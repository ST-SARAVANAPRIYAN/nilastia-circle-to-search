import Nilastia.Plugins
import QtQuick

SettingsObject {
    property string targetLanguage: "en"
    property bool autoLensOnCircle: false
    property bool iridescentBorder: true
    property real borderGlowWidth: 6.0
    property string lensBrowser: "auto"

    SettingMeta on targetLanguage {
        label: "Translate Target Language"
        description: "Target language code to translate screen text into (e.g. en, es, fr, de, ta, ja)"
        inputType: SettingMeta.TextField
    }

    SettingMeta on autoLensOnCircle {
        label: "Auto-Search On Circle"
        description: "Directly open Google Lens immediately when a lasso circle is completed"
        inputType: SettingMeta.Switch
    }

    SettingMeta on iridescentBorder {
        label: "Iridescent Rainbow Border"
        description: "Show Android-style luminous rainbow border glow on trigger"
        inputType: SettingMeta.Switch
    }

    SettingMeta on borderGlowWidth {
        label: "Border Glow Thickness"
        description: "Width of the glowing screen border perimeter"
        inputType: SettingMeta.Slider
        min: 2.0
        max: 20.0
        step: 1.0
    }

    SettingMeta on lensBrowser {
        label: "Browser Binary"
        description: "Browser to open Lens drawer: 'auto' (detects Brave, Chrome, Chromium, Firefox) or specify binary name"
        inputType: SettingMeta.TextField
    }
}
