import QtQuick
import QtQuick.Layouts
import Nilastia
import Nilastia.Config
import qs.components
import qs.services

Rectangle {
    id: root

    property string statusHint: "Circle, highlight, or drag to search"

    signal closeRequested()

    width: contentRow.implicitWidth + 36
    height: 48
    radius: 24

    color: Colours.palette.m3surfaceContainerHighest || "#1e1e2e"
    border.color: Colours.palette.m3outlineVariant || "#44475a"
    border.width: 1

    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    // Drop shadow
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: 28
        color: "transparent"
        border.color: Qt.rgba(0, 0, 0, 0.35)
        border.width: 2
        z: -1
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 12

        // Google Lens Sparkle Pill
        Rectangle {
            width: 32; height: 32; radius: 16
            color: Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.16)

            MaterialIcon {
                anchors.centerIn: parent
                text: "auto_awesome"
                fontStyle: Tokens.font.icon.small
                color: Colours.palette.m3primary || "#00f0ff"
            }
        }

        // Search Hint / Pill text
        RowLayout {
            spacing: 8
            MaterialIcon {
                text: "gesture"
                fontStyle: Tokens.font.icon.small
                color: Colours.palette.m3onSurfaceVariant || "#a6adc8"
            }

            Text {
                text: root.statusHint
                color: Colours.palette.m3onSurface || "#ffffff"
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }

        // Divider
        Rectangle {
            width: 1
            height: 20
            color: Colours.palette.m3outlineVariant || "#44475a"
        }

        // Close Button
        Rectangle {
            width: 30; height: 30; radius: 15
            color: closeMouse.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.3) : Qt.rgba(1, 1, 1, 0.08)

            MaterialIcon {
                anchors.centerIn: parent
                text: "close"
                fontStyle: Tokens.font.icon.small
                color: closeMouse.containsMouse ? "#ff5555" : (Colours.palette.m3onSurface || "#ffffff")
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }
    }
}
