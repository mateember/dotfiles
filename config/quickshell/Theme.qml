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
    property color accent: ron("#FFAD00FF")
    property color accentHover: ron("#E09E14FF")
    property color accentPressed: ron("#8A610BFF")
    property color fgOnAccent: ron("#000000FF")
    readonly property color accentText: fgOnAccent

    // ---- background (v2/background) ----
    property color bg: ron("#1B1B1BFF")
    readonly property color bgTransparent: alpha(bg, 200 / 255) // v2/transparent_background (#1B1B1BC8)
    property color fgOnBg: ron("#EEEEEEFF")
    property color bgDivider: ron("#454545FF")
    // Translucent overlays calibrated to match COSMIC's #2E2E2E / #434343 / #585858
    // over #1B1B1B at 0.96 opacity, while scaling naturally with surfaceTint/surfaceStrength.
    property color surfaceTint: "#FFFFFF"
    property real surfaceStrength: 1.0
    property color borderColor: "#FFFFFF"
    property real borderAlpha: 0.20
    readonly property color component: Qt.rgba(surfaceTint.r, surfaceTint.g, surfaceTint.b, Math.min(1, 0.083 * surfaceStrength))
    readonly property color componentHover: Qt.rgba(surfaceTint.r, surfaceTint.g, surfaceTint.b, Math.min(1, 0.175 * surfaceStrength))
    readonly property color componentPressed: Qt.rgba(surfaceTint.r, surfaceTint.g, surfaceTint.b, Math.min(1, 0.268 * surfaceStrength))
    readonly property color componentDivider: Qt.rgba(borderColor.r, borderColor.g, borderColor.b, borderAlpha)
    readonly property color divider: componentDivider
    property color componentBorder: ron("#BEBEBEFF")

    // ---- primary / secondary containers (v2/primary, v2/secondary) ----
    property color primary: ron("#272727FF")
    readonly property color primaryComponent: Qt.rgba(surfaceTint.r, surfaceTint.g, surfaceTint.b, Math.min(1, 0.118 * surfaceStrength))
    readonly property color primaryHover: Qt.rgba(surfaceTint.r, surfaceTint.g, surfaceTint.b, Math.min(1, 0.206 * surfaceStrength))
    readonly property color primaryPressed: Qt.rgba(surfaceTint.r, surfaceTint.g, surfaceTint.b, Math.min(1, 0.294 * surfaceStrength))
    property color primaryDivider: ron("#525252FF")
    property color fgOnPrimary: ron("#FFFFFFFF")
    property color secondary: ron("#343434FF")
    readonly property color secondaryComponent: Qt.rgba(surfaceTint.r, surfaceTint.g, surfaceTint.b, Math.min(1, 0.14 * surfaceStrength))
    readonly property color secondaryHover: Qt.rgba(surfaceTint.r, surfaceTint.g, surfaceTint.b, Math.min(1, 0.228 * surfaceStrength))

    // ---- buttons (v2/button, v2/icon_button, v2/text_button) ----
    property color button: ron("#9E9E9E40")
    property color buttonHover: ron("#63636366")
    property color buttonPressed: ron("#2B2B2B9F")
    property color iconButtonOn: ron("#BEBEBEFF")
    property color iconButtonHover: ron("#63636333")
    property color iconButtonPressed: ron("#16161680")

    // ---- semantic (v2/destructive, v2/success, v2/warning) ----
    property color destructive: ron("#FFA09AFF")
    readonly property color danger: destructive
    property color success: ron("#5EDB8CFF")
    property color warning: ron("#FFA37DFF")
    readonly property color surface0: Qt.rgba(surfaceTint.r, surfaceTint.g, surfaceTint.b, Math.min(1, 0.04 * surfaceStrength))
    readonly property color surface1: primaryComponent
    readonly property color surface2: secondaryComponent

    // ---- text ----
    readonly property color text: fgOnBg
    readonly property color textStrong: fgOnPrimary
    property color textDim: ron("#FFFFFFA6") // component.on_disabled

    // v2/shade: rgba(0,0,0,0.32), used to dim the screen behind modal surfaces
    property color shade: Qt.rgba(0, 0, 0, 0.32)

    // ---- configurable surface opacities (managed by services/OpacityConfig.qml & ThemeConfig.qml) ----
    property real widgetsOpacity: 0.96
    property real barOpacity: 0.66
    property real notificationsOpacity: 0.96
    property real osdOpacity: 0.96

    // ---- panel (com.system76.CosmicPanel.Panel/v1) ----
    // opacity 0.66 applied to background.base, anchor_gap -> margin 4, border_radius 160 (pill)
    readonly property real panelOpacity: barOpacity
    readonly property color barBg: alpha(bg, barOpacity)
    readonly property color panelBg: barBg
    readonly property color panelBorder: componentDivider
    property int panelMargin: 4
    property int barHeight: 35
    readonly property int barPadding: spaceXxs
    property int barRadius: 160
    property int barBorderWidth: 0
    property int popupBorderWidth: 1

    // Popups / launcher / notifications / OSD use configurable frosted backgrounds.
    readonly property color widgetsBg: alpha(bg, widgetsOpacity)
    readonly property color popupBg: widgetsBg
    readonly property color notificationsBg: alpha(bg, notificationsOpacity)
    readonly property color osdBg: alpha(bg, osdOpacity)
    readonly property color overviewBg: alpha(bg, widgetsOpacity * 0.69)
    readonly property color popupBorder: componentDivider
    property int popupGap: 6        // space between bar and popup
    property int popupWidth: 320    // default popup width

    // ---- spacing (v2/spacing) ----
    property real spacingScale: 1.0
    readonly property int spaceNone: 0
    readonly property int spaceXxxs: Math.max(1, Math.round(4 * spacingScale))
    readonly property int spaceXxs: Math.max(2, Math.round(8 * spacingScale))
    readonly property int spaceXs: Math.max(3, Math.round(12 * spacingScale))
    readonly property int spaceS: Math.max(4, Math.round(16 * spacingScale))
    readonly property int spaceM: Math.max(6, Math.round(24 * spacingScale))
    readonly property int spaceL: Math.max(8, Math.round(32 * spacingScale))
    readonly property int spaceXl: Math.max(12, Math.round(48 * spacingScale))
    readonly property int spaceXxl: Math.max(16, Math.round(64 * spacingScale))
    readonly property int spaceXxxl: Math.max(24, Math.round(128 * spacingScale))

    // ---- corner radii ----
    // No corner_radii file in the v2 theme dir, so these are COSMIC's defaults.
    readonly property int radius0: 0
    property int radiusXs: 4
    property int radiusS: 8
    property int radiusM: 16
    property int radiusL: 32
    property int radiusXl: 160

    // ---- window gaps (v2/gaps = (0, 3)) ----
    property int gapInner: 3

    // ---- fonts ----
    // COSMIC interface_font is "Noto Sans Adlam" (likely accidental); Fira Sans is used instead.
    property string fontFamily: "Fira Sans"
    property string monoFamily: "JetBrainsMono Nerd Font"
    property string iconFamily: "Material Symbols Rounded"
    property int fontSize: 14
    readonly property int fontSizeSmall: Math.max(9, fontSize - 2)
    readonly property int fontSizeLarge: fontSize + 2
    property int barFontSize: 16
    readonly property int fontSizeTitle: fontSize + 6
    property int iconSize: 18
    property int barIconSize: 19
    property int workspaceCircle: 26   // active workspace circle diameter   // icons in the bar itself (popups keep iconSize)

    // ---- motion ----
    property real animScale: 1.0
    readonly property int animFast: Math.round(120 * animScale)
    readonly property int animNormal: Math.round(200 * animScale)
    readonly property int animSlow: Math.round(320 * animScale)
}
