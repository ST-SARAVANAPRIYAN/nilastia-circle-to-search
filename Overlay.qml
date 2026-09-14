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

    property var entryPoint: null
    property string pluginDir: (entryPoint && entryPoint.plugin && entryPoint.plugin.dir)
                               ? entryPoint.plugin.dir
                               : Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")
    property var settings: null

    property bool active: false
    property int captureTimestamp: 0

    // Selection and gesture states
    property rect currentCropRect: Qt.rect(0, 0, 0, 0)
    property bool hasSelection: false
    property var lassoPoints: []

    // Iridescent shader animation & trigger wave
    property real shaderTime: 0.0
    property real triggerWave: 0.0
    property real shaderIntensity: 1.0

    // Settings access helpers
    readonly property bool autoLensOnCircle: (settings && settings.autoLensOnCircle !== undefined) ? settings.autoLensOnCircle : true
    readonly property bool showIridescentBorder: (settings && settings.iridescentBorder !== undefined) ? settings.iridescentBorder : true
    readonly property real borderGlowWidth: (settings && settings.borderGlowWidth) ? settings.borderGlowWidth : 6.0
    readonly property string lensBrowser: (settings && settings.lensBrowser) ? settings.lensBrowser : "auto"

    // Continuous smooth shader time animation offloaded to SceneGraph render thread at 144Hz
    NumberAnimation {
        id: shaderTimeAnim
        target: root
        property: "shaderTime"
        from: 0.0
        to: 628.31853
        duration: 314159
        loops: Animation.Infinite
        running: root.active
    }

    // Trigger wave animation sweeping upward on overlay presentation
    NumberAnimation {
        id: triggerWaveAnim
        target: root
        property: "triggerWave"
        from: 0.0
        to: 1.2
        duration: 750
        easing.type: Easing.OutCubic
    }

    function openOverlay() {
        console.log("[CircleToSearch] Opening overlay, triggering screenshot...");
        root.hasSelection = false;
        root.currentCropRect = Qt.rect(0, 0, 0, 0);
        root.lassoPoints = [];
        root.triggerWave = 0.0;
        root.captureTimestamp = Date.now();

        // Capture screen first
        screenshotProcess.running = true;
    }

    function closeOverlay() {
        console.log("[CircleToSearch] Closing overlay...");
        root.active = false;
        root.hasSelection = false;
        root.lassoPoints = [];
        root.triggerWave = 0.0;
    }

    function onScreenshotReady() {
        console.log("[CircleToSearch] Screenshot ready. Displaying overlay immediately...");
        root.active = true;
        triggerWaveAnim.restart();
    }

    function doLensSearch(r: rect) {
        let cropStr = "";
        if (r && r.width > 15 && r.height > 15) {
            cropStr = `${Math.round(r.x)},${Math.round(r.y)},${Math.round(r.width)},${Math.round(r.height)}`;
        }
        console.log("[CircleToSearch] Launching Google Lens with crop:", cropStr);
        if (lensRunnerProcess.running) {
            lensRunnerProcess.running = false;
        }
        lensRunnerProcess.cropArg = cropStr;
        lensRunnerProcess.running = true;
        root.closeOverlay();
    }

    function doCopyImage(r: rect) {
        let cropStr = "";
        if (r && r.width > 15 && r.height > 15) {
            cropStr = `${Math.round(r.x)},${Math.round(r.y)},${Math.round(r.width)},${Math.round(r.height)}`;
        }
        console.log("[CircleToSearch] Copying cropped image to clipboard:", cropStr);
        if (lensCopyProcess.running) {
            lensCopyProcess.running = false;
        }
        lensCopyProcess.cropArg = cropStr;
        lensCopyProcess.running = true;
        root.closeOverlay();
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

    // Process: Google Lens upload & browser opener
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

    // Process: Copy cropped image to clipboard
    Process {
        id: lensCopyProcess
        property string cropArg: ""
        running: false
        command: cropArg ? [
            "python3",
            root.pluginDir + "/backend/lens.py",
            "--image", "/tmp/cts-screen.png",
            "--crop", cropArg,
            "--copy-only"
        ] : [
            "python3",
            root.pluginDir + "/backend/lens.py",
            "--image", "/tmp/cts-screen.png",
            "--copy-only"
        ]
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
                        enabled: root.active && root.hasSelection
                        onActivated: root.doCopyImage(root.currentCropRect)
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
                        opacity: 0.16
                    }

                    // 3. Android Iridescent Screen Border & Moving Gradient Tint Shimmer
                    ShaderEffect {
                        id: iridescentBorder
                        anchors.fill: parent
                        visible: root.showIridescentBorder

                        property real time: root.shaderTime
                        property real intensity: root.shaderIntensity
                        property real borderWidth: root.borderGlowWidth
                        property real glowRadius: root.borderGlowWidth * 5.0
                        property real triggerWave: root.triggerWave
                        property size resolution: Qt.size(win.width, win.height)

                        fragmentShader: Qt.resolvedUrl("shaders/iridescent.qsb")
                    }

                    // 4. Glowing Luminous Lasso Canvas
                    LassoCanvas {
                        id: lassoCanvas
                        anchors.fill: parent
                        z: 4
                        points: root.lassoPoints
                    }

                    // 5. Selection Bounding Box & Corner Handles
                    SelectionBox {
                        id: selBox
                        z: 6
                        targetRect: root.currentCropRect
                        active: root.hasSelection
                    }

                    // 6. Floating Action Bar Pill
                    ActionMenu {
                        id: actionMenu
                        z: 20
                        targetRect: root.currentCropRect
                        active: root.hasSelection

                        onLensRequested: root.doLensSearch(root.currentCropRect)
                        onCopyImageRequested: root.doCopyImage(root.currentCropRect)
                        onCloseRequested: {
                            root.hasSelection = false;
                            root.currentCropRect = Qt.rect(0, 0, 0, 0);
                        }
                    }

                    // 7. Gesture MouseArea for Circling and Selecting
                    MouseArea {
                        id: gestureArea
                        anchors.fill: parent
                        z: 5
                        acceptedButtons: Qt.LeftButton
                        hoverEnabled: false

                        onPressed: (mouse) => {
                            root.lassoPoints = [{ "x": mouse.x, "y": mouse.y }];
                            root.hasSelection = false;
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

                            let minX = 99999, minY = 99999, maxX = 0, maxY = 0;
                            for (let i = 0; i < pts.length; i++) {
                                minX = Math.min(minX, pts[i].x);
                                minY = Math.min(minY, pts[i].y);
                                maxX = Math.max(maxX, pts[i].x);
                                maxY = Math.max(maxY, pts[i].y);
                            }

                            let w = maxX - minX;
                            let h = maxY - minY;
                            let closingDist = Math.hypot(pn.x - p0.x, pn.y - p0.y);

                            // Circle / Loop Detection
                            let isLoop = (pts.length > 8) && (w > 30 && h > 30) && (closingDist < Math.max(55, 0.45 * Math.max(w, h)));

                            if (isLoop) {
                                console.log("[CircleToSearch] Closed circle gesture detected!");
                                let crop = Qt.rect(
                                    Math.max(0, minX - 12),
                                    Math.max(0, minY - 12),
                                    Math.min(win.width - minX, w + 24),
                                    Math.min(win.height - minY, h + 24)
                                );
                                root.currentCropRect = crop;
                                root.hasSelection = true;
                                if (root.autoLensOnCircle) {
                                    root.doLensSearch(crop);
                                }
                                return;
                            }

                            // Freeform Region Drag Selection
                            if (w > 20 && h > 20) {
                                let crop = Qt.rect(
                                    Math.max(0, minX - 10),
                                    Math.max(0, minY - 10),
                                    Math.min(win.width - minX, w + 20),
                                    Math.min(win.height - minY, h + 20)
                                );
                                root.currentCropRect = crop;
                                root.hasSelection = true;
                            } else {
                                root.hasSelection = false;
                                root.lassoPoints = [];
                            }
                        }
                    }

                    // 8. Android CTS Bottom Navigation Bar
                    BottomBar {
                        id: bottomBar
                        z: 25
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 28

                        onCloseRequested: root.closeOverlay()
                    }
                }
            }
        }
    }
}
