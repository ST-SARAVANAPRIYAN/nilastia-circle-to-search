import QtQuick
import Nilastia
import Nilastia.Config
import qs.services

Item {
    id: root

    property rect targetRect: Qt.rect(0, 0, 0, 0)
    property bool active: false
    property color glowColor: Colours.palette.m3primary || "#00f0ff"

    visible: active && targetRect.width > 5 && targetRect.height > 5
    opacity: visible ? 1.0 : 0.0

    x: targetRect.x
    y: targetRect.y
    width: targetRect.width
    height: targetRect.height

    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    // Outer glow
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: 16
        color: "transparent"
        border.color: Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.45)
        border.width: 3
    }

    // Main selection box
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.12)
        border.color: root.glowColor
        border.width: 2.0
    }

    // 4 Android Corner Handles
    Rectangle {
        width: 14; height: 14; radius: 7
        anchors.left: parent.left; anchors.top: parent.top
        anchors.margins: -7
        color: "#ffffff"
        border.color: root.glowColor
        border.width: 2
    }

    Rectangle {
        width: 14; height: 14; radius: 7
        anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: -7
        color: "#ffffff"
        border.color: root.glowColor
        border.width: 2
    }

    Rectangle {
        width: 14; height: 14; radius: 7
        anchors.left: parent.left; anchors.bottom: parent.bottom
        anchors.margins: -7
        color: "#ffffff"
        border.color: root.glowColor
        border.width: 2
    }

    Rectangle {
        width: 14; height: 14; radius: 7
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: -7
        color: "#ffffff"
        border.color: root.glowColor
        border.width: 2
    }
}
