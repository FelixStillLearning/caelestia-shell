#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float paddedX;
    float paddedY;
    float paddedW;
    float paddedH;
    float smoothFactor;
    int rectCount;
    int myIndex;
    vec4 color;
    int hasInverted;
    float invertedRadius;
    float invertedGlass;
    vec4 invertedOuter;
    vec4 invertedInner;
    vec4 rectData[80];
    vec4 shadowColor;
};

float sdRoundedBox(vec2 p, vec2 center, vec2 halfSize, float radius) {
    vec2 d = abs(p - center) - halfSize + vec2(radius);
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
}

float sdRoundedBox4(vec2 p, vec2 center, vec2 halfSize, vec4 r) {
    // r = (topRight, bottomRight, bottomLeft, topLeft)
    p -= center;
    r.xy = (p.x > 0.0) ? r.xy : r.wz;
    r.x  = (p.y > 0.0) ? r.y : r.x;
    vec2 q = abs(p) - halfSize + r.x;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
}

float sdBox(vec2 p, vec2 center, vec2 halfSize) {
    vec2 d = abs(p - center) - halfSize;
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

float smin(float a, float b, float k) {
    // Circular smooth min — the blend fillet is a true circular arc of radius k,
    // tangent to both surfaces (not a polynomial/squircle curve). Deviates from
    // min(a, b) only in the corner region where BOTH a < k and b < k (unlike the
    // cubic it replaced, which deviated over the whole band |a - b| < k). Always
    // <= min(a, b); max blend depth at a == b is (sqrt(2) - 1) * k. It is C1 but
    // not C2 at the support boundary, so a circular-arc fillet shows the usual
    // line-meets-arc curvature step — by design, that is the "circular" look.
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

float smax(float a, float b, float k) {
    // Circular smooth max — dual of smin: -smin(-a, -b, k). Always >= max(a, b).
    return min(-k, max(a, b)) + length(max(vec2(a, b) + vec2(k), vec2(0.0)));
}

float smaxSharpA(float a, float b, float k) {
    // Circular smax variant that keeps a's boundary sharp (no inward rounding at
    // a = 0). Used for the frame outer edge so it always fills to the edges.
    float sm = min(-k, max(a, b)) + length(max(vec2(a, b) + vec2(k), vec2(0.0)));
    float blend = (sm - max(a, b)) * smoothstep(0.0, k * 0.5, -a);
    return max(a, b) + blend;
}

float glassRim(float x) {
    if (x < 0.07) return mix(0.10, 0.55, clamp(x / 0.07, 0.0, 1.0));
    if (x < 0.30) return mix(0.55, 0.14, (x - 0.07) / 0.23);
    if (x < 0.70) return mix(0.14, 0.10, (x - 0.30) / 0.40);
    if (x < 0.93) return mix(0.10, 0.40, (x - 0.70) / 0.23);
    return mix(0.40, 0.08, clamp((x - 0.93) / 0.07, 0.0, 1.0));
}

float glassFill(vec2 p, vec2 size, vec4 radii) {
    float bottom = 0.07 * clamp((p.y / size.y - 0.35) / 0.65, 0.0, 1.0);
    vec2 leftCenter = vec2(radii.z * 0.7, size.y - radii.z * 0.7);
    vec2 rightCenter = vec2(size.x - radii.y * 0.7, size.y - radii.y * 0.7);
    float left = 0.13 * max(0.0, 1.0 - distance(p, leftCenter) / 46.0);
    float right = 0.09 * max(0.0, 1.0 - distance(p, rightCenter) / 46.0);
    return 1.0 - (1.0 - bottom) * (1.0 - left) * (1.0 - right);
}

void main() {
    vec2 pixel = vec2(paddedX, paddedY) + qt_TexCoord0 * vec2(paddedW, paddedH);
    // Mesh interpolation must agree at ownership ties or translucent pixels overlap/vanish.
    pixel = round(pixel * 256.0) / 256.0;

    // Phase 1: compute per-rect SDF, track owner. We can't smin yet because excluded
    // pairs need to skip the smooth blend, which requires pairwise pass below.
    float dArr[16];
    int owner = -2;
    float minDist = 1e10;

    for (int i = 0; i < rectCount; i++) {
        vec4 rect = rectData[i * 5];         // cx, cy, hw, hh
        vec4 props = rectData[i * 5 + 1];    // excludeMask(int bits), offsetX, offsetY, minEig
        vec4 invDm = rectData[i * 5 + 2];    // inverse deform matrix
        vec4 sh = rectData[i * 5 + 3];       // screenHalfX, screenHalfY, 0, 0
        vec4 radii = rectData[i * 5 + 4];    // effective per-corner radii (tr, br, bl, tl)

        // Offset center for asymmetric deformation
        vec2 center = rect.xy + props.yz;

        // AABB early-out: skip rects far from this pixel
        vec2 extent = sh.xy + vec2(smoothFactor * 1.5);
        if (abs(pixel.x - center.x) > extent.x || abs(pixel.y - center.y) > extent.y) {
            dArr[i] = 1e10;
            continue;
        }

        // Apply pre-computed inverse deformation to the evaluation point
        mat2 invDeform = mat2(invDm.xy, invDm.zw);
        vec2 transformedPixel = center + invDeform * (pixel - center);

        // Use pre-computed effective per-corner radii
        float d = sdRoundedBox4(transformedPixel, center, rect.zw, radii);

        // Use pre-computed minimum eigenvalue for SDF correction
        d *= max(props.w, 0.01);

        // Scale SDF on the axis facing a nearby border to narrow the smin blend zone
        // in that direction only, without reducing k (which would cause sharp edges).
        if (hasInverted != 0) {
            vec2 screenHalf = sh.xy;

            float distY0 = (center.y + screenHalf.y) - (invertedInner.y - invertedInner.w);
            float distY1 = (invertedInner.y + invertedInner.w) - (center.y - screenHalf.y);
            float distX0 = (center.x + screenHalf.x) - (invertedInner.x - invertedInner.z);
            float distX1 = (invertedInner.x + invertedInner.z) - (center.x - screenHalf.x);

            // 0 = far from border, 1 = at border (max compression)
            float yProx = 1.0 - min(
                smoothstep(0.0, smoothFactor, distY0),
                smoothstep(0.0, smoothFactor, distY1)
            );
            float xProx = 1.0 - min(
                smoothstep(0.0, smoothFactor, distX0),
                smoothstep(0.0, smoothFactor, distX1)
            );

            // Smooth axis weights: gradient-based at corners, face-based inside.
            vec2 q = abs(pixel - center) - screenHalf;
            vec2 qp = max(q, vec2(0.0));
            float cornerLen = length(qp);

            // Gradient direction in corner region (smooth 90-degree rotation)
            float gradX = qp.x / max(cornerLen, 0.001);
            float gradY = qp.y / max(cornerLen, 0.001);

            // Smooth face weights for inside/edge (no hard branch)
            float faceY = smoothstep(-4.0, 4.0, q.y - q.x);
            float faceX = 1.0 - faceY;

            // Blend: gradient in corner region, face-based inside
            float t = smoothstep(0.0, 2.0, cornerLen);
            float xWeight = mix(faceX, gradX, t);
            float yWeight = mix(faceY, gradY, t);

            float boost = 3.0;
            float scale = 1.0 + (xProx * xWeight + yProx * yWeight) * boost;
            d *= scale;
        }

        dArr[i] = d;
        if (d < smoothFactor && d < minDist) {
            minDist = d;
            owner = i;
        }
    }

    // Phase 2: hard-min baseline over all rects.
    float mergedSdf = 1e10;
    for (int i = 0; i < rectCount; i++) {
        mergedSdf = min(mergedSdf, dArr[i]);
    }

    // Phase 3: pair-wise smin contributions, skipping excluded pairs. Pair smin <= min,
    // so taking the min over all non-excluded pair smins gives the smoothly-merged SDF.
    for (int i = 0; i < rectCount; i++) {
        if (dArr[i] >= 1e9)
            continue;
        int excludeMask = floatBitsToInt(rectData[i * 5 + 1].x);
        for (int j = i + 1; j < rectCount; j++) {
            if (dArr[j] >= 1e9)
                continue;
            if ((excludeMask & (1 << j)) != 0)
                continue;
            // Circular smin deviates from min only where BOTH dArr are < smoothFactor.
            if (max(dArr[i], dArr[j]) >= smoothFactor)
                continue;
            mergedSdf = min(mergedSdf, smin(dArr[i], dArr[j], smoothFactor));
        }
    }

    float dFrame = 1e10;
    if (hasInverted != 0) {
        float dOuter = sdBox(pixel, invertedOuter.xy, invertedOuter.zw) - 1.0;
        float dInner = sdRoundedBox(pixel, invertedInner.xy, invertedInner.zw, invertedRadius);

        // Border sinks: track the opposite rect edge, clamped to border thickness
        float innerTop = invertedInner.y - invertedInner.w;
        float innerBot = invertedInner.y + invertedInner.w;
        float innerLeft = invertedInner.x - invertedInner.z;
        float innerRight = invertedInner.x + invertedInner.z;
        float outerTop = invertedOuter.y - invertedOuter.w;
        float outerBot = invertedOuter.y + invertedOuter.w;
        float outerLeft = invertedOuter.x - invertedOuter.z;
        float outerRight = invertedOuter.x + invertedOuter.z;

        float sinkValue = 0.0;
        for (int i = 0; i < rectCount; i++) {
            vec4 rect = rectData[i * 5];
            vec4 sinkProps = rectData[i * 5 + 1];
            vec2 sinkSh = rectData[i * 5 + 3].xy;

            // Screen-space center (with offset) and pre-computed AABB half-extents
            vec2 ctr = rect.xy + sinkProps.yz;

            // Sink onset / residual overlap: how far a rect must penetrate the border before
            // the inner wall recedes to form its pocket. Too low and the wall recedes faster
            // than the junction can stay convex, denting the inner edge inward near the rect's
            // (squared) corners; too high and the rect nestles too deep before the wall yields.
            // Tuned between the old cubic blend depth (k/6, too shallow) and the circular blend
            // depth ((sqrt2-1)k): half the circular smin gap-closing distance, (2-sqrt2)k/2.
            float preOff = smoothFactor * (2.0 - sqrt(2.0)) * 0.5;

            // Top border: track rect's BOTTOM edge, only within border thickness
            float topPen = clamp(innerTop - (ctr.y + sinkSh.y) - preOff, 0.0, innerTop - outerTop);

            // Bottom border: track rect's TOP edge
            float botPen = clamp((ctr.y - sinkSh.y) - innerBot - preOff, 0.0, outerBot - innerBot);

            // Left border: track rect's RIGHT edge
            float leftPen = clamp(innerLeft - (ctr.x + sinkSh.x) - preOff, 0.0, innerLeft - outerLeft);

            // Right border: track rect's LEFT edge
            float rightPen = clamp((ctr.x - sinkSh.x) - innerRight - preOff, 0.0, outerRight - innerRight);

            // Lateral distance from pixel to rect's extent along each edge
            float hLat = max(abs(pixel.x - ctr.x) - sinkSh.x, 0.0);
            float vLat = max(abs(pixel.y - ctr.y) - sinkSh.y, 0.0);

            // Perpendicular proximity: full strength in border, fade inside inner area
            float topZone = 1.0 - smoothstep(innerTop, innerTop + smoothFactor, pixel.y);
            float botZone = smoothstep(innerBot - smoothFactor, innerBot, pixel.y);
            float leftZone = 1.0 - smoothstep(innerLeft, innerLeft + smoothFactor, pixel.x);
            float rightZone = smoothstep(innerRight - smoothFactor, innerRight, pixel.x);

            float s = smoothFactor * 2.0;
            float sink = max(
                max(topPen * smoothstep(s, 0.0, hLat) * topZone,
                    botPen * smoothstep(s, 0.0, hLat) * botZone),
                max(leftPen * smoothstep(s, 0.0, vLat) * leftZone,
                    rightPen * smoothstep(s, 0.0, vLat) * rightZone)
            );
            sinkValue = max(sinkValue, sink);
        }

        dInner -= sinkValue;

        // The circular smax fillet has radius kFrame; when it exceeds the border thickness
        // it can't complete inside the border, so the sharp outer-box term bleeds onto the
        // inner edge and bulges the inner corners (worst when thickness < smoothFactor — the
        // default border is thinner than the blend radius). Clamp kFrame to the thinnest side
        // so the inner edge stays a clean constant-radius arc. Each inner corner is bounded by
        // its thinner adjacent side, so the global min is correct for every corner.
        float minThick = min(min(innerTop - outerTop, outerBot - innerBot),
                             min(innerLeft - outerLeft, outerRight - innerRight));
        float kFrame = clamp(min(smoothFactor, minThick - 1.0), 1.0, smoothFactor);
        dFrame = smaxSharpA(dOuter, -dInner, kFrame);

        mergedSdf = smin(mergedSdf, dFrame, smoothFactor);
        if (dFrame < minDist) {
            owner = -1;
        }
    }

    // -3 draws the entire union with one shared SDF snapshot.
    float fw = fwidth(mergedSdf);
    // Derive the normal in scene coordinates, independent of the graphics API's Y direction.
    vec2 gradient = vec2(dFdx(mergedSdf), dFdy(mergedSdf)) / vec2(dFdx(pixel.x), dFdy(pixel.y));
    if (myIndex != -3 && owner != myIndex)
        discard;
    float alpha = 1.0 - smoothstep(-fw, fw, mergedSdf);
    float tintDelta = 0.0;
    float rimLight = 0.0;
    float fillLight = 0.0;
    vec2 normal = gradient / max(length(gradient), 0.001);
    float totalWeight = 0.0;

    if (hasInverted != 0) {
        float frameW = smoothstep(-4.0, 4.0, minDist - dFrame);
        totalWeight += frameW;
        if (invertedGlass > 0.0) {
            float frameTint = clamp(invertedGlass / max(color.a, 0.01), 0.0, 1.0);
            tintDelta += (frameTint - 1.0) * frameW;
            float facing = clamp(0.5 - 0.35 * (normal.x + normal.y), 0.0, 1.0);
            rimLight += mix(0.08, 0.40, facing) * frameW;
            fillLight += mix(0.012, 0.035, facing)
                * (1.0 - smoothstep(0.0, 20.0, max(-mergedSdf, 0.0))) * frameW;
        }
    }

    // Blend material contributions over 4 px while lighting only the shared outer contour.
    for (int i = 0; i < rectCount; i++) {
        if (dArr[i] >= 1e9)
            continue;
        float dOther = dFrame;
        for (int j = 0; j < rectCount; j++)
            if (j != i)
                dOther = min(dOther, dArr[j]);
        float w = smoothstep(-4.0, 4.0, dOther - dArr[i]);
        totalWeight += w;
        float g = rectData[i * 5 + 3].z;
        if (w <= 0.0 || g <= 0.0)
            continue;

        // Parent opacity supplies surfaceColour.a; shadows no longer need compensation.
        float aGlass = clamp(g / max(color.a, 0.01), 0.0, 1.0);
        tintDelta += (aGlass - 1.0) * w;
        vec4 rect = rectData[i * 5];
        vec4 props = rectData[i * 5 + 1];
        vec4 invDm = rectData[i * 5 + 2];
        vec2 local = rect.zw + mat2(invDm.xy, invDm.zw) * (pixel - rect.xy - props.yz);
        vec2 size = max(rect.zw * 2.0, vec2(0.01));
        rimLight += glassRim(local.x / size.x) * w;
        // Suppress highlights from corners buried inside another surface.
        float exposed = 1.0 - smoothstep(0.0, 4.0, dArr[i] - mergedSdf);
        fillLight += glassFill(local, size, rectData[i * 5 + 4]) * exposed * w;
    }

    // Normalise multi-panel junctions so equal glass tints stay equal through the join.
    float tintA = 1.0 + tintDelta / max(totalWeight, 0.001);
    float rim = rimLight / max(totalWeight, 0.001)
        * smoothstep(-1.2 - fw, -1.2 + fw, mergedSdf);
    float fill = fillLight / max(totalWeight, 0.001);
    float light = clamp(1.0 - (1.0 - fill) * (1.0 - rim), 0.0, 1.0);
    vec4 col = vec4(color.rgb * tintA, tintA) * (1.0 - light) + vec4(light);

    // Knock out the full shape coverage, rather than its translucent tint.
    // shortcut: shadow reach is capped by smoothing padding; expand geometry for wider shadows.
    float shadowWidth = max(min(15.0, smoothFactor), 0.01);
    float falloff = 1.0 - smoothstep(0.0, shadowWidth, max(mergedSdf, 0.0));
    float shadowA = 0.5 * shadowColor.a * falloff * falloff * (1.0 - alpha);
    fragColor = (col * alpha + vec4(shadowColor.rgb * shadowA, shadowA)) * qt_Opacity;
}
