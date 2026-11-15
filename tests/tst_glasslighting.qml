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
            scene.color = "black";
            group.color = "#202020";
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
        function test_regularMaterialContrast_data() {
            return [
                { tag: "dark-on-white", background: "white", surface: "#161216", foreground: Qt.rgba(240/255, 229/255, 234/255, 1) },
                { tag: "dark-on-black", background: "#181818", surface: "#161216", foreground: Qt.rgba(240/255, 229/255, 234/255, 1) },
                { tag: "light-on-white", background: "white", surface: "#fff9fa", foreground: Qt.rgba(33/255, 25/255, 29/255, 1) },
                { tag: "light-on-black", background: "#181818", surface: "#fff9fa", foreground: Qt.rgba(33/255, 25/255, 29/255, 1) }
            ];
        }
        function test_regularMaterialContrast(data) {
            scene.color = data.background;
            group.color = data.surface;
            panel.glass = 0.7;
            wait(100);
            const image = grabImage(scene);
            function luminance(r, g, b) {
                const values = [r, g, b].map(v => v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
                return values[0] * 0.2126 + values[1] * 0.7152 + values[2] * 0.0722;
            }
            const background = luminance(image.red(260, 110)/255, image.green(260, 110)/255, image.blue(260, 110)/255);
            const foreground = luminance(data.foreground.r, data.foreground.g, data.foreground.b);
            verify((Math.max(background, foreground) + 0.05) / (Math.min(background, foreground) + 0.05) >= 4.5,
                   "regular glass preserves text contrast across theme and backdrop combinations");
        }
        function test_disabledGlass() {
            panel.glass = 0;
            wait(100);
            const image = grabImage(scene);
            fuzzyCompare(image.red(260, 220), 32, 2, "disabled glass retains the original material");
        }
    }
}
