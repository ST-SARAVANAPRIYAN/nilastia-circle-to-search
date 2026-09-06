import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Nilastia
import Nilastia.Config
import qs.components
import qs.components.containers
import qs.components.misc
import qs.components.controls
import qs.services
import qs.utils
import saravana.circletosearch 1.0

Scope {
    id: root

    property string pluginDir: "/home/saravana/projects/nilastia-circle-to-search"
    property var settings: null

    property bool active: false
    property string mode: "circle" // "circle" or "translate"
    property int captureTimestamp: 0

    // Selection and gesture states
    property rect currentCropRect: Qt.rect(0, 0, 0, 0)
    property bool hasSelection: false
    property var lassoPoints: []
    property string selectedText: ""

    // OCR & Translation states
    property var ocrWords: []
    property var ocrLines: []
    property var translatedLines: []
    property bool isOcrLoading: false
    property bool isTranslating: false

    // Iridescent shader animation
    property real shaderTime: 0.0
    property real shaderIntensity: 1.0

    // Settings access helpers
    property string targetLanguage: (settings && settings.targetLanguage) ? settings.targetLanguage : "en"
    readonly property bool autoLensOnCircle: (settings && settings.autoLensOnCircle !== undefined) ? settings.autoLensOnCircle : true
    readonly property bool showIridescentBorder: (settings && settings.iridescentBorder !== undefined) ? settings.iridescentBorder : true
    readonly property real borderGlowWidth: (settings && settings.borderGlowWidth) ? settings.borderGlowWidth : 4.0
    readonly property string lensBrowser: (settings && settings.lensBrowser) ? settings.lensBrowser : "auto"

    function setTargetLanguage(code) {
        console.log("[CircleToSearch] Target language updated to:", code);
        root.targetLanguage = code;
        if (settings) {
            settings.targetLanguage = code;
        }
        if (root.mode === "translate" || root.translatedLines.length > 0) {
            root.triggerLiveTranslate();
        }
    }

    // Timer driving shader animation at 60fps
    Timer {
        id: animTimer
        interval: 16
        running: root.active
        repeat: true
        onTriggered: {
            root.shaderTime += 0.03;
        }
    }

    function openOverlay() {
        console.log("[CircleToSearch] Opening overlay, triggering screenshot...");
        root.hasSelection = false;
        root.currentCropRect = Qt.rect(0, 0, 0, 0);
        root.lassoPoints = [];
        root.selectedText = "";
        root.ocrWords = [];
        root.ocrLines = [];
        root.translatedLines = [];
        root.mode = "circle";
        root.captureTimestamp = Date.now();

        // Capture screen first
        screenshotProcess.running = true;
    }

    function closeOverlay() {
        console.log("[CircleToSearch] Closing overlay...");
        root.active = false;
        root.hasSelection = false;
        root.lassoPoints = [];
    }

    function onScreenshotReady() {
        console.log("[CircleToSearch] Screenshot ready. Displaying overlay and starting OCR...");
        root.active = true;
        root.isOcrLoading = true;
        ocrProcess.running = true;
    }

    function doLensSearch(r: rect) {
        let cropStr = "";
        if (r && r.width > 15 && r.height > 15) {
            cropStr = `${Math.round(r.x)},${Math.round(r.y)},${Math.round(r.width)},${Math.round(r.height)}`;
        }
        console.log("[CircleToSearch] Launching Google Lens with crop:", cropStr);
        lensRunnerProcess.cropArg = cropStr;
        lensRunnerProcess.running = true;
        root.closeOverlay();
    }

    function doCopyText(text: string) {
        if (!text) text = root.selectedText;
        if (!text) return;
        console.log("[CircleToSearch] Copying text to clipboard:", text);
        clipboardWriter.textToCopy = text;
        clipboardWriter.running = true;

        if (typeof Toaster !== "undefined" && Toaster) {
            Toaster.toast("Circle to Search", "Copied to clipboard:\n" + (text.length > 60 ? text.substring(0, 60) + "..." : text), "content_copy");
        }
        root.closeOverlay();
    }

    function doWebSearch(text: string) {
        if (!text) text = root.selectedText;
        if (!text) return;
        let url = "https://www.google.com/search?q=" + encodeURIComponent(text);
        console.log("[CircleToSearch] Opening web search:", url);
        webSearchProcess.searchUrl = url;
        webSearchProcess.running = true;
        root.closeOverlay();
    }

    function triggerLiveTranslate() {
        if (root.ocrLines.length === 0) {
            console.log("[CircleToSearch] No OCR lines available to translate yet.");
            return;
        }
        console.log("[CircleToSearch] Starting live batch translation of", root.ocrLines.length, "lines to", root.targetLanguage);
        root.isTranslating = true;
        transProcess.running = true;
    }

    function extractTextInRect(r: rect): string {
        if (!root.ocrWords || root.ocrWords.length === 0) return "";
        let hits = [];
        for (let w of root.ocrWords) {
            let cx = w.x + w.w / 2;
            let cy = w.y + w.h / 2;
            if (cx >= r.x && cx <= r.x + r.width && cy >= r.y && cy <= r.y + r.height) {
                hits.push(w);
            }
        }
        // Sort top-to-bottom, left-to-right
        hits.sort((a, b) => {
            let dy = Math.abs(a.y - b.y);
            if (dy < 12) return a.x - b.x;
            return a.y - b.y;
        });
        return hits.map(w => w.text).join(" ");
    }

    // Global shortcut
    // qmllint disable unresolved-type
    CustomShortcut {
        name: "circletosearch"
        description: "Open Circle to Search & Google Lens"
        onPressed: root.openOverlay()
    }
    // qmllint enable unresolved-type

    // IPC Handler
    IpcHandler {
        target: "circletosearch"
        function open() {
            root.openOverlay();
        }
        function close() {
            root.closeOverlay();
        }
    }

    // Process: Screenshot capture via grim
    Process {
        id: screenshotProcess
        running: false
        command: ["grim", "/tmp/cts-screen.png"]
        onExited: (code, status) => {
            if (code === 0) {
                root.onScreenshotReady();
            } else {
                console.error("[CircleToSearch] Screenshot capture failed with code:", code);
            }
        }
    }

    // Process: Fast OCR via tesseract TSV
    Process {
        id: ocrProcess
        running: false
        command: ["python3", root.pluginDir + "/backend/ocr.py", "--image", "/tmp/cts-screen.png"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.isOcrLoading = false;
                try {
                    let res = JSON.parse(text);
                    if (res.status === "ok") {
                        root.ocrWords = res.words || [];
                        root.ocrLines = res.lines || [];
                        console.log("[CircleToSearch] OCR detected", root.ocrWords.length, "words and", root.ocrLines.length, "lines.");
                        if (root.mode === "translate") {
                            root.triggerLiveTranslate();
                        }
                    }
                } catch (e) {
                    console.error("[CircleToSearch] Failed to parse OCR output:", e);
                }
            }
        }
    }

    // Process: Google Lens upload & docked app window opener
    Process {
        id: lensRunnerProcess
        property string cropArg: ""
        running: false
        command: cropArg ? [
            "python3",
            root.pluginDir + "/backend/lens.py",
            "--image", "/tmp/cts-screen.png",
            "--crop", cropArg,
            "--browser", root.lensBrowser
        ] : [
            "python3",
            root.pluginDir + "/backend/lens.py",
            "--image", "/tmp/cts-screen.png",
            "--browser", root.lensBrowser
        ]
        stdout: StdioCollector {
            onStreamFinished: console.log("[CircleToSearch] Lens backend response:\n", text)
        }
        stderr: StdioCollector {
            onStreamFinished: console.error("[CircleToSearch] Lens backend error:\n", text)
        }
    }

    // Process: Batch Translation
    Process {
        id: transProcess
        running: false
        command: ["python3", root.pluginDir + "/backend/translate.py", "--mode", "batch", "--batch-file", "/tmp/cts-ocr.json", "--target", root.targetLanguage]
        stdout: StdioCollector {
            onStreamFinished: {
                root.isTranslating = false;
                try {
                    let res = JSON.parse(text);
                    if (res.status === "ok") {
                        root.translatedLines = res.results || [];
                        console.log("[CircleToSearch] Received", root.translatedLines.length, "translated cards.");
                    }
                } catch (e) {
                    console.error("[CircleToSearch] Failed to parse translation response:", e);
                }
            }
        }
    }

    // Process: Single Text Translation
    Process {
        id: transSingleProcess
        property string textToTranslate: ""
        running: false
        command: ["python3", root.pluginDir + "/backend/translate.py", "--mode", "single", "--text", textToTranslate, "--target", root.targetLanguage]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let res = JSON.parse(text);
                    if (res.status === "ok" && res.translated) {
                        root.translatedLines = [{
                            "id": "single",
                            "original": res.original,
                            "translated": res.translated,
                            "x": Math.round(root.currentCropRect.x),
                            "y": Math.round(root.currentCropRect.y),
                            "w": Math.round(root.currentCropRect.width),
                            "h": Math.round(root.currentCropRect.height)
                        }];
                    }
                } catch (e) {
                    console.error("[CircleToSearch] Single translation error:", e);
                }
            }
        }
    }

    // Process: Clipboard copy
    Process {
        id: clipboardWriter
        property string textToCopy: ""
        running: false
        command: ["wl-copy", textToCopy]
    }

    // Process: Web search
    Process {
        id: webSearchProcess
        property string searchUrl: ""
        running: false
        command: ["xdg-open", searchUrl]
    }

    // Fullscreen Overlay Window
    LazyLoader {
        active: root.active

        Variants {
            model: Screens.screens

            StyledWindow {
                id: win
                required property ShellScreen modelData
                screen: modelData

                name: "circle-to-search-overlay"
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                Item {
                    id: screenContainer
                    anchors.fill: parent

                    // Keyboard shortcuts
                    Shortcut {
                        sequence: "Escape"
                        enabled: root.active
                        onActivated: root.closeOverlay()
                    }

                    Shortcut {
                        sequence: "Return"
                        enabled: root.active && root.hasSelection
                        onActivated: root.doLensSearch(root.currentCropRect)
                    }

                    Shortcut {
                        sequence: "Enter"
                        enabled: root.active && root.hasSelection
                        onActivated: root.doLensSearch(root.currentCropRect)
                    }

                    Shortcut {
                        sequence: "Ctrl+C"
                        enabled: root.active && (root.hasSelection || wordOverlay.selectionActive)
                        onActivated: {
                            let txt = wordOverlay.selectionActive ? wordOverlay.getSelectedText() : root.selectedText;
                            root.doCopyText(txt);
                        }
                    }

                    // 1. Frozen Screenshot Background
                    Image {
                        id: frozenBg
                        anchors.fill: parent
                        source: root.active ? ("file:///tmp/cts-screen.png?t=" + root.captureTimestamp) : ""
                        cache: false
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                    }

                    // 2. Cinematic Dimming Vignette
                    Rectangle {
                        anchors.fill: parent
                        color: "#000000"
                        opacity: 0.28
                    }

                    // 3. Android Iridescent Screen Border Shimmer Effect
                    ShaderEffect {
                        id: iridescentBorder
                        anchors.fill: parent
                        visible: root.showIridescentBorder

                        property real time: root.shaderTime
                        property real intensity: root.shaderIntensity
                        property real borderWidth: root.borderGlowWidth
                        property real glowRadius: root.borderGlowWidth * 5.0
                        property size resolution: Qt.size(win.width, win.height)

                        fragmentShader: Qt.resolvedUrl("shaders/iridescent.qsb")
                    }

                    // 4. Interactive Word Overlay Chips & Drag Handles
                    WordOverlay {
                        id: wordOverlay
                        anchors.fill: parent
                        z: 3
                        words: root.ocrWords

                        onSelectionChanged: (text, bounds) => {
                            if (bounds.width > 0 && bounds.height > 0) {
                                root.currentCropRect = bounds;
                                root.selectedText = text;
                                root.hasSelection = true;
                            }
                        }

                        onWordSelected: (word, additive) => {
                            let selRect = wordOverlay.getSelectedBoundingBox();
                            root.currentCropRect = selRect;
                            root.selectedText = wordOverlay.getSelectedText();
                            root.hasSelection = true;
                        }
                    }

                    // 5. In-Place Live Translation Cards
                    LiveTranslateOverlay {
                        id: liveTransOverlay
                        anchors.fill: parent
                        z: 16
                        active: root.mode === "translate"
                        translatedLines: root.translatedLines
                        onTextCopied: (txt) => root.doCopyText(txt)
                    }

                    // 6. Glowing Luminous Lasso Canvas
                    LassoCanvas {
                        id: lassoCanvas
                        anchors.fill: parent
                        z: 4
                        points: root.lassoPoints
                    }

                    // 7. Selection Bounding Box & Corner Handles (shown for image/region crops)
                    SelectionBox {
                        id: selBox
                        z: 6
                        targetRect: root.currentCropRect
                        active: root.hasSelection && !wordOverlay.selectionActive
                    }

                    // 8. Floating Action Bar Pill
                    ActionMenu {
                        id: actionMenu
                        z: 20
                        targetRect: root.currentCropRect
                        active: root.hasSelection
                        textToSearch: root.selectedText

                        onLensRequested: root.doLensSearch(root.currentCropRect)
                        onCopyRequested: root.doCopyText(root.selectedText)
                        onSearchRequested: root.doWebSearch(root.selectedText)
                        onTranslateRequested: {
                            if (root.selectedText) {
                                transSingleProcess.textToTranslate = root.selectedText;
                                transSingleProcess.running = true;
                                root.mode = "translate";
                            }
                        }
                    }

                    // 9. Gesture MouseArea for Circling, Swiping & Tapping
                    MouseArea {
                        id: gestureArea
                        anchors.fill: parent
                        z: 5
                        acceptedButtons: Qt.LeftButton
                        hoverEnabled: false

                        onPressed: (mouse) => {
                            root.lassoPoints = [{ "x": mouse.x, "y": mouse.y }];
                            root.hasSelection = false;
                            wordOverlay.clearSelection();
                        }

                        onPositionChanged: (mouse) => {
                            if (pressed) {
                                let pts = root.lassoPoints.slice();
                                pts.push({ "x": mouse.x, "y": mouse.y });
                                root.lassoPoints = pts;
                            }
                        }

                        onReleased: (mouse) => {
                            let pts = root.lassoPoints;
                            if (!pts || pts.length === 0) return;

                            let p0 = pts[0];
                            let pn = pts[pts.length - 1];
                            let totalDist = Math.hypot(pn.x - p0.x, pn.y - p0.y);

                            // 1. Single Tap Detection (minimal displacement)
                            if (pts.length <= 6 && totalDist < 18) {
                                let closestIdx = wordOverlay.findClosestWordIndex(mouse.x, mouse.y);
                                if (closestIdx !== -1 && root.ocrWords && root.ocrWords[closestIdx]) {
                                    let w = root.ocrWords[closestIdx];
                                    let cx = w.x + w.w / 2;
                                    let cy = w.y + w.h / 2;
                                    if (Math.hypot(mouse.x - cx, mouse.y - cy) < Math.max(w.w * 0.8, w.h * 1.5, 30)) {
                                        wordOverlay.updateSelectionFromIndices([closestIdx]);
                                        root.currentCropRect = wordOverlay.getSelectedBoundingBox();
                                        root.selectedText = wordOverlay.getSelectedText();
                                        root.hasSelection = true;
                                        root.lassoPoints = [];
                                        return;
                                    }
                                }
                                root.hasSelection = false;
                                wordOverlay.clearSelection();
                                root.lassoPoints = [];
                                return;
                            }

                            // 2. Gesture Path & Bounding Box Analysis
                            let minX = 99999, minY = 99999, maxX = 0, maxY = 0;
                            let pathLen = 0;
                            for (let i = 0; i < pts.length; i++) {
                                minX = Math.min(minX, pts[i].x);
                                minY = Math.min(minY, pts[i].y);
                                maxX = Math.max(maxX, pts[i].x);
                                maxY = Math.max(maxY, pts[i].y);
                                if (i > 0) {
                                    pathLen += Math.hypot(pts[i].x - pts[i-1].x, pts[i].y - pts[i-1].y);
                                }
                            }

                            let w = maxX - minX;
                            let h = maxY - minY;
                            let closingDist = Math.hypot(pn.x - p0.x, pn.y - p0.y);

                            // 3. Circle / Loop Detection
                            // Starts and ends near each other with sufficient 2D area
                            let isLoop = (pts.length > 8) && (w > 35 && h > 35) && (closingDist < Math.max(50, 0.45 * Math.max(w, h)));

                            if (isLoop) {
                                console.log("[CircleToSearch] Closed circle gesture detected! Directly opening Google Lens...");
                                let crop = Qt.rect(
                                    Math.max(0, minX - 12),
                                    Math.max(0, minY - 12),
                                    Math.min(win.width - minX, w + 24),
                                    Math.min(win.height - minY, h + 24)
                                );
                                root.currentCropRect = crop;
                                root.selectedText = root.extractTextInRect(crop);
                                root.hasSelection = true;
                                root.doLensSearch(crop);
                                return;
                            }

                            // 4. Line / Swipe Gesture across text words
                            let hitWords = wordOverlay.selectWordsIntersectingStroke(pts);
                            if (hitWords) {
                                console.log("[CircleToSearch] Line swipe across text detected! Selected words with handles.");
                                root.currentCropRect = wordOverlay.getSelectedBoundingBox();
                                root.selectedText = wordOverlay.getSelectedText();
                                root.hasSelection = true;
                                root.lassoPoints = [];
                                return;
                            }

                            // 5. Freeform Region Selection
                            if (w > 20 && h > 20) {
                                let crop = Qt.rect(
                                    Math.max(0, minX - 12),
                                    Math.max(0, minY - 12),
                                    Math.min(win.width - minX, w + 24),
                                    Math.min(win.height - minY, h + 24)
                                );
                                root.currentCropRect = crop;
                                root.selectedText = root.extractTextInRect(crop);
                                root.hasSelection = true;
                            }
                        }
                    }

                    // 10. Android CTS Bottom Navigation Bar
                    BottomBar {
                        id: bottomBar
                        z: 25
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 28
                        currentMode: root.mode
                        ocrLoading: root.isOcrLoading
                        targetLanguage: root.targetLanguage

                        onModeChanged: (m) => {
                            root.mode = m;
                            if (m === "translate") {
                                root.triggerLiveTranslate();
                            }
                        }

                        onTargetLanguageSelected: (langCode) => {
                            root.setTargetLanguage(langCode);
                        }

                        onCloseRequested: root.closeOverlay()
                    }
                }
            }
        }
    }
}
