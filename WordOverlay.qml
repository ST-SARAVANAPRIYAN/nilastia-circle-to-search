import QtQuick
import QtQuick.Layouts
import Nilastia
import Nilastia.Config
import qs.components
import qs.services

Item {
    id: root

    property var words: []
    property var selectedIndices: []
    readonly property bool hasSelection: selectedIndices && selectedIndices.length > 0
    readonly property bool selectionActive: hasSelection
    property string selectedText: ""
    property rect selectedBounds: Qt.rect(0, 0, 0, 0)

    signal selectionChanged(string text, rect bounds)
    signal wordTapped(var word)
    signal wordSelected(var word, bool additive)

    function getSelectedBoundingBox() {
        return selectedBounds;
    }

    function getSelectedText() {
        return selectedText;
    }

    function clearSelection() {
        selectedIndices = [];
        selectedText = "";
        selectedBounds = Qt.rect(0, 0, 0, 0);
        root.selectionChanged("", Qt.rect(0, 0, 0, 0));
    }

    function isSelected(idx) {
        return selectedIndices.indexOf(idx) !== -1;
    }

    function updateSelectionFromIndices(indices) {
        if (!indices || indices.length === 0) {
            clearSelection();
            return;
        }

        // Sort indices numerically to maintain reading order
        let sorted = indices.slice().sort((a, b) => a - b);
        selectedIndices = sorted;

        let txtList = [];
        let minX = 99999, minY = 99999, maxX = 0, maxY = 0;

        for (let i of sorted) {
            let w = words[i];
            if (!w) continue;
            txtList.push(w.text);
            minX = Math.min(minX, w.x);
            minY = Math.min(minY, w.y);
            maxX = Math.max(maxX, w.x + w.w);
            maxY = Math.max(maxY, w.y + w.h);
        }

        selectedText = txtList.join(" ");
        selectedBounds = Qt.rect(minX - 4, minY - 4, (maxX - minX) + 8, (maxY - minY) + 8);
        root.selectionChanged(selectedText, selectedBounds);
    }

    function selectRange(startIdx, endIdx) {
        if (startIdx < 0 || endIdx < 0 || !words || words.length === 0) return;
        let s = Math.min(startIdx, endIdx);
        let e = Math.max(startIdx, endIdx);
        s = Math.max(0, Math.min(s, words.length - 1));
        e = Math.max(0, Math.min(e, words.length - 1));

        let list = [];
        for (let i = s; i <= e; i++) {
            list.push(i);
        }
        updateSelectionFromIndices(list);
    }

    function findClosestWordIndex(px, py) {
        if (!words || words.length === 0) return -1;
        let closestIdx = -1;
        let minDist = 999999;

        for (let i = 0; i < words.length; i++) {
            let w = words[i];
            let cx = w.x + w.w / 2;
            let cy = w.y + w.h / 2;
            let d = Math.hypot(px - cx, py - cy);
            if (d < minDist) {
                minDist = d;
                closestIdx = i;
            }
        }
        return closestIdx;
    }

    // Line swipe gesture: checks if swipe stroke crosses words
    function selectWordsIntersectingStroke(strokePoints) {
        if (!words || words.length === 0 || !strokePoints || strokePoints.length < 2) return false;

        let hitIndices = [];
        for (let i = 0; i < words.length; i++) {
            let w = words[i];
            let wx1 = w.x - 6, wy1 = w.y - 4, wx2 = w.x + w.w + 6, wy2 = w.y + w.h + 4;

            // Check if any stroke point touches word
            let hit = false;
            for (let p of strokePoints) {
                if (p.x >= wx1 && p.x <= wx2 && p.y >= wy1 && p.y <= wy2) {
                    hit = true;
                    break;
                }
            }

            if (hit) {
                hitIndices.push(i);
            }
        }

        if (hitIndices.length > 0) {
            let minIdx = Math.min(...hitIndices);
            let maxIdx = Math.max(...hitIndices);
            selectRange(minIdx, maxIdx);
            return true;
        }
        return false;
    }

    // Word highlighting delegates
    Repeater {
        model: root.words

        Rectangle {
            id: wordRect
            required property var modelData
            required property int index

            x: modelData.x - 2
            y: modelData.y - 1
            width: modelData.w + 4
            height: modelData.h + 2
            radius: 3

            readonly property bool selected: root.isSelected(index)

            color: selected
                ? (Colours.palette.m3primaryContainer || "#3b82f6")
                : (wordHoverArea.containsMouse ? Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.2) : "transparent")

            opacity: selected ? 0.72 : (wordHoverArea.containsMouse ? 0.9 : 0.0)

            border.color: selected
                ? (Colours.palette.m3primary || "#60a5fa")
                : (wordHoverArea.containsMouse ? Colours.palette.m3primary : "transparent")
            border.width: selected ? 1.0 : 0

            Behavior on opacity { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: 100 } }

            MouseArea {
                id: wordHoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.IBeamCursor

                onClicked: (mouse) => {
                    if (mouse.modifiers & Qt.ShiftModifier && root.selectedIndices.length > 0) {
                        let curStart = root.selectedIndices[0];
                        root.selectRange(curStart, wordRect.index);
                    } else {
                        root.updateSelectionFromIndices([wordRect.index]);
                    }
                    root.wordTapped(wordRect.modelData);
                }
            }
        }
    }

    // Android Text Selection Handles
    Item {
        id: handlesLayer
        anchors.fill: parent
        z: 15
        visible: root.hasSelection

        readonly property var startWord: (root.hasSelection && root.words[root.selectedIndices[0]]) ? root.words[root.selectedIndices[0]] : null
        readonly property var endWord: (root.hasSelection && root.words[root.selectedIndices[root.selectedIndices.length - 1]]) ? root.words[root.selectedIndices[root.selectedIndices.length - 1]] : null

        // 1. Start Handle (Left Teardrop / Pin)
        Item {
            id: startHandleItem
            visible: handlesLayer.startWord !== null
            x: handlesLayer.startWord ? (handlesLayer.startWord.x - 6) : 0
            y: handlesLayer.startWord ? (handlesLayer.startWord.y + handlesLayer.startWord.h) : 0
            width: 24
            height: 32

            // Stem line pointing up to the text baseline
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: 2.5
                height: 8
                color: Colours.palette.m3primary || "#4285F4"
            }

            // Teardrop circular handle
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 18
                height: 18
                radius: 9
                color: startDragArea.pressed ? Colours.palette.m3onPrimary : (Colours.palette.m3primary || "#4285F4")
                border.color: Colours.palette.m3primary || "#4285F4"
                border.width: 2

                // Drop shadow
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: 11
                    color: "transparent"
                    border.color: Qt.rgba(0, 0, 0, 0.25)
                    border.width: 1
                    z: -1
                }
            }

            MouseArea {
                id: startDragArea
                anchors.fill: parent
                cursorShape: Qt.SizeHorCursor
                drag.target: null

                onPositionChanged: (mouse) => {
                    if (pressed) {
                        let globalPos = mapToItem(root, mouse.x, mouse.y);
                        let closest = root.findClosestWordIndex(globalPos.x, globalPos.y);
                        if (closest !== -1 && root.selectedIndices.length > 0) {
                            let curEnd = root.selectedIndices[root.selectedIndices.length - 1];
                            root.selectRange(closest, curEnd);
                        }
                    }
                }
            }
        }

        // 2. End Handle (Right Teardrop / Pin)
        Item {
            id: endHandleItem
            visible: handlesLayer.endWord !== null
            x: handlesLayer.endWord ? (handlesLayer.endWord.x + handlesLayer.endWord.w - 18) : 0
            y: handlesLayer.endWord ? (handlesLayer.endWord.y + handlesLayer.endWord.h) : 0
            width: 24
            height: 32

            // Stem line pointing up to the text baseline
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: 2.5
                height: 8
                color: Colours.palette.m3primary || "#4285F4"
            }

            // Teardrop circular handle
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 18
                height: 18
                radius: 9
                color: endDragArea.pressed ? Colours.palette.m3onPrimary : (Colours.palette.m3primary || "#4285F4")
                border.color: Colours.palette.m3primary || "#4285F4"
                border.width: 2

                // Drop shadow
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: 11
                    color: "transparent"
                    border.color: Qt.rgba(0, 0, 0, 0.25)
                    border.width: 1
                    z: -1
                }
            }

            MouseArea {
                id: endDragArea
                anchors.fill: parent
                cursorShape: Qt.SizeHorCursor
                drag.target: null

                onPositionChanged: (mouse) => {
                    if (pressed) {
                        let globalPos = mapToItem(root, mouse.x, mouse.y);
                        let closest = root.findClosestWordIndex(globalPos.x, globalPos.y);
                        if (closest !== -1 && root.selectedIndices.length > 0) {
                            let curStart = root.selectedIndices[0];
                            root.selectRange(curStart, closest);
                        }
                    }
                }
            }
        }
    }
}
