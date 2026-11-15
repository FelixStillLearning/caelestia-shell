// Run with the same command as tst_blobshadow.qml.
import QtQuick
import QtTest
import Caelestia.Blobs

Item {
    width: 600
    height: 500
    Item {
        id: scene
        anchors.fill: parent
        BlobGroup { id: group; color: "#202020"; smoothing: 32 }
        BlobInvertedRect {
            anchors.fill: parent
            anchors.margins: -50
            group: group
            radius: 20
            borderLeft: 110
            borderRight: 60
            borderTop: 60
            borderBottom: 60
            glass: 0.38
        }
        BlobRect {
            id: popup
            x: -10; y: 80; width: 360; height: 360
            group: group
            radius: 20
            glass: 0.38
            deformScale: 0
        }
        BlobRect {
            id: closed
            x: 150; y: -195; width: 0; height: 200
            group: group
            radius: 20
            glass: 0.38
            deformScale: 0
        }
    }
    TestCase {
        name: "PopoutJoin"
        when: windowShown
        function init() {
            group.color = "#202020";
            popup.visible = true;
            closed.width = 0;
            closed.visible = true;
            popup.x = -10;
            popup.y = 80;
            popup.width = 360;
            popup.height = 360;
            scene.Window.window.color = "white";
        }
        function test_exterior_data() {
            return [
                { tag: "dark-on-white", surface: "#202020", background: "white", red: 255 },
                { tag: "dark-on-black", surface: "#202020", background: "black", red: 0 },
                { tag: "light-on-white", surface: "#fff9fa", background: "white", red: 255 },
                { tag: "light-on-black", surface: "#fff9fa", background: "black", red: 0 }
            ];
        }
        function test_exterior(data) {
            group.color = data.surface;
            scene.Window.window.color = data.background;
            popup.height = 200;
            for (const offset of [0, 0.375, 4, 12.625]) {
                popup.x = -10 + offset;
                popup.y = 80 + offset;
                wait(32);
                const image = grabImage(scene);
                for (let d = 20; d <= 60; ++d) {
                    compare(image.red(Math.ceil(popup.x + popup.width) + d, 150), data.red,
                            "no vertical line beyond the panel at offset " + offset + ", distance " + d);
                    compare(image.red(200, Math.ceil(popup.y + popup.height) + d), data.red,
                            "no horizontal line beyond the panel at offset " + offset + ", distance " + d);
                }
            }
        }
        function test_hiddenPanel() {
            wait(100);
            const before = grabImage(scene);
            closed.width = 300;
            closed.visible = false;
            wait(100);
            verify(grabImage(scene).equals(before), "hidden panel must not alter the top border");
            closed.visible = true;
            wait(100);
            verify(!grabImage(scene).equals(before), "visible panel contributes to the border");
            closed.visible = false;
            wait(100);
            verify(grabImage(scene).equals(before), "hiding a panel invalidates all affected renderers");
        }
        function test_buriedEdges() {
            popup.height = 160;
            wait(100);
            const image = grabImage(scene);
            for (let x = 15; x <= 40; ++x)
                for (let offset = -3; offset <= 3; ++offset) {
                    const y = 240 + x - 60 + offset;
                    fuzzyCompare((255 - image.red(x, y)) / 223, 0.38, 0.02,
                                 "internal edge lighting at " + x + "," + y);
                }
        }
        function test_darkJoin() {
            popup.height = 160;
            scene.Window.window.color = "black";
            wait(100);
            const image = grabImage(scene);
            image.save("/tmp/glass-dark-surface.png");
            for (let x = 15; x <= 30; ++x) {
                const y = 240 + x - 60;
                fuzzyCompare(image.red(x, y - 4), image.red(x, y + 4), 2,
                             "dark surface changes across internal join at x=" + x);
            }
        }
        function test_softReflection() {
            popup.visible = false;
            scene.Window.window.color = "black";
            wait(100);
            const image = grabImage(scene);
            const body = image.red(30, 150);
            verify(image.red(55, 150) > body, "white reflection remains visible on dark glass");
            verify(image.red(55, 150) < body + 20, "reflection stays soft inside the surface");
            verify(image.red(50, 150) >= image.red(45, 150), "reflection fades into the glass");
        }
        function test_transition_data() {
            return [{ tag: "white", background: "white" }, { tag: "black", background: "black" }];
        }
        function test_transition(data) {
            scene.Window.window.color = data.background;
            popup.visible = false;
            wait(32);
            const baseline = grabImage(scene).red(20, 100);
            popup.visible = true;
            popup.deformScale = 0.00015;
            for (let frame = 0; frame <= 80; ++frame) {
                const progress = frame <= 40 ? frame : 80 - frame;
                popup.x = -305 + 7.375 * progress;
                wait(16);
                const image = grabImage(scene);
                for (let x = 20; x <= 50; ++x)
                    for (let y = 100; y <= 140; ++y)
                        fuzzyCompare(image.red(x, y), baseline, 3,
                                     "moving join at frame " + frame + ": " + x + "," + y);
            }
            popup.deformScale = 0;
        }
        function test_join_data() {
            return [
                { tag: "wide", x: -10, y: 80, width: 360, height: 360 },
                { tag: "small", x: 20, y: 100, width: 240, height: 160 },
                { tag: "fractional", x: -9.625, y: 80.375, width: 359.625, height: 359.25 }
            ];
        }
        function test_join(data) {
            popup.x = data.x;
            popup.y = data.y;
            popup.width = data.width;
            popup.height = data.height;
            scene.Window.window.color = "white";
            wait(100);
            const image = grabImage(scene);
            for (let x = 15; x < 58; ++x)
                for (let offset = -3; offset <= 3; ++offset) {
                    const y = Math.round(data.y + 60 - x) + offset;
                    fuzzyCompare((255 - image.red(x, y)) / 223, 0.38, 0.02, "ownership seam at " + x + "," + y);
                }
        }
    }
}
