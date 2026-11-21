import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// App launcher (qs ipc call launcher toggle, SUPER Space).
// Typing searches apps (fuzzy, most-used first). Prefixes:
//   =expr    calculator (qalc); plain math like "2*21" works too. Enter copies.
//   >cmd     shell command. Shift+Enter runs in kitty.
//   :name    emoji picker (Enter types + copies; Shift+Enter copies). Also: ipc call launcher emoji.
//   !name    built-in panels (also /name or @name). Also: ipc call launcher shell.
Scope {
    id: root

    property bool open: false
    property string initialQuery: ""
    property var usage: ({})     // desktop entry id → launch count
    property string pendingShellId: ""
    property string pendingScreen: ""

    readonly property string usageFile: Quickshell.statePath("launcher-usage.json")

    function toggle() { root.open = !root.open; }

    function bump(id: string) {
        const u = Object.assign({}, root.usage);
        u[id] = (u[id] || 0) + 1;
        root.usage = u;
        usageStore.setText(JSON.stringify(u));
    }

    // Run a Quickshell app after the launcher window has closed and released keyboard focus.
    function triggerShellApp(id: string, screenName: string) {
        root.pendingShellId = id;
        root.pendingScreen = screenName || (Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "");
        root.open = false;
        shellLaunchTimer.restart();
    }

    Timer {
        id: shellLaunchTimer
        interval: 120
        onTriggered: {
            const id = root.pendingShellId;
            const scr = root.pendingScreen;
            root.pendingShellId = "";
            if (id === "qs:settings") SettingsState.open = true;
            else if (id.startsWith("qs:settings:")) {
                const rest = id.slice(12);
                const colon = rest.indexOf(":");
                if (colon >= 0) SettingsState.openPage(rest.slice(0, colon), rest.slice(colon + 1));
                else SettingsState.openPage(rest, "");
            }
            else if (id === "qs:bar-settings") SettingsState.openPage("panel", "");
            else if (id === "qs:opacity-settings") SettingsState.openPage("appearance", "surfaces");
            else if (id === "qs:theme-settings") SettingsState.openPage("appearance", "profiles");
            else if (id === "qs:overview") Hypr.openOverview();
            else if (id === "qs:capture") Recorder.openOverlay("shot");
            else if (id === "qs:record") Recorder.openOverlay("record");
            else if (id === "qs:quicksettings") QuickSettingsState.openWindow();
            else if (id === "qs:colorpicker") ColorPicker.pick();
            else if (id === "qs:wallpaper") Wallpapers.next();
            else if (id === "qs:lock") Quickshell.execDetached(["loginctl", "lock-session"]);
            else if (id.startsWith("qs:popup:")) Popups.openWindow(id.slice(9) + "@" + scr);
        }
    }

    onOpenChanged: if (!open) root.initialQuery = ""

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.initialQuery = ""; root.toggle(); }
        function emoji(): void { root.initialQuery = root.open ? "" : ":"; root.toggle(); }
        function shell(): void { root.initialQuery = root.open ? "" : "!"; root.toggle(); }
        function open(): void { root.initialQuery = ""; root.open = true; }
        function close(): void { root.initialQuery = ""; root.open = false; }
    }

    FileView {
        id: usageStore
        path: root.usageFile
        printErrors: false
        onLoaded: {
            try { root.usage = JSON.parse(text()); } catch (e) { root.usage = {}; }
        }
    }
    Process {
        running: true
        command: ["mkdir", "-p", Quickshell.stateDir]
    }

    // Fresh window (and empty search) every time it opens, on the focused monitor.
    LazyLoader {
        active: root.open

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            WlrLayershell.namespace: "hcs-launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            property string query: search.text

            function looksLikeCalc(q: string): bool {
                const s = (q || "").trim();
                if (s === "") return false;
                if (s.startsWith("=")) return true;
                // Pure arithmetic: "2*21", "(10 + 5) / 3", "2^10"
                if (/^[\d\s.,()+\-*/^%]+$/.test(s) && /\d\s*[+\-*/^%]\s*[\d(]/.test(s)) return true;
                // Math functions: "sqrt(2)", "sin(45 deg)", "log(100)"
                if (/^(?:sqrt|cbrt|sin|cos|tan|asin|acos|atan|log|log10|ln|abs|ceil|floor|round|exp)\s*\(.+\)$/i.test(s)) return true;
                // Percentage of number: "15% of 240"
                if (/^[\d.,]+\s*%\s+of\s+[\d.,]+$/i.test(s)) return true;
                // Unit & currency conversions: "100 eur to huf", "50 km to mi", "32 f in c", "6 ft to cm", "2 gb in mb"
                if (/^[\d.,+\-*/()^\s]+\s*[a-zA-Z°%$€£¥/²³]+\s+(?:to|in|as)\s+[a-zA-Z°%$€£¥/²³]+$/i.test(s) && /\d/.test(s)) return true;
                return false;
            }

            function normalizeCalcExpr(q: string): string {
                let s = (q || "").replace(/^=/, "").trim();
                // "15% of 240" -> "15% * 240"
                s = s.replace(/^([\d.,]+\s*%)\s+of\s+([\d.,]+)$/i, "$1 * $2");
                // Temperature shorthand ("32 f to c" -> "32 °F to °C") so F isn't parsed as Farad
                s = s.replace(/^([\d.,+\-*/()\s]+?)\s*°?\s*([cfCF])\s+(to|in|as)\s+°?\s*([cfCF])$/i,
                    (_, num, u1, prep, u2) => `${num.trim()} °${u1.toUpperCase()} ${prep} °${u2.toUpperCase()}`);
                return s;
            }

            readonly property string mode: query.startsWith(":") ? "emoji"
                                         : (query.startsWith("!") || query.startsWith("/") || query.startsWith("@")) ? "shell"
                                         : query.startsWith("?") ? "web"
                                         : query.startsWith(">") ? "run"
                                         : looksLikeCalc(query) ? "calc"
                                         : "apps"
            property string calcResult: ""
            property string previousQuery: ""

            readonly property var shellApps: [
                { id: "qs:settings",            name: "Settings",              comment: "Unified HCS Settings (Wi-Fi, Bluetooth, Displays, Sound, Theme, Power, Input & About)", icon: "settings", keywords: ["settings", "control center", "preferences", "system", "config", "wifi", "bluetooth", "displays", "sound", "theme", "power", "keybinds"] },
                { id: "qs:settings:input",      name: "Keybindings & Input",   comment: "Searchable shortcut cheat sheet, touchpad, mouse & keyboard layouts", icon: "keyboard", keywords: ["keybinds", "shortcuts", "cheatsheet", "keyboard", "touchpad", "mouse"] },
                { id: "qs:settings:phone",      name: "Phone & Continuity",    comment: "KDE Connect phone battery, ring, clipboard & file sharing", icon: "smartphone", keywords: ["phone", "kdeconnect", "android", "ring", "continuity"] },
                { id: "qs:settings:apps",       name: "Apps & Services",       comment: "Default apps (xdg-mime), autostart entries & systemd user services", icon: "apps", keywords: ["default apps", "autostart", "systemd", "services"] },
                { id: "qs:settings:lock",       name: "Lock Screen & Security", comment: "Howdy IR face unlock, lock widgets, avatar & idle timers", icon: "lock", keywords: ["howdy", "lock", "security", "idle", "hypridle"] },
                { id: "qs:settings:about",      name: "About This Computer",   comment: "NixOS, hardware specs, removable drives & shell maintenance", icon: "info", keywords: ["about", "specs", "hardware", "nixos", "version"] },
                { id: "qs:overview",            name: "Overview",              comment: "KDE Plasma-style workspaces & live window previews (SUPER+Tab)", icon: "grid_view",        keywords: ["workspaces", "desktops", "expose", "windows", "plasma"] },
                { id: "qs:capture",             name: "Screenshot & Capture",  comment: "Interactive region/window/screen capture, timer & annotation (SUPER+Print)", icon: "photo_camera", keywords: ["screenshot", "snip", "satty", "swappy", "annotate", "capture"] },
                { id: "qs:record",              name: "Screen Recorder",       comment: "Record screen, region or window with system/mic audio",       icon: "videocam",            keywords: ["record", "video", "screenrec", "wf-recorder", "capture"] },
                { id: "qs:popup:storage",       name: "Removable Drives",      comment: "Mount, open and safely eject USB & SD drives",               icon: "usb",                 keywords: ["usb", "drives", "storage", "eject", "mount", "sd"] },
                { id: "qs:popup:privacy",       name: "Privacy Status",        comment: "Apps currently using your microphone, camera or screen",      icon: "shield",              keywords: ["privacy", "microphone", "camera", "webcam", "screenshare"] },
                { id: "qs:bar-settings",        name: "Bar Settings",          comment: "Toggle bar items on/off, reorder and move between sections", icon: "view_agenda",         keywords: ["bar", "panel", "customize", "modules", "order", "toggle"] },
                { id: "qs:opacity-settings",    name: "Opacity & Transparency", comment: "Separate opacity sliders for widgets, bar, notifications & OSD toast", icon: "opacity",      keywords: ["opacity", "transparency", "alpha", "appearance", "glass", "bar", "widgets", "notifications", "toast", "osd"] },
                { id: "qs:theme-settings",      name: "Theme & Profiles",      comment: "Customize colors, opacity, radii, bar sizing, fonts & saved profiles", icon: "palette",      keywords: ["theme", "profile", "profiles", "colors", "accent", "font", "dark", "light", "appearance", "style"] },
                { id: "qs:popup:stats",         name: "System Monitor (Minimon)", comment: "CPU, temperature, memory, network, disk & GPU graphs and settings", icon: "monitoring",   keywords: ["minimon", "cpu", "ram", "memory", "gpu", "network", "disk", "stats"] },
                { id: "qs:quicksettings",       name: "Quick Settings",        comment: "Toggles, volume/brightness sliders, media and power mode",   icon: "tune",                keywords: ["control", "toggles", "sliders", "tlp"] },
                { id: "qs:popup:calendar",      name: "Calendar & Events",     comment: "Month calendar, agenda and Nextcloud / Google / Neptun",     icon: "calendar_month",      keywords: ["date", "time", "clock", "agenda", "nextcloud", "events"] },
                { id: "qs:popup:weather",       name: "Weather",               comment: "Forecast, hourly timeline, location & modular weather settings", icon: "partly_cloudy_day", keywords: ["forecast", "temperature", "rain", "wind", "location", "weather settings", "units"] },
                { id: "qs:popup:clipboard",     name: "Clipboard History",     comment: "Search, copy and delete recent clipboard entries",           icon: "content_paste",       keywords: ["paste", "copy", "cliphist"] },
                { id: "qs:popup:notifications", name: "Notifications",         comment: "Notification center, history and Do Not Disturb",            icon: "notifications",       keywords: ["dnd", "do not disturb", "alerts", "bell"] },
                { id: "qs:popup:volume",        name: "Audio & Volume",        comment: "Output, input devices and per-application volume mixer",     icon: "volume_up",           keywords: ["sound", "speaker", "microphone", "mute", "pipewire"] },
                { id: "qs:popup:network",       name: "Network, Wi-Fi & VPN",   comment: "Wi-Fi networks, VPN profiles and Ethernet status",           icon: "wifi",                keywords: ["internet", "wlan", "ethernet", "nm", "vpn", "wireguard"] },
                { id: "qs:popup:bluetooth",     name: "Bluetooth",             comment: "Bluetooth toggle, paired and nearby devices",                icon: "bluetooth",           keywords: ["pair", "connect", "headphones"] },
                { id: "qs:popup:display",       name: "Display & Brightness",  comment: "Screen brightness, keyboard light, monitors, screenshots",   icon: "desktop_windows",     keywords: ["monitor", "backlight", "keyboard", "screenshot"] },
                { id: "qs:popup:media",         name: "Media Player",          comment: "Now playing cover, seek bar, controls and player switcher",  icon: "play_arrow",          keywords: ["music", "mpris", "player", "spotify"] },
                { id: "qs:popup:nightlight",    name: "Night Light",           comment: "Screen warmth temperature and schedule (hyprsunset)",        icon: "nightlight",          keywords: ["warm", "blue light", "hyprsunset", "temperature"] },
                { id: "qs:popup:caffeine",      name: "Caffeine",              comment: "Keep screen awake indefinitely or for a fixed timer",        icon: "coffee",              keywords: ["awake", "idle", "sleep", "inhibit", "timer"] },
                { id: "qs:popup:battery",       name: "Battery & Power Mode",  comment: "Battery charge, health and TLP power profile selector",      icon: "battery_full",        keywords: ["tlp", "power saver", "balanced", "performance", "charge"] },
                { id: "qs:popup:layout",        name: "Tiling Layout",         comment: "Switch between scrolling (niri) and dwindle layouts",        icon: "view_column",         keywords: ["niri", "scrolling", "dwindle", "columns"] },
                { id: "qs:colorpicker",         name: "Color Picker",          comment: "Pick a pixel color on screen (#RRGGBB to clipboard)",        icon: "colorize",            keywords: ["hyprpicker", "hex", "eyedropper"] },
                { id: "qs:emoji",               name: "Emoji Picker",          comment: "Search and insert emojis",                                   icon: "sentiment_satisfied", keywords: ["emoticon", "unicode"], keepOpen: true },
                { id: "qs:popup:background",    name: "Background Settings",   comment: "Toggle slideshows, single images, live scenes & effects",    icon: "photo_library",       keywords: ["wallpaper", "background", "slideshow", "animated"] },
                { id: "qs:wallpaper",           name: "Next Wallpaper",        comment: "Switch to a new random wallpaper now",                       icon: "wallpaper",           keywords: ["background", "bing"] },
                { id: "qs:lock",                name: "Lock Screen",           comment: "Lock the session immediately (SUPER+CTRL+L)",                icon: "lock",                keywords: ["lock", "screen", "howdy", "security"] },
                { id: "qs:popup:power",         name: "Power Menu",            comment: "Lock, suspend, log out, restart or shut down",               icon: "power_settings_new",  keywords: ["lock", "suspend", "logout", "reboot", "shutdown"] }
            ]

            function score(q: string, e): real {
                const name = (e.name || "").toLowerCase();
                if (name === q) return 1000;
                if (name.startsWith(q)) return 900 - name.length;
                if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 700 - name.length;
                if (name.includes(q)) return 600 - name.length;
                const other = [e.genericName, e.comment, e.id].concat(e.keywords || []).join(" ").toLowerCase();
                if (other.includes(q)) return 400;
                // fuzzy: all query chars appear in order in the name; fewer gaps = better
                let pos = -1, gaps = 0;
                for (const c of q) {
                    const next = name.indexOf(c, pos + 1);
                    if (next < 0) return -1;
                    if (pos >= 0) gaps += next - pos - 1;
                    pos = next;
                }
                return 200 - gaps;
            }

            readonly property var apps: {
                const all = DesktopEntries.applications.values.filter(e => !e.noDisplay);
                const q = query.trim().toLowerCase();
                const used = e => root.usage[e.id] || 0;
                if (q === "")
                    return all.slice().sort((a, b) => used(b) - used(a) || a.name.localeCompare(b.name));
                return all.map(e => ({ e, s: score(q, e) }))
                          .filter(x => x.s >= 0)
                          .sort((a, b) => (b.s + Math.min(used(b.e), 50)) - (a.s + Math.min(used(a.e), 50)) || a.e.name.localeCompare(b.e.name))
                          .map(x => x.e);
            }

            readonly property var results: {
                if (mode === "shell") {
                    const q = query.slice(1).trim().toLowerCase();
                    const list = q === ""
                        ? shellApps
                        : shellApps.map(e => ({ e, s: score(q, e) }))
                                   .filter(x => x.s >= 0)
                                   .sort((a, b) => b.s - a.s)
                                   .map(x => x.e);
                    return list.map(e => ({ kind: "shell", id: e.id, title: e.name, subtitle: e.comment, icon: e.icon, keepOpen: Boolean(e.keepOpen) }));
                }
                if (mode === "calc") {
                    const expr = query.replace(/^=/, "").trim();
                    if (expr === "") return [];
                    const out = [{ kind: "calc", title: calcResult !== "" ? calcResult : "…", subtitle: expr + " · Enter to copy", icon: "calculate" }];
                    out.push({ kind: "web", queryText: expr, title: `Search web for "${expr}"`, subtitle: "Open in default web browser", icon: "public" });
                    return out;
                }
                if (mode === "web") {
                    const wq = query.slice(1).trim();
                    return wq === "" ? [] : [{ kind: "web", queryText: wq, title: `Search web for "${wq}"`, subtitle: "Open in default web browser", icon: "public" }];
                }
                if (mode === "emoji")
                    return Emoji.search(query.slice(1), 80).map(e => ({ kind: "emoji", char: e.char, title: e.name, subtitle: e.group }));
                if (mode === "run") {
                    const cmd = query.slice(1).trim();
                    return cmd === "" ? [] : [{ kind: "run", title: cmd, subtitle: "Run command · Shift+Enter runs in a terminal", icon: "terminal" }];
                }
                const appItems = apps.map(e => ({ kind: "app", entry: e, title: e.name, subtitle: e.comment || e.genericName || "" }));
                const q = query.trim().toLowerCase();
                if (q !== "") {
                    const settingsEntry = shellApps[0];
                    const s = score(q, settingsEntry);
                    if (s >= 400) {
                        appItems.unshift({ kind: "shell", id: settingsEntry.id, title: "HCS Settings", subtitle: settingsEntry.comment, icon: settingsEntry.icon, keepOpen: false });
                    }
                    if (appItems.length === 0) {
                        const rawQ = query.trim();
                        appItems.push({ kind: "web", queryText: rawQ, title: `Search web for "${rawQ}"`, subtitle: "No matching apps · Enter to search in browser", icon: "public" });
                    }
                }
                return appItems;
            }

            function activate(i: int, inTerminal: bool) {
                const r = results[i];
                if (!r) return;
                if (r.kind === "app") {
                    root.bump(r.entry.id);
                    if (r.entry.runInTerminal && r.entry.command && r.entry.command.length > 0) {
                        const termArgs = ["kitty"];
                        if (r.entry.workingDirectory) termArgs.push("--directory", r.entry.workingDirectory);
                        termArgs.push("-e");
                        Quickshell.execDetached(termArgs.concat(r.entry.command));
                    } else {
                        r.entry.execute();
                    }
                } else if (r.kind === "shell") {
                    root.bump(r.id);
                    if (r.keepOpen) {
                        win.previousQuery = search.text;
                        search.text = ":";
                        search.focusInput();
                        return;
                    }
                    root.triggerShellApp(r.id, win.screen?.name ?? "");
                    return;
                } else if (r.kind === "run") {
                    const cmd = query.slice(1).trim();
                    Quickshell.execDetached(inTerminal
                        ? ["kitty", "-e", "sh", "-c", 'sh -c "$1"; exec "${SHELL:-sh}"', "sh", cmd]
                        : ["sh", "-c", cmd]);
                } else if (r.kind === "emoji") {
                    Emoji.insert(r.char, !inTerminal);
                } else if (r.kind === "calc") {
                    if (calcResult === "") return;
                    Quickshell.execDetached(["wl-copy", "--", calcResult]);
                } else if (r.kind === "web") {
                    const wq = (r.queryText || "").trim();
                    if (wq === "") return;
                    const url = /^https?:\/\//i.test(wq) ? wq : ("https://duckduckgo.com/?q=" + encodeURIComponent(wq));
                    Quickshell.execDetached(["xdg-open", url]);
                }
                root.open = false;
            }

            function move(d: int) {
                if (list.count === 0) return;
                list.currentIndex = (list.currentIndex + d + list.count) % list.count;
            }

            onQueryChanged: {
                list.currentIndex = 0;
                if (query === "") win.previousQuery = "";
                if (mode === "calc") {
                    win.calcResult = "";
                    calcTimer.restart();
                } else {
                    calcTimer.stop();
                    calc.running = false;
                    win.calcResult = "";
                }
            }

            Timer {
                id: calcTimer
                interval: 120
                onTriggered: {
                    calc.running = false;
                    calc.command = ["qalc", "-t", "--", win.normalizeCalcExpr(win.query)];
                    calc.running = true;
                }
            }
            Process {
                id: calc
                stdout: StdioCollector { onStreamFinished: if (win.mode === "calc") win.calcResult = text.trim() }
            }

            // Click outside the box closes.
            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }

            Rectangle {
                id: box
                width: Math.min(640, win.width - 2 * Theme.spaceL)
                height: column.implicitHeight + 2 * Theme.spaceS
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(win.height * 0.16)
                radius: Theme.radiusM
                color: Theme.popupBg
                border.color: Theme.popupBorder
                border.width: Theme.popupBorderWidth

                property bool entered: false
                opacity: entered ? 1.0 : 0.0
                scale: entered ? 1.0 : 0.96
                transformOrigin: Item.Top
                transform: Translate {
                    y: box.entered ? 0 : -10
                    Behavior on y { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                }
                Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                Component.onCompleted: Qt.callLater(() => { box.entered = true; })

                // Swallow clicks so they don't reach the close-area behind.
                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: column
                    anchors.fill: parent
                    anchors.margins: Theme.spaceS
                    spacing: Theme.spaceXs

                    TextField {
                        id: search
                        Layout.fillWidth: true
                        implicitHeight: 44
                        placeholder: "Search apps · ! shell · = calc · > cmd · : emoji · ? web"
                        input.font.pixelSize: Theme.fontSizeLarge
                        Component.onCompleted: { text = root.initialQuery; focusInput(); }

                        input.Keys.onPressed: e => {
                            const ctrl = e.modifiers & Qt.ControlModifier;
                            if (e.key === Qt.Key_Escape) {
                                if (win.previousQuery !== "") {
                                    const prev = win.previousQuery;
                                    win.previousQuery = "";
                                    search.text = prev;
                                } else {
                                    root.open = false;
                                }
                                e.accepted = true;
                            }
                            else if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier)) || (ctrl && e.key === Qt.Key_J)) { win.move(1); e.accepted = true; }
                            else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || (ctrl && e.key === Qt.Key_K)) { win.move(-1); e.accepted = true; }
                            else if (e.key === Qt.Key_PageDown) { win.move(5); e.accepted = true; }
                            else if (e.key === Qt.Key_PageUp) { win.move(-5); e.accepted = true; }
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                win.activate(list.currentIndex, e.modifiers & Qt.ShiftModifier);
                                e.accepted = true;
                            }
                        }
                    }

                    ListView {
                        id: list
                        visible: count > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(count, 8) * 52 + Math.max(0, Math.min(count, 8) - 1) * spacing
                        clip: true
                        spacing: 2
                        model: win.results
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: 0
                        keyNavigationEnabled: false

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool selected: ListView.isCurrentItem
                            width: ListView.view.width
                            height: 52
                            radius: Theme.radiusS
                            color: selected ? Theme.componentHover : mouse.containsMouse ? Theme.component : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spaceXs
                                anchors.rightMargin: Theme.spaceXs
                                spacing: Theme.spaceXs

                                IconImage {
                                    id: appIcon
                                    visible: row.modelData.kind === "app"
                                    implicitSize: 32
                                    asynchronous: true
                                    // Some .desktop files point at icon files that don't exist; fall back once.
                                    property bool failed: false
                                    onStatusChanged: if (status === Image.Error) failed = true
                                    source: {
                                        if (failed) return Quickshell.iconPath("application-x-executable");
                                        const i = row.modelData.entry?.icon ?? "";
                                        return i.startsWith("/") ? "file://" + i : Quickshell.iconPath(i, "application-x-executable");
                                    }
                                }
                                Text {
                                    visible: row.modelData.kind === "emoji"
                                    text: row.modelData.char ?? ""
                                    font.family: "Noto Color Emoji"
                                    font.pixelSize: 26
                                    Layout.preferredWidth: 32
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                Icon {
                                    visible: row.modelData.kind !== "app" && row.modelData.kind !== "emoji"
                                    icon: row.modelData.icon ?? ""
                                    size: 28
                                    Layout.preferredWidth: 32
                                    color: Theme.accent
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: row.modelData.title
                                        elide: Text.ElideRight
                                        color: row.selected ? Theme.accent : Theme.text
                                        font.pixelSize: row.modelData.kind === "calc" ? Theme.fontSizeTitle : Theme.fontSize
                                        font.weight: row.modelData.kind === "calc" ? Font.Bold : Font.Normal
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        visible: text !== ""
                                        text: row.modelData.subtitle
                                        elide: Text.ElideRight
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.textDim
                                    }
                                }
                                StyledText {
                                    visible: row.selected
                                    text: "↵"
                                    color: Theme.textDim
                                }
                            }

                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: list.currentIndex = row.index
                                onClicked: win.activate(row.index, false)
                            }
                        }
                    }

                    StyledText {
                        visible: list.count === 0 && win.query !== ""
                        Layout.fillWidth: true
                        Layout.margins: Theme.spaceXs
                        horizontalAlignment: Text.AlignHCenter
                        text: "No results"
                        color: Theme.textDim
                    }
                }
            }
        }
    }
}
