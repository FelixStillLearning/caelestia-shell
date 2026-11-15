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
        BlobGroup {
            id: group
            color: "#202020"
            smoothing: 32
        }
        BlobRect {
            id: first
            x: 100; y: 60; width: 160; height: 400
            group: group
            radius: 20
            glass: 0.38
            deformScale: 0
        }
        BlobRect {
            id: second
            x: 240; y: 60; width: 160; height: 400
            group: group
            radius: 20
            glass: 0.38
            deformScale: 0
        }
        BlobRect {
            id: third
            x: 100; y: 60; width: 0; height: 400
            group: group
            radius: 20
            glass: 0.38
            deformScale: 0
        }
    }

    TestCase {
        name: "PanelGlass"
        when: windowShown

        function test_joins_data() {
            return [
                { tag: "two-panels", base: 1, count: 2, excluded: false },
                { tag: "two-translucent-panels", base: 0.8, count: 2, excluded: false },
                { tag: "three-overlapping-panels", base: 1, count: 3, excluded: false },
                { tag: "excluded-panels", base: 1, count: 2, excluded: true }
            ];
        }

        function test_joins(data) {
            scene.Window.window.color = "white";
            group.color = Qt.rgba(32 / 255, 32 / 255, 32 / 255, data.base);
            scene.opacity = data.base;
            second.x = data.count === 3 ? first.x : 240;
            third.width = data.count === 3 ? 160 : 0;
            first.exclude = data.excluded ? [second] : [];
            second.exclude = data.excluded ? [first] : [];
            wait(100);
            const image = grabImage(scene);
            for (let x = 245; x <= 255; ++x)
                fuzzyCompare((255 - image.red(x, 130)) / (255 - 32), 0.38, 0.02, "joined tint at x=" + x);
            if (data.excluded)
                compare(image.red(250, 55), 255, "excluded panels retain their unblended corners");
        }
    }
}
