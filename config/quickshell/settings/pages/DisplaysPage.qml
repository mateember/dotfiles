import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services
import "../components"

ColumnLayout {
    id: root

    spacing: Theme.spaceM

    // Editable local copy of monitors for interactive drag/snap arrangement before clicking Apply.
    property var draftMonitors: []
    property string selectedMonitorName: ""
    property bool draftDirty: false

    readonly property var selectedMonitor: {
        for (const m of draftMonitors)
            if (m.name === selectedMonitorName) return m;
        return draftMonitors.length > 0 ? draftMonitors[0] : null;
    }

    function syncFromLive() {
        const list = HyprSettings.monitors.map(m => ({
            name: m.name,
            description: m.description,
            disabled: Boolean(m.disabled),
            width: m.width,
            height: m.height,
            refreshRate: m.refreshRate,
            mode: `${m.width}x${m.height}@${Number(m.refreshRate).toFixed(2)}`,
            x: m.x,
            y: m.y,
            scale: m.scale || 1,
            vrr: m.vrr ? 1 : 0,
            transform: m.transform || 0,
            mirror: "",
            availableModes: m.availableModes || []
        }));
        root.draftMonitors = list;
        if (list.length > 0 && !list.some(m => m.name === root.selectedMonitorName))
            root.selectedMonitorName = list[0].name;
        root.draftDirty = false;
    }

    function updateDraft(name: string, patch) {
        root.draftMonitors = root.draftMonitors.map(m => m.name === name ? Object.assign({}, m, patch) : m);
        root.draftDirty = true;
    }

    function logicalSize(m): var {
        const s = (m.scale && m.scale > 0) ? m.scale : 1;
        const rot = (m.transform === 1 || m.transform === 3 || m.transform === 5 || m.transform === 7);
        const w = (rot ? m.height : m.width) / s;
        const h = (rot ? m.width : m.height) / s;
        return { w: Math.round(w), h: Math.round(h) };
    }

    function applyPreset(kind: string) {
        if (draftMonitors.length < 2) return;
        const next = draftMonitors.map(m => Object.assign({}, m, { mirror: "", disabled: false }));
        next[0].x = 0;
        next[0].y = 0;
        const s0 = logicalSize(next[0]);
        for (let i = 1; i < next.length; i++) {
            const si = logicalSize(next[i]);
            if (kind === "right") {
                next[i].x = next[i - 1].x + logicalSize(next[i - 1]).w;
                next[i].y = 0;
            } else if (kind === "left") {
                next[i].x = next[i - 1].x - si.w;
                next[i].y = 0;
            } else if (kind === "above") {
                next[i].x = Math.round((s0.w - si.w) / 2);
                next[i].y = -si.h;
            } else if (kind === "mirror") {
                next[i].x = 0;
                next[i].y = 0;
                next[i].mirror = next[0].name;
            }
        }
        root.draftMonitors = next;
        root.draftDirty = true;
    }

    function snapPosition(movingName: string, rawX: int, rawY: int): var {
        const me = draftMonitors.find(m => m.name === movingName);
        if (!me) return { x: rawX, y: rawY };
        const mySize = logicalSize(me);
        const thresh = 70;
        let x = rawX, y = rawY;
        for (const other of draftMonitors) {
            if (other.name === movingName || other.disabled) continue;
            const os = logicalSize(other);
            // Snap horizontal edges
            if (Math.abs(x - (other.x + os.w)) < thresh) x = other.x + os.w;
            else if (Math.abs((x + mySize.w) - other.x) < thresh) x = other.x - mySize.w;
            else if (Math.abs(x - other.x) < thresh) x = other.x;
            // Snap vertical edges
            if (Math.abs(y - (other.y + os.h)) < thresh) y = other.y + os.h;
            else if (Math.abs((y + mySize.h) - other.y) < thresh) y = other.y - mySize.h;
            else if (Math.abs(y - other.y) < thresh) y = other.y;
        }
        return { x: Math.round(x), y: Math.round(y) };
    }

    Component.onCompleted: {
        HyprSettings.refreshMonitors();
        Brightness.refreshExternals();
        syncFromLive();
    }

    Connections {
        target: HyprSettings
        function onMonitorsChanged() {
            if (!root.draftDirty) root.syncFromLive();
        }
    }

    SettingsPageHeader {
        icon: "desktop_windows"
        title: "Displays & Night Light"
        subtitle: "Arrange monitors, adjust resolution, refresh rate, scale, brightness, and screen warmth"

        SettingsActionButton {
            icon: "refresh"
            text: "Refresh"
            onClicked: {
                HyprSettings.refreshMonitors();
                Brightness.refreshExternals();
                root.syncFromLive();
            }
        }
    }

    // ---- 15-Second Safety Confirmation Banner ----
    Rectangle {
        visible: HyprSettings.revertCountdown > 0
        Layout.fillWidth: true
        implicitHeight: safetyRow.implicitHeight + 2 * Theme.spaceXs
        radius: Theme.radiusM
        color: Theme.alpha(Theme.warning, 0.20)
        border.width: 1.5
        border.color: Theme.warning

        RowLayout {
            id: safetyRow
            anchors.fill: parent
            anchors.margins: Theme.spaceXs
            spacing: Theme.spaceXs

            Icon { icon: "warning"; size: 22; color: Theme.warning }
            StyledText {
                Layout.fillWidth: true
                text: "Keep these display settings? Reverting automatically in " + HyprSettings.revertCountdown + " s…"
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }
            SettingsActionButton {
                variant: "accent"
                text: "Keep Changes"
                onClicked: HyprSettings.confirmMonitors()
            }
            SettingsActionButton {
                variant: "danger"
                text: "Revert Now"
                onClicked: HyprSettings.revertMonitors()
            }
        }
    }

    // ---- Interactive Monitor Arrangement Canvas ----
    SettingsSection {
        title: "Monitor Arrangement"
        description: "Drag displays with mouse or touch to reposition (auto-snaps to edges), then click Apply"

        Rectangle {
            id: arrangeCanvas
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXxs
            implicitHeight: 220
            radius: Theme.radiusS
            color: Theme.bg
            border.width: 1
            border.color: Theme.divider
            clip: true

            readonly property var bounds: {
                let minX = 0, minY = 0, maxX = 1920, maxY = 1080;
                let first = true;
                for (const m of root.draftMonitors) {
                    if (m.disabled) continue;
                    const sz = root.logicalSize(m);
                    if (first) {
                        minX = m.x; minY = m.y; maxX = m.x + sz.w; maxY = m.y + sz.h;
                        first = false;
                    } else {
                        minX = Math.min(minX, m.x);
                        minY = Math.min(minY, m.y);
                        maxX = Math.max(maxX, m.x + sz.w);
                        maxY = Math.max(maxY, m.y + sz.h);
                    }
                }
                return { minX: minX, minY: minY, w: Math.max(800, maxX - minX), h: Math.max(600, maxY - minY) };
            }

            readonly property real pad: 24
            readonly property real scaleFactor: Math.min(
                (width - 2 * pad) / Math.max(1, bounds.w + 400),
                (height - 2 * pad) / Math.max(1, bounds.h + 300),
                0.14
            )
            readonly property real originX: (width - bounds.w * scaleFactor) / 2 - bounds.minX * scaleFactor
            readonly property real originY: (height - bounds.h * scaleFactor) / 2 - bounds.minY * scaleFactor

            Repeater {
                model: root.draftMonitors
                delegate: Rectangle {
                    id: monBox
                    required property var modelData
                    readonly property var sz: root.logicalSize(modelData)
                    readonly property bool selected: root.selectedMonitorName === modelData.name

                    x: Math.round(arrangeCanvas.originX + modelData.x * arrangeCanvas.scaleFactor)
                    y: Math.round(arrangeCanvas.originY + modelData.y * arrangeCanvas.scaleFactor)
                    width: Math.max(76, Math.round(sz.w * arrangeCanvas.scaleFactor))
                    height: Math.max(48, Math.round(sz.h * arrangeCanvas.scaleFactor))
                    radius: Theme.radiusS
                    opacity: modelData.disabled ? 0.45 : 1.0
                    color: selected ? Theme.alpha(Theme.accent, 0.28) : Theme.primaryComponent
                    border.width: selected ? 2 : 1
                    border.color: selected ? Theme.accent : Theme.componentBorder

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        spacing: 1
                        StyledText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: monBox.modelData.name
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: monBox.selected ? Theme.accent : Theme.textStrong
                            elide: Text.ElideRight
                        }
                        StyledText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: monBox.modelData.disabled ? "Disabled"
                                : (monBox.modelData.mirror ? ("Mirror " + monBox.modelData.mirror)
                                   : (monBox.modelData.width + "×" + monBox.modelData.height))
                            font.pixelSize: 10
                            color: Theme.textDim
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        preventStealing: true
                        cursorShape: Qt.OpenHandCursor
                        property real startGlobalX: 0
                        property real startGlobalY: 0
                        property real startMonX: 0
                        property real startMonY: 0

                        onPressed: e => {
                            root.selectedMonitorName = monBox.modelData.name;
                            startGlobalX = e.x + monBox.x;
                            startGlobalY = e.y + monBox.y;
                            startMonX = monBox.modelData.x;
                            startMonY = monBox.modelData.y;
                            cursorShape = Qt.ClosedHandCursor;
                        }
                        onPositionChanged: e => {
                            if (!pressed) return;
                            const curX = e.x + monBox.x;
                            const curY = e.y + monBox.y;
                            const dx = (curX - startGlobalX) / Math.max(0.01, arrangeCanvas.scaleFactor);
                            const dy = (curY - startGlobalY) / Math.max(0.01, arrangeCanvas.scaleFactor);
                            const snapped = root.snapPosition(monBox.modelData.name, Math.round(startMonX + dx), Math.round(startMonY + dy));
                            root.updateDraft(monBox.modelData.name, { x: snapped.x, y: snapped.y, mirror: "" });
                        }
                        onReleased: cursorShape = Qt.OpenHandCursor
                    }
                }
            }
        }

        // Quick Multi-Monitor Layout Presets + Apply
        Flow {
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXxs
            spacing: Theme.spaceXxs

            SettingsActionButton { visible: root.draftMonitors.length > 1; icon: "arrow_forward"; text: "Extend Right"; onClicked: root.applyPreset("right") }
            SettingsActionButton { visible: root.draftMonitors.length > 1; icon: "arrow_back";    text: "Extend Left";  onClicked: root.applyPreset("left") }
            SettingsActionButton { visible: root.draftMonitors.length > 1; icon: "arrow_upward";  text: "Stack Above";  onClicked: root.applyPreset("above") }
            SettingsActionButton { visible: root.draftMonitors.length > 1; icon: "flip_to_front"; text: "Mirror";       onClicked: root.applyPreset("mirror") }

            SettingsActionButton {
                variant: "accent"
                icon: "check"
                text: "Apply Arrangement"
                buttonEnabled: root.draftDirty
                onClicked: {
                    HyprSettings.applyMonitorPlan(root.draftMonitors, true);
                    root.draftDirty = false;
                }
            }
            SettingsActionButton {
                visible: root.draftDirty
                text: "Discard"
                onClicked: root.syncFromLive()
            }
        }
    }

    // ---- Selected Monitor Properties ----
    SettingsSection {
        visible: root.selectedMonitor !== null
        title: root.selectedMonitor ? ("Display: " + root.selectedMonitor.name) : "Display"
        description: root.selectedMonitor ? (root.selectedMonitor.description || "") : ""

        SettingsRow {
            icon: "power_settings_new"
            title: "Enable Display"
            subtitle: root.selectedMonitor && root.selectedMonitor.disabled ? "Output is disabled" : "Output active"

            Toggle {
                checked: root.selectedMonitor ? !root.selectedMonitor.disabled : true
                enabled: root.draftMonitors.length > 1 || (root.selectedMonitor && root.selectedMonitor.disabled)
                onToggled: if (root.selectedMonitor) root.updateDraft(root.selectedMonitor.name, { disabled: !root.selectedMonitor.disabled })
            }
        }

        // Scale presets
        ColumnLayout {
            visible: root.selectedMonitor && !root.selectedMonitor.disabled
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: 6

            StyledText { text: "Scale"; font.weight: Font.Medium }
            SettingsPillGroup {
                selectedId: root.selectedMonitor ? Number(root.selectedMonitor.scale).toFixed(2).replace(/\.00$/, "") : "1"
                model: [
                    { id: "1",    label: "100%" },
                    { id: "1.25", label: "125%" },
                    { id: "1.50", label: "150%" },
                    { id: "1.75", label: "175%" },
                    { id: "2",    label: "200%" }
                ]
                onPicked: id => { if (root.selectedMonitor) root.updateDraft(root.selectedMonitor.name, { scale: parseFloat(id) }); }
            }
        }

        // VRR presets
        ColumnLayout {
            visible: root.selectedMonitor && !root.selectedMonitor.disabled
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: 6

            StyledText { text: "Variable Refresh Rate (VRR)"; font.weight: Font.Medium }
            SettingsPillGroup {
                selectedId: root.selectedMonitor ? String(root.selectedMonitor.vrr) : "0"
                model: [
                    { id: "0", label: "Off" },
                    { id: "1", label: "Always On" },
                    { id: "2", label: "Fullscreen Only" }
                ]
                onPicked: id => { if (root.selectedMonitor) root.updateDraft(root.selectedMonitor.name, { vrr: parseInt(id) }); }
            }
        }

        // Rotation / Transform
        ColumnLayout {
            visible: root.selectedMonitor && !root.selectedMonitor.disabled
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: 6

            StyledText { text: "Orientation"; font.weight: Font.Medium }
            SettingsPillGroup {
                selectedId: root.selectedMonitor ? String(root.selectedMonitor.transform) : "0"
                model: [
                    { id: "0", label: "Landscape" },
                    { id: "1", label: "90°" },
                    { id: "2", label: "180°" },
                    { id: "3", label: "270°" }
                ]
                onPicked: id => { if (root.selectedMonitor) root.updateDraft(root.selectedMonitor.name, { transform: parseInt(id) }); }
            }
        }

        // Resolution & Refresh Rate modes from Hyprland
        ColumnLayout {
            visible: root.selectedMonitor && !root.selectedMonitor.disabled && root.selectedMonitor.availableModes.length > 0
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: 6

            StyledText { text: "Resolution & Refresh Rate"; font.weight: Font.Medium }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.selectedMonitor ? root.selectedMonitor.availableModes.slice(0, 12) : []
                    delegate: SettingsActionButton {
                        required property string modelData
                        readonly property string cleanMode: modelData.replace("Hz", "")
                        active: root.selectedMonitor && root.selectedMonitor.mode === cleanMode
                        text: modelData
                        onClicked: {
                            if (!root.selectedMonitor) return;
                            const m = cleanMode.match(/^(\d+)x(\d+)@([\d.]+)/);
                            root.updateDraft(root.selectedMonitor.name, {
                                mode: cleanMode,
                                width: m ? parseInt(m[1]) : root.selectedMonitor.width,
                                height: m ? parseInt(m[2]) : root.selectedMonitor.height,
                                refreshRate: m ? parseFloat(m[3]) : root.selectedMonitor.refreshRate
                            });
                        }
                    }
                }
            }
        }
    }

    // ---- Brightness, Keyboard Backlight & Quick Refresh ----
    SettingsSection {
        title: "Brightness & Backlight"

        SettingsSliderRow {
            visible: Brightness.available
            icon: "brightness_6"
            title: "Built-in Display Brightness"
            valueText: Math.round(Brightness.value * 100) + "%"
            from: 0.01
            to: 1.0
            step: 0.05
            value: Brightness.value
            onMoved: v => Brightness.set(v)
        }

        Repeater {
            model: Brightness.externals
            delegate: SettingsSliderRow {
                required property var modelData
                icon: "monitor"
                title: modelData.name
                subtitle: "External DDC/CI"
                valueText: Math.round(modelData.value * 100) + "%"
                from: 0
                to: 1
                step: 0.05
                value: modelData.value
                onMoved: v => Brightness.setExternal(modelData.bus, v)
            }
        }

        SettingsRow {
            visible: Brightness.kbdAvailable
            icon: "keyboard"
            title: "Keyboard Backlight"
            subtitle: Brightness.kbdLevel === 0 ? "Off" : ("Level " + Brightness.kbdLevel + " / " + Brightness.kbdMax)

            SettingsPillGroup {
                Layout.preferredWidth: 190
                Layout.fillWidth: false
                selectedId: String(Brightness.kbdLevel)
                model: Brightness.kbdMax === 2
                    ? [{ id: "0", label: "Off" }, { id: "1", label: "Low" }, { id: "2", label: "High" }]
                    : [{ id: "0", label: "Off" }, { id: "1", label: "On" }]
                onPicked: id => Brightness.setKbd(parseInt(id))
            }
        }

        SettingsRow {
            icon: "speed"
            title: "Laptop Quick Refresh Rate (eDP-1)"
            subtitle: "Instantly switch built-in panel between 60 Hz (battery) and 120 Hz (smooth)"

            SettingsPillGroup {
                Layout.preferredWidth: 160
                Layout.fillWidth: false
                selectedId: String(Brightness.refreshRate)
                model: [{ id: "60", label: "60 Hz" }, { id: "120", label: "120 Hz" }]
                onPicked: id => Brightness.setRefreshRate(parseInt(id))
            }
        }
    }

    // ---- Night Light ----
    SettingsSection {
        visible: NightLight.available
        title: "Night Light"
        description: "Reduces blue light with hyprsunset; schedule checked against wall clock even after suspend"

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: Theme.spaceXs

            SettingsPillGroup {
                selectedId: NightLight.mode
                model: [
                    { id: "auto", label: "Automatic (" + NightLight.scheduleText + ")", icon: "schedule" },
                    { id: "on",   label: "Always On", icon: "nightlight" },
                    { id: "off",  label: "Off", icon: "wb_sunny" }
                ]
                onPicked: id => NightLight.setMode(id)
            }
        }

        SettingsSliderRow {
            icon: "thermostat"
            title: "Color Temperature"
            subtitle: "Lower values are warmer"
            valueText: NightLight.temperature + " K"
            from: NightLight.minTemperature
            to: NightLight.maxTemperature
            step: 100
            value: NightLight.temperature
            onMoved: v => NightLight.setTemperature(Math.round(v))
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: Theme.spaceXs

            StyledText { text: "Schedule From"; font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim }
            TextField {
                id: nlFrom
                Layout.preferredWidth: 86
                implicitHeight: 36
                text: NightLight.warmFrom
                placeholder: "20:00"
            }
            StyledText { text: "Until"; font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim }
            TextField {
                id: nlUntil
                Layout.preferredWidth: 86
                implicitHeight: 36
                text: NightLight.warmUntil
                placeholder: "08:30"
            }
            Item { Layout.fillWidth: true }
            SettingsActionButton {
                variant: "accent"
                text: "Save Schedule"
                onClicked: NightLight.setSchedule(nlFrom.text, nlUntil.text)
            }
        }
    }

    // ---- Virtual Streaming Display (Sunshine) ----
    SettingsSection {
        title: "Virtual Streaming Display"

        SettingsRow {
            icon: "cast"
            highlighted: HyprSettings.sunshineActive
            title: "Headless REMOTE Output (Sunshine / VNC)"
            subtitle: HyprSettings.sunshineActive
                ? "Active · 1920×1080@60 headless display created"
                : "Create a virtual 1080p Hyprland output for game/desktop streaming"

            Toggle {
                checked: HyprSettings.sunshineActive
                onToggled: HyprSettings.toggleSunshineVirtualDisplay()
            }
        }
    }
}
