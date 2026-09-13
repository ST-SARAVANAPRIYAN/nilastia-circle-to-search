import QtQuick
import QtQuick.Layouts
import Nilastia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: root

    property var settings

    spacing: Tokens.spacing.medium

    readonly property var browserCatalog: [
        { bin: "brave", name: "Brave Browser", icon: "web" },
        { bin: "google-chrome-stable", name: "Google Chrome", icon: "web" },
        { bin: "google-chrome", name: "Google Chrome", icon: "web" },
        { bin: "chromium", name: "Chromium", icon: "web" },
        { bin: "firefox", name: "Mozilla Firefox", icon: "web" },
        { bin: "zen-browser", name: "Zen Browser", icon: "web" },
        { bin: "zen", name: "Zen Browser", icon: "web" },
        { bin: "librewolf", name: "LibreWolf", icon: "web" },
        { bin: "vivaldi", name: "Vivaldi", icon: "web" },
        { bin: "microsoft-edge-stable", name: "Microsoft Edge", icon: "web" }
    ]

    property list<MenuItem> browserMenuItems: [
        MenuItem {
            text: "Auto-detect (System)"
            value: "auto"
            icon: "travel_explore"
        }
    ]

    function rebuildBrowserMenu(detectedBins) {
        let items = [];
        let autoItem = Qt.createQmlObject('import qs.components.controls; MenuItem { text: "Auto-detect (System)"; value: "auto"; icon: "travel_explore" }', root);
        items.push(autoItem);

        let addedBins = new Set();
        for (let entry of root.browserCatalog) {
            if (detectedBins.indexOf(entry.bin) !== -1 && !addedBins.has(entry.bin)) {
                addedBins.add(entry.bin);
                let item = Qt.createQmlObject('import qs.components.controls; MenuItem {}', root);
                item.text = entry.name;
                item.value = entry.bin;
                item.icon = entry.icon;
                items.push(item);
            }
        }

        let xdgItem = Qt.createQmlObject('import qs.components.controls; MenuItem { text: "System Default (xdg-open)"; value: "xdg-open"; icon: "open_in_new" }', root);
        items.push(xdgItem);

        root.browserMenuItems = items;
    }

    Process {
        id: detector
        running: false
        command: ["sh", "-c", "for b in brave google-chrome-stable google-chrome chromium firefox zen-browser zen librewolf vivaldi microsoft-edge-stable; do which $b 2>/dev/null; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n");
                let detected = [];
                for (let line of lines) {
                    line = line.trim();
                    if (!line) continue;
                    let bin = line.split("/").pop();
                    if (bin && detected.indexOf(bin) === -1) {
                        detected.push(bin);
                    }
                }
                root.rebuildBrowserMenu(detected);
            }
        }
    }

    Component.onCompleted: {
        detector.running = true;
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        ToggleRow {
            first: true
            text: "Auto-Search On Circle"
            subtext: "Directly open Google Lens immediately when a circle gesture is completed"
            checked: root.settings ? (root.settings.autoLensOnCircle !== undefined ? root.settings.autoLensOnCircle : true) : true
            onToggled: {
                if (root.settings) root.settings.autoLensOnCircle = checked;
            }
        }

        ToggleRow {
            text: "Iridescent Border & Screen Tint"
            subtext: "Display luminous Android-style rainbow border and moving gradient tint on trigger"
            checked: root.settings ? (root.settings.iridescentBorder !== undefined ? root.settings.iridescentBorder : true) : true
            onToggled: {
                if (root.settings) root.settings.iridescentBorder = checked;
            }
        }

        SliderRow {
            label: "Border Glow Thickness"
            value: root.settings ? ((root.settings.borderGlowWidth || 6.0) - 2.0) / 18.0 : 0.22
            valueLabel: root.settings ? (root.settings.borderGlowWidth || 6.0).toFixed(0) + " px" : "6 px"
            onMoved: v => {
                if (root.settings) root.settings.borderGlowWidth = 2.0 + v * 18.0;
            }
        }

        SelectRow {
            last: true
            label: "Browser Application"
            subtext: "Browser used to open Google Lens search results"
            menuItems: root.browserMenuItems
            active: {
                let currentVal = (root.settings && root.settings.lensBrowser) ? root.settings.lensBrowser : "auto";
                for (let i = 0; i < root.browserMenuItems.length; i++) {
                    if (root.browserMenuItems[i].value === currentVal) {
                        return root.browserMenuItems[i];
                    }
                }
                return root.browserMenuItems[0] ?? null;
            }
            onSelected: item => {
                if (root.settings && item) {
                    root.settings.lensBrowser = item.value;
                }
            }
        }
    }
}
