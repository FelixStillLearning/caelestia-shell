// Run from the fork with a working display:
// QML_IMPORT_PATH="$PWD/build/qml" QSG_RHI_BACKEND=opengl /usr/lib/qt6/bin/qmltestrunner -input tests
import QtQuick
import QtTest
import Caelestia.Blobs

Item {
    width: 400
    height: 300

    Item {
        id: scene
        anchors.fill: parent
        layer.enabled: true
        BlobGroup {
            id: group
            color: "#202020"
            smoothing: 32
        }
        BlobInvertedRect {
            anchors.fill: parent
            group: group
            radius: 20
            borderRight: 20
        }
        BlobRect {
            x: 220; y: 50; width: 160; height: 200
            group: group
            radius: 20
            glass: 0.38
            deformScale: 0
        }
    }

    TestCase {
        name: "BlobShadow"
        when: windowShown

        function test_tintJoinAndOuterShadow() {
            scene.Window.window.color = "white";
            wait(100);
            const before = grabImage(scene);
            // Infer alpha over white; allow display color conversion and 8-bit rounding.
            // Upper half avoids the intentional glow at the bottom of the glass.
            for (let x = 270; x < 355; ++x)
                fuzzyCompare((255 - before.red(x, 100)) / (255 - 32), 0.38, 0.02, "tint at x=" + x);

            group.shadowColor = "#b3000000";
            wait(100);
            const after = grabImage(scene);
            for (let x = 225; x < 395; ++x)
                compare(after.pixel(x, 100), before.pixel(x, 100), "shadow under shape at x=" + x);
            verify(after.red(215, 100) < before.red(215, 100), "shadow outside shape");
            compare(after.pixel(195, 100), before.pixel(195, 100), "shadow ends within 15 px");

            group.shadowColor = "transparent";
            wait(100);
            verify(grabImage(scene).equals(before), "shadow fade returns to original pixels");
        }
    }
}
