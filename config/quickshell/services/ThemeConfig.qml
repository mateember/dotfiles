pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Persistent theme configuration and profile manager.
// Manages live theme tokens in Theme.qml, built-in presets (including "Default",
// the original COSMIC Dark look), and user-created profiles stored in a shared
// XDG state file (~/.local/state/quickshell/hcs-theme.json) so both shell.qml
// and lock.qml stay synchronized.
Singleton {
    id: root

    property bool settingsOpen: false
    property bool pickingColor: false
    property bool passiveMode: false
    property bool ready: false
    property bool loadedFromFile: false

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell"
    readonly property string stateFile: stateDir + "/hcs-theme.json"

    property string activeProfileId: "default"
    property var current: defaultSettings()
    property var userProfiles: []

    property bool _ignoreNextFileChange: false
    property int _revision: 0

    function defaultSettings(): var {
        return {
            accent: "#FFAD00",
            accentHover: "#E09E14",
            accentPressed: "#8A610B",
            fgOnAccent: "#000000",
            autoAccentDerived: true,

            bg: "#1B1B1B",
            primary: "#272727",
            secondary: "#343434",
            text: "#EEEEEE",
            textStrong: "#FFFFFF",
            textDim: "#A6FFFFFF",
            surfaceTint: "#FFFFFF",
            surfaceStrength: 1.0,
            borderColor: "#FFFFFF",
            borderAlpha: 0.20,
            componentBorder: "#BEBEBE",
            bgDivider: "#454545",
            primaryDivider: "#525252",

            button: "#409E9E9E",
            buttonHover: "#66636363",
            buttonPressed: "#9F2B2B2B",
            iconButtonOn: "#BEBEBE",
            iconButtonHover: "#33636363",
            iconButtonPressed: "#80161616",

            destructive: "#FFA09A",
            success: "#5EDB8C",
            warning: "#FFA37D",

            widgetsOpacity: 0.96,
            barOpacity: 0.66,
            notificationsOpacity: 0.96,
            osdOpacity: 0.96,
            barBorderWidth: 0,
            popupBorderWidth: 1,

            radiusXs: 4,
            radiusS: 8,
            radiusM: 16,
            radiusL: 32,
            barRadius: 160,
            barHeight: 35,
            panelMargin: 4,
            popupGap: 6,
            popupWidth: 320,
            workspaceCircle: 26,
            spacingScale: 1.0,

            fontFamily: "Fira Sans",
            monoFamily: "JetBrainsMono Nerd Font",
            fontSize: 14,
            barFontSize: 16,
            iconSize: 18,
            barIconSize: 19,
            animScale: 1.0
        };
    }

    function makePreset(patch): var {
        return Object.assign(defaultSettings(), patch);
    }

    readonly property var builtinProfiles: [
        {
            id: "default",
            name: "Default",
            description: "Original COSMIC Dark look",
            builtin: true,
            settings: defaultSettings()
        },
        {
            id: "cosmic-light",
            name: "COSMIC Light",
            description: "Bright daylight surfaces with dark overlays",
            builtin: true,
            settings: makePreset({
                accent: "#D97706",
                accentHover: "#B45309",
                accentPressed: "#78350F",
                fgOnAccent: "#FFFFFF",
                bg: "#F3F4F6",
                primary: "#FFFFFF",
                secondary: "#E5E7EB",
                text: "#18181B",
                textStrong: "#09090B",
                textDim: "#9918181B",
                surfaceTint: "#000000",
                surfaceStrength: 0.90,
                borderColor: "#000000",
                borderAlpha: 0.14,
                componentBorder: "#71717A",
                bgDivider: "#D4D4D8",
                primaryDivider: "#E4E4E7",
                button: "#2B000000",
                buttonHover: "#40000000",
                buttonPressed: "#55000000",
                iconButtonOn: "#52525B",
                iconButtonHover: "#18000000",
                iconButtonPressed: "#2E000000",
                destructive: "#DC2626",
                success: "#16A34A",
                warning: "#EA580C",
                widgetsOpacity: 0.95,
                barOpacity: 0.80,
                notificationsOpacity: 0.96,
                osdOpacity: 0.95
            })
        },
        {
            id: "nordic-frost",
            name: "Nordic Frost",
            description: "Arctic slate palette with cyan highlights",
            builtin: true,
            settings: makePreset({
                accent: "#88C0D0",
                accentHover: "#76ACC0",
                accentPressed: "#4E7B8C",
                fgOnAccent: "#191E28",
                bg: "#2E3440",
                primary: "#3B4252",
                secondary: "#434C5E",
                text: "#ECEFF4",
                textStrong: "#FFFFFF",
                textDim: "#A6ECEFF4",
                surfaceTint: "#ECEFF4",
                surfaceStrength: 1.0,
                borderColor: "#D8DEE9",
                borderAlpha: 0.18,
                componentBorder: "#81A1C1",
                bgDivider: "#4C566A",
                primaryDivider: "#4C566A",
                destructive: "#BF616A",
                success: "#A3BE8C",
                warning: "#EBCB8B",
                widgetsOpacity: 0.94,
                barOpacity: 0.78,
                notificationsOpacity: 0.95,
                osdOpacity: 0.94,
                radiusXs: 4,
                radiusS: 6,
                radiusM: 12,
                radiusL: 22,
                barRadius: 12
            })
        },
        {
            id: "catppuccin-mocha",
            name: "Catppuccin Mocha",
            description: "Warm deep espresso with pastel mauve",
            builtin: true,
            settings: makePreset({
                accent: "#CBA6F7",
                accentHover: "#B58CEB",
                accentPressed: "#7D56B2",
                fgOnAccent: "#11111B",
                bg: "#1E1E2E",
                primary: "#313244",
                secondary: "#45475A",
                text: "#CDD6F4",
                textStrong: "#FFFFFF",
                textDim: "#A6BAC2DE",
                surfaceTint: "#CDD6F4",
                surfaceStrength: 0.95,
                borderColor: "#BAC2DE",
                borderAlpha: 0.18,
                componentBorder: "#9399B2",
                bgDivider: "#45475A",
                primaryDivider: "#585B70",
                destructive: "#F38BA8",
                success: "#A6E3A1",
                warning: "#FAB387",
                widgetsOpacity: 0.95,
                barOpacity: 0.74,
                notificationsOpacity: 0.95,
                osdOpacity: 0.95,
                radiusS: 10,
                radiusM: 18,
                radiusL: 30
            })
        },
        {
            id: "minimal-sharp",
            name: "Minimal Sharp",
            description: "Flush panel with crisp architectural corners",
            builtin: true,
            settings: makePreset({
                accent: "#FFAD00",
                accentHover: "#E09E14",
                accentPressed: "#8A610B",
                fgOnAccent: "#000000",
                bg: "#121214",
                primary: "#1C1C20",
                secondary: "#26262B",
                barOpacity: 0.88,
                widgetsOpacity: 0.97,
                notificationsOpacity: 0.97,
                osdOpacity: 0.97,
                barBorderWidth: 1,
                radiusXs: 0,
                radiusS: 2,
                radiusM: 4,
                radiusL: 6,
                barRadius: 0,
                barHeight: 32,
                panelMargin: 0,
                popupGap: 4,
                workspaceCircle: 24
            })
        }
    ]

    readonly property var allProfiles: {
        const _ = root._revision;
        return root.builtinProfiles.concat(root.userProfiles);
    }

    readonly property var activeProfile: {
        const list = root.allProfiles;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === root.activeProfileId) return list[i];
        }
        return root.builtinProfiles[0];
    }

    readonly property bool activeIsBuiltin: Boolean(root.activeProfile?.builtin)

    readonly property bool isDirty: {
        const _ = root._revision;
        const base = root.activeProfile?.settings;
        const cur = root.current;
        if (!base || !cur) return false;
        const keys = Object.keys(defaultSettings());
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i];
            const a = cur[k];
            const b = base[k];
            if (typeof a === "number" && typeof b === "number") {
                if (Math.abs(a - b) > 0.001) return true;
            } else if (String(a) !== String(b)) {
                return true;
            }
        }
        return false;
    }

    readonly property var curatedAccents: [
        { hex: "#FFAD00", name: "COSMIC Amber" },
        { hex: "#38BDF8", name: "Sky" },
        { hex: "#34D399", name: "Mint" },
        { hex: "#CBA6F7", name: "Mauve" },
        { hex: "#FB7185", name: "Rose" },
        { hex: "#F97316", name: "Tangerine" },
        { hex: "#60A5FA", name: "Cobalt" },
        { hex: "#E4E4E7", name: "Silver" }
    ]

    // ---- Color & Sanitization Helpers ----

    function normalizeHex(raw: string, fallback: string, allowAlpha: bool): string {
        if (typeof raw !== "string") return fallback;
        let s = raw.trim().toUpperCase();
        if (!s.startsWith("#")) s = "#" + s;
        if (/^#[0-9A-F]{3}$/.test(s)) {
            s = "#" + s[1] + s[1] + s[2] + s[2] + s[3] + s[3];
        }
        if (/^#[0-9A-F]{6}$/.test(s)) return s;
        if (allowAlpha && /^#[0-9A-F]{8}$/.test(s)) return s;
        if (!allowAlpha && /^#[0-9A-F]{8}$/.test(s)) return "#" + s.slice(3);
        return fallback;
    }

    function hexRgbComponents(hex: string): var {
        const clean = normalizeHex(hex, "#000000", true);
        const off = clean.length === 9 ? 3 : 1;
        return {
            a: clean.length === 9 ? parseInt(clean.slice(1, 3), 16) / 255 : 1.0,
            r: parseInt(clean.slice(off, off + 2), 16) / 255,
            g: parseInt(clean.slice(off + 2, off + 4), 16) / 255,
            b: parseInt(clean.slice(off + 4, off + 6), 16) / 255
        };
    }

    function componentsToHex(r: real, g: real, b: real, a: real, includeAlpha: bool): string {
        const byte = v => Math.max(0, Math.min(255, Math.round(v * 255))).toString(16).padStart(2, "0").toUpperCase();
        if (includeAlpha)
            return "#" + byte(a) + byte(r) + byte(g) + byte(b);
        return "#" + byte(r) + byte(g) + byte(b);
    }

    function rgbToHsl(r: real, g: real, b: real): var {
        const max = Math.max(r, g, b);
        const min = Math.min(r, g, b);
        let h = 0;
        let s = 0;
        const l = (max + min) / 2;
        if (max !== min) {
            const d = max - min;
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            if (max === r) h = (g - b) / d + (g < b ? 6 : 0);
            else if (max === g) h = (b - r) / d + 2;
            else h = (r - g) / d + 4;
            h /= 6;
        }
        return { h: h * 360, s: s, l: l };
    }

    function hslToRgb(h: real, s: real, l: real): var {
        const hh = ((h % 360) + 360) % 360 / 360;
        if (s <= 0.0001) return { r: l, g: l, b: l };
        const hue2rgb = (p, q, t) => {
            if (t < 0) t += 1;
            if (t > 1) t -= 1;
            if (t < 1 / 6) return p + (q - p) * 6 * t;
            if (t < 1 / 2) return q;
            if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
            return p;
        };
        const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
        const p = 2 * l - q;
        return {
            r: hue2rgb(p, q, hh + 1 / 3),
            g: hue2rgb(p, q, hh),
            b: hue2rgb(p, q, hh - 1 / 3)
        };
    }

    function hslToHex(h: real, s: real, l: real, a: real, includeAlpha: bool): string {
        const rgb = hslToRgb(h, Math.max(0, Math.min(1, s)), Math.max(0, Math.min(1, l)));
        return componentsToHex(rgb.r, rgb.g, rgb.b, a === undefined ? 1.0 : a, Boolean(includeAlpha));
    }

    function relativeLuminance(hex: string): real {
        const c = hexRgbComponents(hex);
        const lin = ch => ch <= 0.03928 ? ch / 12.92 : Math.pow((ch + 0.055) / 1.055, 2.4);
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }

    function isLightHex(hex: string): bool {
        return relativeLuminance(hex) > 0.36;
    }

    function deriveAccentColors(hex: string): var {
        const clean = normalizeHex(hex, "#FFAD00", false);
        if (clean === "#FFAD00") {
            return { accentHover: "#E09E14", accentPressed: "#8A610B", fgOnAccent: "#000000" };
        }
        const c = hexRgbComponents(clean);
        const hsl = rgbToHsl(c.r, c.g, c.b);
        const hoverL = hsl.l > 0.28 ? Math.max(0.08, hsl.l - 0.07) : Math.min(0.85, hsl.l + 0.09);
        const pressL = hsl.l > 0.28 ? Math.max(0.04, hsl.l * 0.52) : Math.min(0.92, hsl.l + 0.18);
        return {
            accentHover: hslToHex(hsl.h, Math.max(0, hsl.s * 0.92), hoverL, 1.0, false),
            accentPressed: hslToHex(hsl.h, Math.min(1, hsl.s * 0.96), pressL, 1.0, false),
            fgOnAccent: isLightHex(clean) ? "#000000" : "#FFFFFF"
        };
    }

    function clampNum(v, lo: real, hi: real, decimals: int, fallback: real): real {
        const n = Number(v);
        if (isNaN(n)) return fallback;
        const p = Math.pow(10, decimals);
        return Math.round(Math.max(lo, Math.min(hi, n)) * p) / p;
    }

    function clampInt(v, lo: int, hi: int, fallback: int): int {
        const n = Math.round(Number(v));
        if (isNaN(n)) return fallback;
        return Math.max(lo, Math.min(hi, n));
    }

    function sanitizeSettings(raw): var {
        const d = defaultSettings();
        const s = (raw && typeof raw === "object") ? raw : {};
        return {
            accent: normalizeHex(s.accent, d.accent, false),
            accentHover: normalizeHex(s.accentHover, d.accentHover, false),
            accentPressed: normalizeHex(s.accentPressed, d.accentPressed, false),
            fgOnAccent: normalizeHex(s.fgOnAccent, d.fgOnAccent, false),
            autoAccentDerived: s.autoAccentDerived !== undefined ? Boolean(s.autoAccentDerived) : d.autoAccentDerived,

            bg: normalizeHex(s.bg, d.bg, false),
            primary: normalizeHex(s.primary, d.primary, false),
            secondary: normalizeHex(s.secondary, d.secondary, false),
            text: normalizeHex(s.text, d.text, false),
            textStrong: normalizeHex(s.textStrong, d.textStrong, false),
            textDim: normalizeHex(s.textDim, d.textDim, true),
            surfaceTint: normalizeHex(s.surfaceTint, d.surfaceTint, false),
            surfaceStrength: clampNum(s.surfaceStrength, 0.3, 2.5, 2, d.surfaceStrength),
            borderColor: normalizeHex(s.borderColor, d.borderColor, false),
            borderAlpha: clampNum(s.borderAlpha, 0.0, 1.0, 2, d.borderAlpha),
            componentBorder: normalizeHex(s.componentBorder, d.componentBorder, false),
            bgDivider: normalizeHex(s.bgDivider, d.bgDivider, false),
            primaryDivider: normalizeHex(s.primaryDivider, d.primaryDivider, false),

            button: normalizeHex(s.button, d.button, true),
            buttonHover: normalizeHex(s.buttonHover, d.buttonHover, true),
            buttonPressed: normalizeHex(s.buttonPressed, d.buttonPressed, true),
            iconButtonOn: normalizeHex(s.iconButtonOn, d.iconButtonOn, false),
            iconButtonHover: normalizeHex(s.iconButtonHover, d.iconButtonHover, true),
            iconButtonPressed: normalizeHex(s.iconButtonPressed, d.iconButtonPressed, true),

            destructive: normalizeHex(s.destructive, d.destructive, false),
            success: normalizeHex(s.success, d.success, false),
            warning: normalizeHex(s.warning, d.warning, false),

            widgetsOpacity: clampNum(s.widgetsOpacity, 0.0, 1.0, 2, d.widgetsOpacity),
            barOpacity: clampNum(s.barOpacity, 0.0, 1.0, 2, d.barOpacity),
            notificationsOpacity: clampNum(s.notificationsOpacity, 0.0, 1.0, 2, d.notificationsOpacity),
            osdOpacity: clampNum(s.osdOpacity, 0.0, 1.0, 2, d.osdOpacity),
            barBorderWidth: clampInt(s.barBorderWidth, 0, 3, d.barBorderWidth),
            popupBorderWidth: clampInt(s.popupBorderWidth, 0, 3, d.popupBorderWidth),

            radiusXs: clampInt(s.radiusXs, 0, 14, d.radiusXs),
            radiusS: clampInt(s.radiusS, 0, 24, d.radiusS),
            radiusM: clampInt(s.radiusM, 0, 36, d.radiusM),
            radiusL: clampInt(s.radiusL, 0, 48, d.radiusL),
            barRadius: clampInt(s.barRadius, 0, 160, d.barRadius),
            barHeight: clampInt(s.barHeight, 24, 54, d.barHeight),
            panelMargin: clampInt(s.panelMargin, 0, 24, d.panelMargin),
            popupGap: clampInt(s.popupGap, 0, 24, d.popupGap),
            popupWidth: clampInt(s.popupWidth, 260, 460, d.popupWidth),
            workspaceCircle: clampInt(s.workspaceCircle, 18, 40, d.workspaceCircle),
            spacingScale: clampNum(s.spacingScale, 0.65, 1.50, 2, d.spacingScale),

            fontFamily: (typeof s.fontFamily === "string" && s.fontFamily.trim() !== "") ? s.fontFamily.trim() : d.fontFamily,
            monoFamily: (typeof s.monoFamily === "string" && s.monoFamily.trim() !== "") ? s.monoFamily.trim() : d.monoFamily,
            fontSize: clampInt(s.fontSize, 10, 22, d.fontSize),
            barFontSize: clampInt(s.barFontSize, 10, 24, d.barFontSize),
            iconSize: clampInt(s.iconSize, 12, 28, d.iconSize),
            barIconSize: clampInt(s.barIconSize, 12, 28, d.barIconSize),
            animScale: clampNum(s.animScale, 0.0, 2.0, 2, d.animScale)
        };
    }

    // ---- Applying to Theme ----

    function applyToTheme() {
        const s = root.current;
        Theme.accent = s.accent;
        Theme.accentHover = s.accentHover;
        Theme.accentPressed = s.accentPressed;
        Theme.fgOnAccent = s.fgOnAccent;

        Theme.bg = s.bg;
        Theme.primary = s.primary;
        Theme.secondary = s.secondary;
        Theme.fgOnBg = s.text;
        Theme.fgOnPrimary = s.textStrong;
        Theme.textDim = s.textDim;
        Theme.surfaceTint = s.surfaceTint;
        Theme.surfaceStrength = s.surfaceStrength;
        Theme.borderColor = s.borderColor;
        Theme.borderAlpha = s.borderAlpha;
        Theme.componentBorder = s.componentBorder;
        Theme.bgDivider = s.bgDivider;
        Theme.primaryDivider = s.primaryDivider;

        Theme.button = s.button;
        Theme.buttonHover = s.buttonHover;
        Theme.buttonPressed = s.buttonPressed;
        Theme.iconButtonOn = s.iconButtonOn;
        Theme.iconButtonHover = s.iconButtonHover;
        Theme.iconButtonPressed = s.iconButtonPressed;

        Theme.destructive = s.destructive;
        Theme.success = s.success;
        Theme.warning = s.warning;

        Theme.widgetsOpacity = s.widgetsOpacity;
        Theme.barOpacity = s.barOpacity;
        Theme.notificationsOpacity = s.notificationsOpacity;
        Theme.osdOpacity = s.osdOpacity;
        Theme.barBorderWidth = s.barBorderWidth;
        Theme.popupBorderWidth = s.popupBorderWidth;

        Theme.radiusXs = s.radiusXs;
        Theme.radiusS = s.radiusS;
        Theme.radiusM = s.radiusM;
        Theme.radiusL = s.radiusL;
        Theme.barRadius = s.barRadius;
        Theme.barHeight = s.barHeight;
        Theme.panelMargin = s.panelMargin;
        Theme.popupGap = s.popupGap;
        Theme.popupWidth = s.popupWidth;
        Theme.workspaceCircle = s.workspaceCircle;
        Theme.spacingScale = s.spacingScale;

        Theme.fontFamily = s.fontFamily;
        Theme.monoFamily = s.monoFamily;
        Theme.fontSize = s.fontSize;
        Theme.barFontSize = s.barFontSize;
        Theme.iconSize = s.iconSize;
        Theme.barIconSize = s.barIconSize;
        Theme.animScale = s.animScale;
    }

    function syncOpacitiesOut() {
        if (root.passiveMode) return;
        const s = root.current;
        OpacityConfig.syncFromTheme(s.widgetsOpacity, s.barOpacity, s.notificationsOpacity, s.osdOpacity);
    }

    // Called by OpacityConfig when OpacitySettingsWindow or `qs ipc call opacity` changes opacity.
    function syncOpacityFromExternal(w: real, b: real, n: real, o: real) {
        const next = Object.assign({}, root.current, {
            widgetsOpacity: clampNum(w, 0, 1, 2, root.current.widgetsOpacity),
            barOpacity: clampNum(b, 0, 1, 2, root.current.barOpacity),
            notificationsOpacity: clampNum(n, 0, 1, 2, root.current.notificationsOpacity),
            osdOpacity: clampNum(o, 0, 1, 2, root.current.osdOpacity)
        });
        root.current = next;
        root._revision++;
        root.applyToTheme();
        if (root.loadedFromFile) root.scheduleSave();
    }

    // ---- Mutating Live Settings ----

    function setSettings(patch: var, syncOpacity: bool) {
        const next = sanitizeSettings(Object.assign({}, root.current, patch));
        root.current = next;
        root._revision++;
        root.applyToTheme();
        if (syncOpacity) root.syncOpacitiesOut();
        root.scheduleSave();
    }

    function setSetting(key: string, val) {
        const patch = {};
        patch[key] = val;
        if (key === "accent" && root.current.autoAccentDerived) {
            const derived = deriveAccentColors(String(val));
            patch.accentHover = derived.accentHover;
            patch.accentPressed = derived.accentPressed;
            patch.fgOnAccent = derived.fgOnAccent;
        }
        const opacityKeys = ["widgetsOpacity", "barOpacity", "notificationsOpacity", "osdOpacity"];
        setSettings(patch, opacityKeys.indexOf(key) >= 0);
    }

    function setAutoAccentDerived(on: bool) {
        const patch = { autoAccentDerived: Boolean(on) };
        if (on) {
            const derived = deriveAccentColors(root.current.accent);
            patch.accentHover = derived.accentHover;
            patch.accentPressed = derived.accentPressed;
            patch.fgOnAccent = derived.fgOnAccent;
        }
        setSettings(patch, false);
    }

    function adaptToneForBackground(bgHex: string, adaptSurfaces: bool) {
        const cleanBg = normalizeHex(bgHex, root.current.bg, false);
        const light = isLightHex(cleanBg);
        const c = hexRgbComponents(cleanBg);
        const hsl = rgbToHsl(c.r, c.g, c.b);
        const patch = { bg: cleanBg };

        if (adaptSurfaces) {
            if (light) {
                patch.primary = hsl.l > 0.94 ? "#FFFFFF" : hslToHex(hsl.h, hsl.s * 0.6, Math.min(0.99, hsl.l + 0.04), 1.0, false);
                patch.secondary = hslToHex(hsl.h, hsl.s * 0.7, Math.max(0.78, hsl.l - 0.06), 1.0, false);
                patch.text = "#18181B";
                patch.textStrong = "#09090B";
                patch.textDim = "#9918181B";
                patch.surfaceTint = "#000000";
                patch.surfaceStrength = 0.90;
                patch.borderColor = "#000000";
                patch.borderAlpha = 0.14;
                patch.componentBorder = "#71717A";
                patch.bgDivider = "#D4D4D8";
                patch.primaryDivider = "#E4E4E7";
                patch.button = "#2B000000";
                patch.buttonHover = "#40000000";
                patch.buttonPressed = "#55000000";
                patch.iconButtonOn = "#52525B";
                patch.iconButtonHover = "#18000000";
                patch.iconButtonPressed = "#2E000000";
            } else {
                patch.primary = hslToHex(hsl.h, hsl.s, Math.min(0.32, hsl.l + 0.05), 1.0, false);
                patch.secondary = hslToHex(hsl.h, hsl.s, Math.min(0.40, hsl.l + 0.10), 1.0, false);
                patch.text = "#EEEEEE";
                patch.textStrong = "#FFFFFF";
                patch.textDim = "#A6FFFFFF";
                patch.surfaceTint = "#FFFFFF";
                patch.surfaceStrength = 1.0;
                patch.borderColor = "#FFFFFF";
                patch.borderAlpha = 0.20;
                patch.componentBorder = "#BEBEBE";
                patch.bgDivider = "#454545";
                patch.primaryDivider = "#525252";
                patch.button = "#409E9E9E";
                patch.buttonHover = "#66636363";
                patch.buttonPressed = "#9F2B2B2B";
                patch.iconButtonOn = "#BEBEBE";
                patch.iconButtonHover = "#33636363";
                patch.iconButtonPressed = "#80161616";
            }
        }
        setSettings(patch, false);
    }

    function applyBaseTone(light: bool) {
        const patch = light ? builtinProfiles[1].settings : defaultSettings();
        // Keep current accent, opacity, layout & typography when switching only Dark/Light surface tone.
        setSettings({
            bg: patch.bg,
            primary: patch.primary,
            secondary: patch.secondary,
            text: patch.text,
            textStrong: patch.textStrong,
            textDim: patch.textDim,
            surfaceTint: patch.surfaceTint,
            surfaceStrength: patch.surfaceStrength,
            borderColor: patch.borderColor,
            borderAlpha: patch.borderAlpha,
            componentBorder: patch.componentBorder,
            bgDivider: patch.bgDivider,
            primaryDivider: patch.primaryDivider,
            button: patch.button,
            buttonHover: patch.buttonHover,
            buttonPressed: patch.buttonPressed,
            iconButtonOn: patch.iconButtonOn,
            iconButtonHover: patch.iconButtonHover,
            iconButtonPressed: patch.iconButtonPressed,
            destructive: patch.destructive,
            success: patch.success,
            warning: patch.warning
        }, false);
    }

    function applyRadiusPreset(kind: string) {
        if (kind === "sharp") {
            setSettings({ radiusXs: 0, radiusS: 0, radiusM: 0, radiusL: 0, barRadius: 0 }, false);
        } else if (kind === "crisp") {
            setSettings({ radiusXs: 2, radiusS: 4, radiusM: 8, radiusL: 16, barRadius: 10 }, false);
        } else if (kind === "plush") {
            setSettings({ radiusXs: 6, radiusS: 12, radiusM: 22, radiusL: 36, barRadius: 160 }, false);
        } else {
            setSettings({ radiusXs: 4, radiusS: 8, radiusM: 16, radiusL: 32, barRadius: 160 }, false);
        }
    }

    // ---- Profile Operations ----

    function profileById(id: string): var {
        const list = root.allProfiles;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) return list[i];
        }
        return null;
    }

    function findProfileByIdOrName(query: string): var {
        const q = (query || "").trim().toLowerCase();
        if (!q) return null;
        const list = root.allProfiles;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id.toLowerCase() === q) return list[i];
        }
        for (let i = 0; i < list.length; i++) {
            if (list[i].name.toLowerCase() === q) return list[i];
        }
        return null;
    }

    function uniqueProfileId(name: string): string {
        let base = (name || "profile").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
        if (!base) base = "profile";
        let candidate = base;
        let n = 2;
        while (profileById(candidate) !== null) {
            candidate = base + "-" + n;
            n++;
        }
        return candidate;
    }

    function applyProfile(id: string): bool {
        const p = profileById(id);
        if (!p) return false;
        root.activeProfileId = p.id;
        root.current = sanitizeSettings(p.settings);
        root._revision++;
        root.applyToTheme();
        root.syncOpacitiesOut();
        root.saveNow();
        return true;
    }

    function createProfile(name: string, description: string): var {
        const cleanName = (name || "").trim() || ("Custom " + (root.userProfiles.length + 1));
        const cleanDesc = (description || "").trim();
        const now = new Date().toISOString();
        const entry = {
            id: uniqueProfileId(cleanName),
            name: cleanName,
            description: cleanDesc,
            builtin: false,
            createdAt: now,
            updatedAt: now,
            settings: sanitizeSettings(root.current)
        };
        root.userProfiles = root.userProfiles.concat([entry]);
        root.activeProfileId = entry.id;
        root._revision++;
        root.saveNow();
        return entry;
    }

    function saveToActiveProfile(): bool {
        const idx = root.userProfiles.findIndex(p => p.id === root.activeProfileId);
        if (idx < 0) return false;
        const next = root.userProfiles.slice();
        next[idx] = Object.assign({}, next[idx], {
            updatedAt: new Date().toISOString(),
            settings: sanitizeSettings(root.current)
        });
        root.userProfiles = next;
        root._revision++;
        root.saveNow();
        return true;
    }

    function revertToActiveProfile() {
        const p = root.activeProfile;
        if (!p) return;
        root.current = sanitizeSettings(p.settings);
        root._revision++;
        root.applyToTheme();
        root.syncOpacitiesOut();
        root.saveNow();
    }

    function renameProfile(id: string, newName: string): bool {
        const clean = (newName || "").trim();
        if (!clean) return false;
        const idx = root.userProfiles.findIndex(p => p.id === id);
        if (idx < 0) return false;
        const next = root.userProfiles.slice();
        next[idx] = Object.assign({}, next[idx], {
            name: clean,
            updatedAt: new Date().toISOString()
        });
        root.userProfiles = next;
        root._revision++;
        root.saveNow();
        return true;
    }

    function duplicateProfile(id: string, customName: string): var {
        const src = profileById(id);
        if (!src) return null;
        const baseName = (customName || "").trim() || (src.name + " Copy");
        const now = new Date().toISOString();
        const entry = {
            id: uniqueProfileId(baseName),
            name: baseName,
            description: src.description || "",
            builtin: false,
            createdAt: now,
            updatedAt: now,
            settings: sanitizeSettings(src.settings)
        };
        root.userProfiles = root.userProfiles.concat([entry]);
        root.activeProfileId = entry.id;
        root.current = sanitizeSettings(entry.settings);
        root._revision++;
        root.applyToTheme();
        root.syncOpacitiesOut();
        root.saveNow();
        return entry;
    }

    function deleteProfile(id: string): bool {
        const idx = root.userProfiles.findIndex(p => p.id === id);
        if (idx < 0) return false;
        const next = root.userProfiles.slice();
        next.splice(idx, 1);
        root.userProfiles = next;
        if (root.activeProfileId === id) {
            root.activeProfileId = "default";
            root.current = defaultSettings();
            root.applyToTheme();
            root.syncOpacitiesOut();
        }
        root._revision++;
        root.saveNow();
        return true;
    }

    function resetToDefault() {
        applyProfile("default");
    }

    // ---- Persistence ----

    function scheduleSave() {
        if (root.passiveMode) return;
        saveTimer.restart();
    }

    function saveNow() {
        if (root.passiveMode) return;
        saveTimer.stop();
        root.loadedFromFile = true;
        root._ignoreNextFileChange = true;
        ignoreChangeTimer.restart();
        const payload = {
            version: 1,
            activeProfileId: root.activeProfileId,
            current: sanitizeSettings(root.current),
            profiles: root.userProfiles.map(p => ({
                id: p.id,
                name: p.name,
                description: p.description || "",
                createdAt: p.createdAt || "",
                updatedAt: p.updatedAt || "",
                settings: sanitizeSettings(p.settings)
            }))
        };
        store.setText(JSON.stringify(payload, null, 2));
    }

    function loadJson(raw: string) {
        try {
            const d = JSON.parse(raw);
            if (!d || typeof d !== "object") return;

            const loadedProfiles = [];
            if (Array.isArray(d.profiles)) {
                const seenIds = { "default": true, "cosmic-light": true, "nordic-frost": true, "catppuccin-mocha": true, "minimal-sharp": true };
                for (let i = 0; i < d.profiles.length; i++) {
                    const p = d.profiles[i];
                    if (!p || typeof p !== "object") continue;
                    const pid = (typeof p.id === "string" && p.id.trim() !== "") ? p.id.trim() : "";
                    const pname = (typeof p.name === "string" && p.name.trim() !== "") ? p.name.trim() : "";
                    if (!pid || !pname || seenIds[pid]) continue;
                    seenIds[pid] = true;
                    loadedProfiles.push({
                        id: pid,
                        name: pname,
                        description: typeof p.description === "string" ? p.description : "",
                        builtin: false,
                        createdAt: typeof p.createdAt === "string" ? p.createdAt : "",
                        updatedAt: typeof p.updatedAt === "string" ? p.updatedAt : "",
                        settings: sanitizeSettings(p.settings)
                    });
                }
            }
            root.userProfiles = loadedProfiles;

            const wantedId = (typeof d.activeProfileId === "string" && d.activeProfileId.trim() !== "")
                ? d.activeProfileId.trim() : "default";
            root.activeProfileId = profileById(wantedId) ? wantedId : "default";

            if (d.current && typeof d.current === "object") {
                root.current = sanitizeSettings(d.current);
            } else {
                const active = profileById(root.activeProfileId);
                root.current = sanitizeSettings(active ? active.settings : defaultSettings());
            }

            root.loadedFromFile = true;
            root._revision++;
            root.applyToTheme();
            root.syncOpacitiesOut();
        } catch (e) {
            console.warn("ThemeConfig: could not parse config:", e);
        }
    }

    Timer {
        id: saveTimer
        interval: 150
        onTriggered: root.saveNow()
    }

    Timer {
        id: ignoreChangeTimer
        interval: 450
        onTriggered: root._ignoreNextFileChange = false
    }

    Process {
        running: !root.passiveMode
        command: ["mkdir", "-p", root.stateDir]
    }

    FileView {
        id: store
        path: root.stateFile
        atomicWrites: true
        printErrors: false
        watchChanges: true
        onFileChanged: {
            if (root._ignoreNextFileChange) return;
            reload();
        }
        onLoaded: {
            root.loadJson(text());
            root.ready = true;
        }
        onLoadFailed: {
            // First run: keep Default look, and preserve any existing opacity-config.json values.
            root.loadedFromFile = false;
            if (!root.passiveMode && OpacityConfig.ready && OpacityConfig.loadedFromFile) {
                root.current = Object.assign({}, defaultSettings(), {
                    widgetsOpacity: OpacityConfig.widgetsOpacity,
                    barOpacity: OpacityConfig.barOpacity,
                    notificationsOpacity: OpacityConfig.notificationsOpacity,
                    osdOpacity: OpacityConfig.osdOpacity
                });
                root._revision++;
            }
            root.applyToTheme();
            root.ready = true;
        }
    }

    Component.onCompleted: root.applyToTheme()

    IpcHandler {
        target: "theme"
        function toggle(): void {
            if (root.settingsOpen) WidgetHistory.closeThemeSettings();
            else WidgetHistory.openThemeStandalone();
        }
        function open(): void { WidgetHistory.openThemeStandalone(); }
        function close(): void { WidgetHistory.closeThemeSettings(); }
        function reset(): void { root.resetToDefault(); }
        function profile(idOrName: string): string {
            const p = root.findProfileByIdOrName(idOrName);
            if (!p) return "Profile not found: " + idOrName;
            root.applyProfile(p.id);
            return "Applied profile: " + p.name;
        }
        function saveProfile(name: string): string {
            const p = root.createProfile(name, "");
            return "Saved profile: " + p.name + " (" + p.id + ")";
        }
        function deleteProfile(idOrName: string): string {
            const p = root.findProfileByIdOrName(idOrName);
            if (!p) return "Profile not found: " + idOrName;
            if (p.builtin) return "Cannot delete built-in profile: " + p.name;
            root.deleteProfile(p.id);
            return "Deleted profile: " + p.name;
        }
        function listProfiles(): string {
            return JSON.stringify(root.allProfiles.map(p => ({
                id: p.id,
                name: p.name,
                builtin: Boolean(p.builtin),
                active: p.id === root.activeProfileId
            })));
        }
    }
}
