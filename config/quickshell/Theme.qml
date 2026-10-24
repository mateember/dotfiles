pragma Singleton

import QtQuick
import Quickshell

// Single source of truth for the shell's look.
// Values are copied verbatim from ~/.config/cosmic/com.system76.CosmicTheme.Dark/v2/*
// (RON colors are #RRGGBBAA; ron() converts them to Qt's #AARRGGBB).
Singleton {
    id: root

    function ron(c: string): color {
        // "#RRGGBBAA" -> "#AARRGGBB"
        return c.length === 9 ? "#" + c.slice(7, 9) + c.slice(1, 7) : c;
    }
    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // ---- accent (v2/accent) ----
    readonly property color accent: ron("#FFAD00FF")
    readonly property color accentHover: ron("#E09E14FF")
    readonly property color accentPressed: ron("#8A610BFF")
    readonly property color fgOnAccent: ron("#000000FF")

    // ---- background (v2/background) ----
    readonly property color bg: ron("#1B1B1BFF")
    readonly property color bgTransparent: ron("#1B1B1BC8") // v2/transparent_background
    readonly property color fgOnBg: ron("#EEEEEEFF")
    readonly property color bgDivider: ron("#454545FF")
    readonly property color component: ron("#2E2E2EFF")
    readonly property color componentHover: ron("#434343FF")
    readonly property color componentPressed: ron("#585858FF")
    readonly property color componentDivider: ron("#FFFFFF33")
    readonly property color componentBorder: ron("#BEBEBEFF")

    // ---- primary / secondary containers (v2/primary, v2/secondary) ----
    readonly property color primary: ron("#272727FF")
    readonly property color primaryComponent: ron("#363636FF")
    readonly property color primaryHover: ron("#4A4A4AFF")
    readonly property color primaryPressed: ron("#5E5E5EFF")
    readonly property color primaryDivider: ron("#525252FF")
    readonly property color fgOnPrimary: ron("#FFFFFFFF")
    readonly property color secondary: ron("#343434FF")
    readonly property color secondaryComponent: ron("#3B3B3BFF")
    readonly property color secondaryHover: ron("#4F4F4FFF")

    // ---- buttons (v2/button, v2/icon_button, v2/text_button) ----
    readonly property color button: ron("#9E9E9E40")
    readonly property color buttonHover: ron("#63636366")
    readonly property color buttonPressed: ron("#2B2B2B9F")
    readonly property color iconButtonOn: ron("#BEBEBEFF")
    readonly property color iconButtonHover: ron("#63636333")
    readonly property color iconButtonPressed: ron("#16161680")

    // ---- semantic (v2/destructive, v2/success, v2/warning) ----
    readonly property color destructive: ron("#FFA09AFF")
    readonly property color success: ron("#5EDB8CFF")
    readonly property color warning: ron("#FFA37DFF")

    // ---- text ----
    readonly property color text: fgOnBg
    readonly property color textStrong: fgOnPrimary
    readonly property color textDim: ron("#FFFFFFA6") // component.on_disabled

    // v2/shade: rgba(0,0,0,0.32), used to dim the screen behind modal surfaces
    readonly property color shade: Qt.rgba(0, 0, 0, 0.32)

    // ---- panel (com.system76.CosmicPanel.Panel/v1) ----
    // opacity 0.66 applied to background.base, anchor_gap -> margin 4, border_radius 160 (pill)
    readonly property real panelOpacity: 0.66
    readonly property color panelBg: alpha(bg, panelOpacity)
    readonly property int panelMargin: 4
    readonly property int barHeight: 35
    readonly property int barPadding: spaceXxs

    // Popups / launcher / toasts use the frosted transparent background.
    readonly property color popupBg: alpha(bg, 0.96)
    readonly property color popupBorder: componentDivider
    readonly property int popupGap: 6        // space between bar and popup
    readonly property int popupWidth: 320    // default popup width

    // ---- spacing (v2/spacing) ----
    readonly property int spaceNone: 0
    readonly property int spaceXxxs: 4
    readonly property int spaceXxs: 8
    readonly property int spaceXs: 12
    readonly property int spaceS: 16
    readonly property int spaceM: 24
    readonly property int spaceL: 32
    readonly property int spaceXl: 48
    readonly property int spaceXxl: 64
    readonly property int spaceXxxl: 128

    // ---- corner radii ----
    // No corner_radii file in the v2 theme dir, so these are COSMIC's defaults.
    readonly property int radius0: 0
    readonly property int radiusXs: 4
    readonly property int radiusS: 8
    readonly property int radiusM: 16
    readonly property int radiusL: 32
    readonly property int radiusXl: 160

    // ---- window gaps (v2/gaps = (0, 3)) ----
    readonly property int gapInner: 3

    // ---- fonts ----
    // COSMIC interface_font is "Noto Sans Adlam" (likely accidental); Fira Sans is used instead.
    readonly property string fontFamily: "Fira Sans"
    readonly property string monoFamily: "JetBrainsMono Nerd Font"
    readonly property string iconFamily: "Material Symbols Rounded"
    readonly property int fontSizeSmall: 12
    readonly property int fontSize: 14
    readonly property int fontSizeLarge: 16
    readonly property int barFontSize: 16
    readonly property int fontSizeTitle: 20
    readonly property int iconSize: 18

    // ---- motion ----
    readonly property int animFast: 120
    readonly property int animNormal: 200
    readonly property int animSlow: 320
}
