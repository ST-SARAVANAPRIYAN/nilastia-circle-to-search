import QtQuick
import QtQuick.Layouts
import Nilastia
import Nilastia.Config
import qs.components
import qs.services

Rectangle {
    id: root

    property string currentMode: "circle" // "circle" or "translate"
    property string statusHint: "Circle or tap anything to search"
    property bool ocrLoading: false
    property string targetLanguage: "en"

    signal modeChanged(string mode)
    signal targetLanguageSelected(string langCode)
    signal closeRequested()

    function getLanguageName(code) {
        const map = {
            "en": "English",
            "es": "Spanish",
            "fr": "French",
            "de": "German",
            "it": "Italian",
            "pt": "Portuguese",
            "ru": "Russian",
            "zh-CN": "Chinese",
            "ja": "Japanese",
            "ko": "Korean",
            "hi": "Hindi",
            "ta": "Tamil",
            "ar": "Arabic",
            "nl": "Dutch",
            "tr": "Turkish"
        };
        return map[code] || code.toUpperCase();
    }

    width: contentRow.implicitWidth + 36
    height: 50
    radius: 25

    color: Colours.palette.m3surfaceContainerHighest || "#1e1e2e"
    border.color: Colours.palette.m3outlineVariant || "#44475a"
    border.width: 1

    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    // Drop shadow
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: 29
        color: "transparent"
        border.color: Qt.rgba(0, 0, 0, 0.35)
        border.width: 2
        z: -1
    }

    // Language Dropdown Popup (Material 3 Card)
    Rectangle {
        id: langPopup
        visible: false
        z: 100
        width: 190
        height: 240
        radius: 16
        color: Colours.palette.m3surfaceContainerHighest || "#1e1e2e"
        border.color: Colours.palette.m3outlineVariant || "#44475a"
        border.width: 1

        anchors.bottom: root.top
        anchors.bottomMargin: 10
        anchors.horizontalCenter: root.horizontalCenter

        // Drop shadow for popup
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: 19
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.45)
            border.width: 2
            z: -1
        }

        ListView {
            id: langList
            anchors.fill: parent
            anchors.margins: 6
            clip: true
            model: [
                { code: "en", name: "English" },
                { code: "es", name: "Spanish" },
                { code: "fr", name: "French" },
                { code: "de", name: "German" },
                { code: "it", name: "Italian" },
                { code: "pt", name: "Portuguese" },
                { code: "ru", name: "Russian" },
                { code: "zh-CN", name: "Chinese (Simplified)" },
                { code: "ja", name: "Japanese" },
                { code: "ko", name: "Korean" },
                { code: "hi", name: "Hindi" },
                { code: "ta", name: "Tamil" },
                { code: "ar", name: "Arabic" },
                { code: "nl", name: "Dutch" },
                { code: "tr", name: "Turkish" }
            ]
            delegate: Rectangle {
                id: langItem
                required property var modelData
                required property int index

                width: langList.width
                height: 30
                radius: 8
                color: modelData.code === root.targetLanguage 
                    ? Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.25)
                    : (itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: langItem.modelData.name
                        color: langItem.modelData.code === root.targetLanguage ? (Colours.palette.m3primary || "#00f0ff") : (Colours.palette.m3onSurface || "#ffffff")
                        font.pixelSize: 12
                        font.weight: langItem.modelData.code === root.targetLanguage ? Font.Bold : Font.Normal
                    }

                    MaterialIcon {
                        visible: langItem.modelData.code === root.targetLanguage
                        text: "check"
                        fontStyle: Tokens.font.icon.small
                        color: Colours.palette.m3primary || "#00f0ff"
                    }
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.targetLanguage = langItem.modelData.code;
                        langPopup.visible = false;
                        root.targetLanguageSelected(langItem.modelData.code);
                    }
                }
            }
        }
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

        // Mode: Circle & Select
        Rectangle {
            height: 36
            width: searchBtnRow.implicitWidth + 20
            radius: 18
            color: root.currentMode === "circle" 
                ? (Colours.palette.m3primary || "#00f0ff") 
                : (searchBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: searchBtnRow
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    text: "gesture"
                    fontStyle: Tokens.font.icon.small
                    color: root.currentMode === "circle" ? (Colours.palette.m3onPrimary || "#000000") : (Colours.palette.m3onSurface || "#ffffff")
                }

                Text {
                    text: "Circle & Select"
                    color: root.currentMode === "circle" ? (Colours.palette.m3onPrimary || "#000000") : (Colours.palette.m3onSurface || "#ffffff")
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                id: searchBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    langPopup.visible = false;
                    root.modeChanged("circle");
                }
            }
        }

        // Mode: Live Translate
        Rectangle {
            height: 36
            width: transBtnRow.implicitWidth + 20
            radius: 18
            color: root.currentMode === "translate" 
                ? (Colours.palette.m3primary || "#00f0ff") 
                : (transBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: transBtnRow
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    text: "translate"
                    fontStyle: Tokens.font.icon.small
                    color: root.currentMode === "translate" ? (Colours.palette.m3onPrimary || "#000000") : (Colours.palette.m3onSurface || "#ffffff")
                }

                Text {
                    text: "Live Translate"
                    color: root.currentMode === "translate" ? (Colours.palette.m3onPrimary || "#000000") : (Colours.palette.m3onSurface || "#ffffff")
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                id: transBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.modeChanged("translate");
                }
            }
        }

        // Language Selector: [ Auto-detect ] -> [ Target Language ▾ ]
        RowLayout {
            id: langSelectorRow
            visible: root.currentMode === "translate"
            spacing: 6

            Rectangle {
                width: 1
                height: 20
                color: Colours.palette.m3outlineVariant || "#44475a"
            }

            // From: Auto-Detect
            Rectangle {
                height: 30
                radius: 15
                width: autoDetectText.implicitWidth + 16
                color: Qt.rgba(1, 1, 1, 0.08)
                border.color: Colours.palette.m3outlineVariant || "#44475a"
                border.width: 1

                Text {
                    id: autoDetectText
                    anchors.centerIn: parent
                    text: "Auto-detect"
                    color: Colours.palette.m3onSurfaceVariant || "#a6adc8"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }

            MaterialIcon {
                text: "arrow_forward"
                fontStyle: Tokens.font.icon.small
                color: Colours.palette.m3onSurfaceVariant || "#a6adc8"
            }

            // To: Target Language Chip with Dropdown
            Rectangle {
                id: targetLangBtn
                height: 30
                radius: 15
                width: targetLangRow.implicitWidth + 18
                color: targetLangMouse.containsMouse 
                    ? Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.3) 
                    : Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.16)
                border.color: Colours.palette.m3primary || "#00f0ff"
                border.width: 1

                RowLayout {
                    id: targetLangRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: root.getLanguageName(root.targetLanguage)
                        color: Colours.palette.m3primary || "#00f0ff"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    MaterialIcon {
                        text: "expand_more"
                        fontStyle: Tokens.font.icon.small
                        color: Colours.palette.m3primary || "#00f0ff"
                    }
                }

                MouseArea {
                    id: targetLangMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        langPopup.visible = !langPopup.visible;
                    }
                }
            }
        }

        // Status divider
        Rectangle {
            width: 1
            height: 20
            color: Colours.palette.m3outlineVariant || "#44475a"
        }

        // Status / Hint text
        Text {
            text: root.ocrLoading ? "Extracting screen text..." : root.statusHint
            color: Colours.palette.m3onSurfaceVariant || "#a6adc8"
            font.pixelSize: 12
            font.weight: Font.Normal
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
                onClicked: {
                    langPopup.visible = false;
                    root.closeRequested();
                }
            }
        }
    }
}
