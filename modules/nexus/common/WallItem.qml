pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Multimedia
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    property alias source: img.source
    property alias text: label.text
    property alias radius: imgWrapper.radius
    property alias imgHeight: imgWrapper.implicitHeight
    property bool fillLabel: true
    property bool selected

    signal clicked

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.small

        ClipRect {
            id: imgWrapper

            Layout.fillWidth: true
            implicitHeight: Math.round(width * 9 / 16)
            radius: Tokens.rounding.largeIncreased
            color: Colours.tPalette.m3surfaceContainer

            Loader {
                anchors.centerIn: parent

                opacity: img.ready ? 0 : 1
                active: opacity > 0

                sourceComponent: StyledRect {
                    implicitWidth: loadingIndicator.implicitSize + Tokens.padding.large * 2
                    implicitHeight: loadingIndicator.implicitSize + Tokens.padding.large * 2

                    color: Colours.palette.m3primaryContainer
                    radius: Tokens.rounding.full

                    LoadingIndicator {
                        id: loadingIndicator

                        anchors.centerIn: parent
                        containsIcon: true
                        implicitSize: Math.min(imgWrapper.width, imgWrapper.height) * 0.3
                    }
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            Visual {
                id: img

                anchors.fill: parent
                playing: stateLayer.containsMouse
            }

            StyledRect {
                anchors.fill: parent
                radius: imgWrapper.radius
                border.width: root.selected ? 2 : 1
                border.color: root.selected ? Colours.palette.m3primary : Qt.alpha("white", 0.12)
            }

            StyledRect {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Tokens.padding.small
                implicitWidth: check.implicitWidth + Tokens.padding.small * 2
                implicitHeight: implicitWidth
                radius: width / 2
                color: Colours.palette.m3primary
                visible: root.selected

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

            Layout.bottomMargin: Tokens.padding.small
            Layout.fillWidth: true
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.builders.medium.weight(Font.Medium).build()
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
        }
    }

    StateLayer {
        id: stateLayer

        anchors.bottomMargin: root.fillLabel ? 0 : layout.implicitHeight - imgWrapper.implicitHeight
        onClicked: root.clicked()
    }
}
