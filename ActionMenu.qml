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
    property string textToSearch: ""

    signal lensRequested()
    signal copyRequested()
    signal searchRequested()
    signal translateRequested()

    visible: active && targetRect.width > 5 && targetRect.height > 5
    opacity: visible ? 1.0 : 0.0

    // Position floating above selection, or below if near top of screen
    readonly property real preferredY: targetRect.y > 60 ? (targetRect.y - height - 12) : (targetRect.y + targetRect.height + 12)
    readonly property real preferredX: targetRect.x + (targetRect.width - width) / 2

    // Clamp inside window boundaries (assuming 1920x1080 or parent)
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

    // Drop shadow
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
        spacing: 6

        // Action: Copy Text (Shown if text is selected)
        Rectangle {
            visible: root.textToSearch.length > 0
            height: 32
            width: copyContentRow.implicitWidth + 18
            radius: 16
            color: copyMouse.containsMouse ? (Colours.palette.m3primary || "#00f0ff") : Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.2)
            border.color: Colours.palette.m3primary || "#00f0ff"
            border.width: 1

            RowLayout {
                id: copyContentRow
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    text: "content_copy"
                    fontStyle: Tokens.font.icon.small
                    color: copyMouse.containsMouse ? (Colours.palette.m3onPrimary || "#000000") : (Colours.palette.m3primary || "#00f0ff")
                }

                Text {
                    text: "Copy"
                    color: copyMouse.containsMouse ? (Colours.palette.m3onPrimary || "#000000") : (Colours.palette.m3primary || "#00f0ff")
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                id: copyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.copyRequested()
            }
        }

        // Action: Web Search (Shown if text is selected)
        Rectangle {
            visible: root.textToSearch.length > 0
            height: 32
            width: searchContentRow.implicitWidth + 16
            radius: 16
            color: searchMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)

            RowLayout {
                id: searchContentRow
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    text: "search"
                    fontStyle: Tokens.font.icon.small
                    color: Colours.palette.m3onSurface || "#ffffff"
                }

                Text {
                    text: "Search"
                    color: Colours.palette.m3onSurface || "#ffffff"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: searchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.searchRequested()
            }
        }

        // Action: Translate (Shown if text is selected)
        Rectangle {
            visible: root.textToSearch.length > 0
            height: 32
            width: transContentRow.implicitWidth + 16
            radius: 16
            color: transMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)

            RowLayout {
                id: transContentRow
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    text: "translate"
                    fontStyle: Tokens.font.icon.small
                    color: Colours.palette.m3onSurface || "#ffffff"
                }

                Text {
                    text: "Translate"
                    color: Colours.palette.m3onSurface || "#ffffff"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: transMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.translateRequested()
            }
        }

        // Action: Google Lens (Primary when visual crop, secondary when text selected)
        Rectangle {
            height: 32
            width: lensContentRow.implicitWidth + 18
            radius: 16
            color: root.textToSearch.length === 0
                ? (lensMouse.containsMouse ? (Colours.palette.m3primary || "#00f0ff") : Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.25))
                : (lensMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06))
            border.color: root.textToSearch.length === 0 ? (Colours.palette.m3primary || "#00f0ff") : "transparent"
            border.width: root.textToSearch.length === 0 ? 1 : 0

            RowLayout {
                id: lensContentRow
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    text: "travel_explore"
                    fontStyle: Tokens.font.icon.small
                    color: (root.textToSearch.length === 0 && lensMouse.containsMouse)
                        ? (Colours.palette.m3onPrimary || "#000000")
                        : (root.textToSearch.length === 0 ? (Colours.palette.m3primary || "#00f0ff") : (Colours.palette.m3onSurface || "#ffffff"))
                }

                Text {
                    text: "Google Lens"
                    color: (root.textToSearch.length === 0 && lensMouse.containsMouse)
                        ? (Colours.palette.m3onPrimary || "#000000")
                        : (root.textToSearch.length === 0 ? (Colours.palette.m3primary || "#00f0ff") : (Colours.palette.m3onSurface || "#ffffff"))
                    font.pixelSize: 12
                    font.weight: root.textToSearch.length === 0 ? Font.DemiBold : Font.Medium
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
    }
}
