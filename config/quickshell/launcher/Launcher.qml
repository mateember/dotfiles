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

// COSMIC-launcher-style app launcher.
//   qs -p <root>/shell ipc call launcher toggle      (SUPER Space)
// Typing searches installed apps (fuzzy, most-used first). Prefixes:
//   =expr    calculator (qalc); plain math like "2*21" works too. Enter copies the result.
//   >cmd     run a shell command. Shift+Enter runs it in a terminal (kitty).
//   :name    emoji picker. Enter types the emoji into the focused window (and copies it),
//            Shift+Enter only copies. Also: ipc call launcher emoji (SUPER period).
//   !name    Quickshell built-in apps & panels (also /name or @name). Also: ipc call launcher shell.
// Keys: ↑/↓ (also Tab, Ctrl+J/K) select, Enter launch, Esc close.
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
            if (id === "qs:bar-settings") BarConfig.settingsOpen = true;
            else if (id === "qs:overview") Hypr.openOverview();
            else if (id === "qs:quicksettings") QuickSettingsState.openWindow();
            else if (id === "qs:colorpicker") ColorPicker.pick();
            else if (id === "qs:wallpaper") Wallpapers.next();
            else if (id.startsWith("qs:popup:")) Popups.openWindow(id.slice(9) + "@" + scr);
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.initialQuery = ""; root.toggle(); }
        function emoji(): void { root.initialQuery = root.open ? "" : ":"; root.toggle(); }
        function shell(): void { root.initialQuery = root.open ? "" : "!"; root.toggle(); }
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
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

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            WlrLayershell.namespace: "hcs-launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            property string query: search.text
            readonly property string mode: query.startsWith(":") ? "emoji"
                                         : (query.startsWith("!") || query.startsWith("/") || query.startsWith("@")) ? "shell"
                                         : query.startsWith("=") ? "calc"
                                         : query.startsWith(">") ? "run"
                                         : /^[\d\s.,()+\-*/^%]+$/.test(query) && /\d\s*[+\-*/^%]\s*[\d(]/.test(query) ? "calc"
                                         : "apps"
            property string calcResult: ""

            readonly property var shellApps: [
                { id: "qs:overview",            name: "Overview",              comment: "KDE Plasma-style workspaces & live window previews (SUPER+Tab)", icon: "grid_view",        keywords: ["workspaces", "desktops", "expose", "windows", "plasma"] },
                { id: "qs:bar-settings",        name: "Bar Settings",          comment: "Toggle bar items on/off, reorder and move between sections", icon: "view_agenda",         keywords: ["bar", "panel", "customize", "modules", "order", "toggle"] },
                { id: "qs:popup:stats",         name: "System Monitor (Minimon)", comment: "CPU, temperature, memory, network, disk & GPU graphs and settings", icon: "monitoring",   keywords: ["minimon", "cpu", "ram", "memory", "gpu", "network", "disk", "stats"] },
                { id: "qs:quicksettings",       name: "Quick Settings",        comment: "Toggles, volume/brightness sliders, media and power mode",   icon: "tune",                keywords: ["control", "toggles", "sliders", "tlp"] },
                { id: "qs:popup:calendar",      name: "Calendar & Events",     comment: "Month calendar, agenda and Nextcloud / Google / Neptun",     icon: "calendar_month",      keywords: ["date", "time", "clock", "agenda", "nextcloud", "events"] },
                { id: "qs:popup:weather",       name: "Weather",               comment: "Today's rain, humidity, wind, UV, pressure and forecast",    icon: "partly_cloudy_day",   keywords: ["forecast", "temperature", "rain", "wind"] },
                { id: "qs:popup:clipboard",     name: "Clipboard History",     comment: "Search, copy and delete recent clipboard entries",           icon: "content_paste",       keywords: ["paste", "copy", "cliphist"] },
                { id: "qs:popup:notifications", name: "Notifications",         comment: "Notification center, history and Do Not Disturb",            icon: "notifications",       keywords: ["dnd", "do not disturb", "alerts", "bell"] },
                { id: "qs:popup:volume",        name: "Audio & Volume",        comment: "Output, input devices and per-application volume mixer",     icon: "volume_up",           keywords: ["sound", "speaker", "microphone", "mute", "pipewire"] },
                { id: "qs:popup:network",       name: "Network & Wi-Fi",       comment: "Wi-Fi networks, passwords and Ethernet status",              icon: "wifi",                keywords: ["internet", "wlan", "ethernet", "nm"] },
                { id: "qs:popup:bluetooth",     name: "Bluetooth",             comment: "Bluetooth toggle, paired and nearby devices",                icon: "bluetooth",           keywords: ["pair", "connect", "headphones"] },
                { id: "qs:popup:display",       name: "Display & Brightness",  comment: "Screen brightness, keyboard light, monitors, screenshots",   icon: "desktop_windows",     keywords: ["monitor", "backlight", "keyboard", "screenshot"] },
                { id: "qs:popup:media",         name: "Media Player",          comment: "Now playing cover, seek bar, controls and player switcher",  icon: "play_arrow",          keywords: ["music", "mpris", "player", "spotify"] },
                { id: "qs:popup:nightlight",    name: "Night Light",           comment: "Screen warmth temperature and schedule (hyprsunset)",        icon: "nightlight",          keywords: ["warm", "blue light", "hyprsunset", "temperature"] },
                { id: "qs:popup:battery",       name: "Battery & Power Mode",  comment: "Battery charge, health and TLP power profile selector",      icon: "battery_full",        keywords: ["tlp", "power saver", "balanced", "performance", "charge"] },
                { id: "qs:popup:layout",        name: "Tiling Layout",         comment: "Switch between scrolling (niri) and dwindle layouts",        icon: "view_column",         keywords: ["niri", "scrolling", "dwindle", "columns"] },
                { id: "qs:colorpicker",         name: "Color Picker",          comment: "Pick a pixel color on screen (#RRGGBB to clipboard)",        icon: "colorize",            keywords: ["hyprpicker", "hex", "eyedropper"] },
                { id: "qs:emoji",               name: "Emoji Picker",          comment: "Search and insert emojis",                                   icon: "sentiment_satisfied", keywords: ["emoticon", "unicode"], keepOpen: true },
                { id: "qs:wallpaper",           name: "Next Wallpaper",        comment: "Switch to a new random wallpaper now",                       icon: "wallpaper",           keywords: ["background", "bing"] },
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
                    return expr === "" ? [] : [{ kind: "calc", title: calcResult !== "" ? calcResult : "…", subtitle: expr + " · Enter to copy", icon: "calculate" }];
                }
                if (mode === "emoji")
                    return Emoji.search(query.slice(1), 80).map(e => ({ kind: "emoji", char: e.char, title: e.name, subtitle: e.group }));
                if (mode === "run") {
                    const cmd = query.slice(1).trim();
                    return cmd === "" ? [] : [{ kind: "run", title: cmd, subtitle: "Run command · Shift+Enter runs in a terminal", icon: "terminal" }];
                }
                return apps.map(e => ({ kind: "app", entry: e, title: e.name, subtitle: e.comment || e.genericName || "" }));
            }

            function activate(i: int, inTerminal: bool) {
                const r = results[i];
                if (!r) return;
                if (r.kind === "app") {
                    root.bump(r.entry.id);
                    if (r.entry.runInTerminal) Quickshell.execDetached(["kitty", "-e"].concat(r.entry.command));
                    else r.entry.execute();
                } else if (r.kind === "shell") {
                    root.bump(r.id);
                    if (r.keepOpen) {
                        search.text = ":";
                        search.focusInput();
                        return;
                    }
                    root.triggerShellApp(r.id, win.screen?.name ?? "");
                    return;
                } else if (r.kind === "run") {
                    const cmd = query.slice(1).trim();
                    Quickshell.execDetached(inTerminal ? ["kitty", "-e", "sh", "-c", cmd + '; exec "${SHELL:-sh}"'] : ["sh", "-c", cmd]);
                } else if (r.kind === "emoji") {
                    Emoji.insert(r.char, !inTerminal);
                } else if (r.kind === "calc") {
                    if (calcResult === "") return;
                    Quickshell.execDetached(["wl-copy", calcResult]);
                }
                root.open = false;
            }

            function move(d: int) {
                if (list.count === 0) return;
                list.currentIndex = (list.currentIndex + d + list.count) % list.count;
            }

            onQueryChanged: {
                list.currentIndex = 0;
                if (mode === "calc") calcTimer.restart();
            }

            Timer {
                id: calcTimer
                interval: 120
                onTriggered: {
                    calc.running = false;
                    calc.command = ["qalc", "-t", win.query.replace(/^=/, "").trim()];
                    calc.running = true;
                }
            }
            Process {
                id: calc
                stdout: StdioCollector { onStreamFinished: win.calcResult = text.trim() }
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
                border.width: 1

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
                        placeholder: "Search apps · ! shell apps · = calculate · > command · : emoji"
                        input.font.pixelSize: Theme.fontSizeLarge
                        Component.onCompleted: { text = root.initialQuery; focusInput(); }

                        input.Keys.onPressed: e => {
                            const ctrl = e.modifiers & Qt.ControlModifier;
                            if (e.key === Qt.Key_Escape) { root.open = false; e.accepted = true; }
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
