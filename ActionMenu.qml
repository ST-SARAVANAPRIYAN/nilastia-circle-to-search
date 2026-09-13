import QtQuick
import QtQuick.Layouts
import Nilastia
import Nilastia.Config
import qs.components
import qs.services

Rectangle {
    id: root

    property rect targetRect: Qt.rect(0, 0, 0, 0)
    property bool active: false

    signal lensRequested()
    signal copyImageRequested()
    signal closeRequested()

    visible: active && targetRect.width > 15 && targetRect.height > 15
    opacity: visible ? 1.0 : 0.0

    readonly property real preferredY: targetRect.y > 60 ? (targetRect.y - height - 12) : (targetRect.y + targetRect.height + 12)
    readonly property real preferredX: targetRect.x + (targetRect.width - width) / 2

    x: Math.max(16, Math.min(preferredX, (parent ? parent.width : 1920) - width - 16))
    y: Math.max(16, Math.min(preferredY, (parent ? parent.height : 1080) - height - 16))

    width: actionRow.implicitWidth + 20
    height: 44
    radius: 22

    color: Colours.palette.m3surfaceContainerHighest || "#282a36"
    border.color: Colours.palette.m3outlineVariant || "#44475a"
    border.width: 1

    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: 25
        color: "transparent"
        border.color: Qt.rgba(0, 0, 0, 0.35)
        border.width: 2
        z: -1
    }

    RowLayout {
        id: actionRow
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            height: 32
            width: lensContentRow.implicitWidth + 20
            radius: 16
            color: lensMouse.containsMouse ? (Colours.palette.m3primary || "#00f0ff") : Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.25)
            border.color: Colours.palette.m3primary || "#00f0ff"
            border.width: 1

            RowLayout {
                id: lensContentRow
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    text: "travel_explore"
                    fontStyle: Tokens.font.icon.small
                    color: lensMouse.containsMouse ? (Colours.palette.m3onPrimary || "#000000") : (Colours.palette.m3primary || "#00f0ff")
                }

                Text {
                    text: "Search Image"
                    color: lensMouse.containsMouse ? (Colours.palette.m3onPrimary || "#000000") : (Colours.palette.m3primary || "#00f0ff")
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                id: lensMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.lensRequested()
            }
        }

        Rectangle {
            height: 32
            width: copyContentRow.implicitWidth + 18
            radius: 16
            color: copyMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)

            RowLayout {
                id: copyContentRow
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    text: "content_copy"
                    fontStyle: Tokens.font.icon.small
                    color: Colours.palette.m3onSurface || "#ffffff"
                }

                Text {
                    text: "Copy Image"
                    color: Colours.palette.m3onSurface || "#ffffff"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: copyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.copyImageRequested()
            }
        }

        Rectangle {
            width: 28; height: 28; radius: 14
            color: closeMouse.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.25) : Qt.rgba(1, 1, 1, 0.06)

            MaterialIcon {
                anchors.centerIn: parent
                text: "close"
                fontStyle: Tokens.font.icon.small
                color: closeMouse.containsMouse ? "#ff5555" : (Colours.palette.m3onSurfaceVariant || "#a6adc8")
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
