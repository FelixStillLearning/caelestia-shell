pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property int centerWidth
    readonly property color bgColour: Colours.tPalette.m3surfaceContainerHighest

    implicitWidth: Math.round(Math.min(128, centerWidth * 0.32))
    implicitHeight: implicitWidth

    StyledClippingRect {
        id: avatar

        anchors.fill: parent
        radius: width / 2
        color: root.bgColour

        MaterialIcon {
            anchors.centerIn: parent
            text: "person"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.size(root.width * 0.45).build()
            visible: pfp.status !== Image.Ready
        }

        CachingImage {
            id: pfp

            anchors.fill: parent
            path: `${Paths.home}/.face`
        }
    }

    StyledRect {
        anchors.fill: avatar
        radius: width / 2
        border.width: 1
        border.color: Qt.alpha("white", 0.2)
    }
}
