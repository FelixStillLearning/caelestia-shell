import QtQuick
import Caelestia.Config
import Caelestia.Models
import Caelestia.Multimedia
import Caelestia.State
import qs.components
import qs.components.effects
import qs.services

Item {
    id: root

    required property FileSystemEntry modelData
    required property ScreenState screenState

    scale: 0.5
    opacity: 0
    z: PathView.z ?? 0 // qmllint disable missing-property

    Component.onCompleted: {
        scale = Qt.binding(() => PathView.isCurrentItem ? 1 : PathView.onPath ? 0.94 : 0);
        opacity = Qt.binding(() => PathView.onPath ? 1 : 0);
    }

    implicitWidth: image.width + Tokens.padding.medium * 2
    implicitHeight: image.height + label.height + Tokens.spacing.extraSmall + Tokens.padding.large + Tokens.padding.medium

    StateLayer {
        id: stateLayer

        radius: Tokens.rounding.large
        onClicked: {
            Wallpapers.setWallpaper(root.modelData.path);
            root.screenState.launcher = false;
        }
    }

    Elevation {
        anchors.fill: image
        radius: image.radius
        opacity: root.PathView.isCurrentItem ? 1 : 0
        level: 2

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    ClipRect {
        id: image

        anchors.horizontalCenter: parent.horizontalCenter
        y: Tokens.padding.large
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.large

        implicitWidth: Tokens.sizes.launcher.wallpaperWidth
        implicitHeight: implicitWidth / 16 * 9

        MaterialIcon {
            anchors.centerIn: parent
            text: "image"
            color: Colours.tPalette.m3outline
            fontStyle: Tokens.font.icon.builders.extraLarge.scale(2).weight(Font.DemiBold).build()
        }

        Visual {
            anchors.fill: parent
            source: root.modelData.path
            playing: (root.PathView.isCurrentItem && PersistentState.wallpaperPlaying) || stateLayer.containsMouse
        }

        StyledRect {
            anchors.fill: parent
            radius: image.radius
            border.width: root.PathView.isCurrentItem ? 2 : 1
            border.color: root.PathView.isCurrentItem ? Colours.palette.m3primary : Qt.alpha("white", 0.14)
        }

        StyledRect {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.padding.small
            implicitWidth: check.implicitWidth + Tokens.padding.small * 2
            implicitHeight: implicitWidth
            radius: width / 2
            color: Colours.palette.m3primary
            visible: root.modelData.path === Wallpapers.actualCurrent

            MaterialIcon {
                id: check
                anchors.centerIn: parent
                text: "check"
                color: Colours.palette.m3onPrimary
                fontStyle: Tokens.font.icon.small
            }
        }
    }

    StyledText {
        id: label

        anchors.top: image.bottom
        anchors.topMargin: Tokens.spacing.extraSmall
        anchors.horizontalCenter: parent.horizontalCenter

        width: image.width - Tokens.padding.medium * 2
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        renderType: Text.QtRendering
        text: root.modelData.name
        font: Tokens.font.label.medium
    }

    Behavior on scale {
        Anim {}
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
