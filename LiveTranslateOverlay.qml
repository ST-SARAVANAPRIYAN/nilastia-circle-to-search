import QtQuick
import QtQuick.Layouts
import Nilastia
import Nilastia.Config
import qs.components
import qs.services

Item {
    id: root

    property var translatedLines: []
    property bool active: false

    visible: active && translatedLines && translatedLines.length > 0
    opacity: visible ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    signal textCopied(string text)

    Repeater {
        model: root.translatedLines

        Rectangle {
            id: transCard
            required property var modelData
            required property int index

            // In-place alignment matching the exact passage bounding box
            readonly property real contentW: transText.implicitWidth + (cardMouse.containsMouse ? 28 : 6)
            readonly property real targetW: Math.max(modelData.w + 4, Math.min(contentW, 800))
            readonly property real targetH: Math.max(modelData.h + 2, transText.implicitHeight + 4)

            x: Math.max(0, modelData.x - 2)
            y: Math.max(0, modelData.y - 1)
            width: targetW
            height: targetH
            radius: 3

            // Android-style inpainting: seamlessly masks the foreign text with sampled background color
            color: modelData.bg_color || "#121212"
            border.width: 0

            Text {
                id: transText
                anchors.left: parent.left
                anchors.leftMargin: 3
                anchors.right: copyBtn.visible ? copyBtn.left : parent.right
                anchors.rightMargin: 3
                anchors.verticalCenter: parent.verticalCenter

                text: transCard.modelData.translated || transCard.modelData.original
                color: transCard.modelData.text_color || "#ffffff"
                font.pixelSize: Math.max(11, Math.min(26, Math.round(transCard.modelData.h * 0.72)))
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                wrapMode: Text.Wrap
            }

            // Subtle copy button visible only on mouse hover
            Rectangle {
                id: copyBtn
                width: 20; height: 20; radius: 10
                anchors.right: parent.right
                anchors.rightMargin: 3
                anchors.verticalCenter: parent.verticalCenter
                color: copyMouse.containsMouse ? (transCard.modelData.text_color || "#ffffff") : "transparent"
                opacity: copyMouse.containsMouse ? 0.9 : 0.6
                visible: cardMouse.containsMouse

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "content_copy"
                    fontStyle: Tokens.font.icon.size(12).build()
                    color: copyMouse.containsMouse ? (transCard.modelData.bg_color || "#121212") : (transCard.modelData.text_color || "#ffffff")
                }

                MouseArea {
                    id: copyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.textCopied(transCard.modelData.translated);
                    }
                }
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                propagateComposedEvents: true
            }
        }
    }
}
