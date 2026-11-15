// Run with the same command as tst_blobshadow.qml.
import QtQuick
import QtTest
import Caelestia.Blobs

Item {
    width: 600
    height: 400

    Item {
        id: scene
        anchors.fill: parent
        BlobGroup {
            id: group
            color: "#202020"
            smoothing: 32
        }
        BlobInvertedRect {
            id: frame
            anchors.fill: parent
            group: group
            radius: 20
            borderLeft: 60
            borderRight: 20
            borderTop: 20
            borderBottom: 20
            glass: 0.38
        }
        BlobRect {
            x: 420; y: 60; width: 160; height: 280
            group: group
            radius: 20
            glass: 0.38
            deformScale: 0
        }
        BlobRect {
            x: 60; y: 140; width: 120; height: 120
            group: group
            radius: 20
            deformScale: 0
        }
    }

    TestCase {
        name: "FrameGlass"
        when: windowShown

        function init() {
            frame.borderLeft = 60;
            frame.borderRight = 20;
            frame.glass = 0.38;
            group.shadowColor = "transparent";
            scene.Window.window.color = "white";
        }

        function test_frameAndBar_data() {
            return [{ tag: "opaque-base", base: 1 }, { tag: "translucent-base", base: 0.8 }];
        }

        function test_frameAndBar(data) {
            group.color = Qt.rgba(32 / 255, 32 / 255, 32 / 255, data.base);
            scene.opacity = data.base;
            wait(100);
            const before = grabImage(scene);
            for (const p of [Qt.point(30, 60), Qt.point(590, 60), Qt.point(300, 10)])
                fuzzyCompare((255 - before.red(p.x, p.y)) / (255 - 32), 0.38, 0.02, "frame tint at " + p);
            // OSD and frame share one material across their join.
            for (let x = 530; x < 595; ++x)
                fuzzyCompare((255 - before.red(x, 110)) / (255 - 32), 0.38, 0.02, "join at x=" + x);
            fuzzyCompare((255 - before.red(120, 180)) / (255 - 32), data.base, 0.02, "ordinary panel retains its original material");

            group.shadowColor = "#b3000000";
            wait(100);
            const shadow = grabImage(scene);
            compare(shadow.pixel(30, 60), before.pixel(30, 60), "no shadow under bar");
            verify(shadow.red(68, 70) < before.red(68, 70), "frame renderer receives outer shadow");

            // A small hole selects the frame's full-quad renderer.
            frame.borderLeft = 340;
            frame.borderRight = 200;
            wait(100);
            fuzzyCompare((255 - grabImage(scene).red(30, 60)) / (255 - 32), 0.38, 0.02, "full-quad frame tint");

            frame.glass = 0;
            wait(100);
            fuzzyCompare((255 - grabImage(scene).red(30, 60)) / (255 - 32), data.base, 0.02, "glass disabled restores the original frame material");

            frame.glass = 0.38;
            frame.borderLeft = 60;
            frame.borderRight = 20;
            wait(100);
            fuzzyCompare((255 - grabImage(scene).red(590, 60)) / (255 - 32), 0.38, 0.02, "return to frame mesh");
        }
    }
}
