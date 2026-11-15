import QtQuick
import QtTest
import Caelestia.Blobs

Item {
    width: 520
    height: 340
    Rectangle {
        color: "black"
        id: scene
        anchors.fill: parent
        BlobGroup { id: group; color: "#202020"; smoothing: 32 }
        BlobRect {
            id: panel
            x: 80; y: 60; width: 360; height: 200
            radius: 26
            group: group
            glass: 0.38
            deformScale: 0
        }
    }
    TestCase {
        name: "GlassLighting"
        when: windowShown
        function init() {
            scene.Window.window.color = "black";
            panel.glass = 0.38;
            wait(100);
        }
        // Allow display color conversion and 8-bit rounding in pixel comparisons.
        function referenceRed(x, y) {
            let value = 32 * 0.38;
            const bottom = 0.07 * Math.max(0, Math.min(1, (y / 200 - 0.35) / 0.65));
            const left = 0.13 * Math.max(0, 1 - Math.hypot(x - 26 * 0.7, y - (200 - 26 * 0.7)) / 46);
            const right = 0.09 * Math.max(0, 1 - Math.hypot(x - (360 - 26 * 0.7), y - (200 - 26 * 0.7)) / 46);
            for (const light of [bottom, left, right])
                value = value * (1 - light) + 255 * light;
            return value;
        }
        function test_bottomGlow() {
            const image = grabImage(scene);
            fuzzyCompare(image.red(260, 110), referenceRed(180, 50), 5, "upper tint stays unchanged");
            fuzzyCompare(image.red(260, 220), referenceRed(180, 160), 5, "bottom glow follows the reference gradient");
        }
        function test_cornerHighlights() {
            const image = grabImage(scene);
            for (const x of [100, 420])
                fuzzyCompare(image.red(x, 240), referenceRed(x - 80, 180), 5, "localized lower corner highlight");
            verify(image.red(100, 240) > image.red(420, 240) + 5, "left highlight is stronger than right");
            verify(image.red(420, 240) > image.red(260, 240) + 10, "corner light stays localized");
        }
        function test_rimContrast() {
            const image = grabImage(scene);
            let peak = 0;
            for (let x = 100; x <= 112; ++x)
                for (let y = 60; y <= 64; ++y)
                    peak = Math.max(peak, image.red(x, y));
            verify(peak > 90, "rim peak must be brighter than the previous flat sheen");
        }
        function test_disabledGlass() {
            panel.glass = 0;
            wait(100);
            const image = grabImage(scene);
            fuzzyCompare(image.red(260, 220), 32, 2, "disabled glass retains the original material");
        }
    }
}
