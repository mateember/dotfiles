import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Quick settings panel (SUPER comma, or the tune icon in the bar), top right of the focused monitor.
// Tiles toggle things directly; the chevron on a tile opens that item's full bar menu.
Scope {
    id: root

    // Open state is shared with the bar button (services/QuickSettingsState.qml).
    readonly property bool open: QuickSettingsState.open
    function setOpen(v: bool) { QuickSettingsState.open = v; }
    function toggle() { QuickSettingsState.toggle(); }

    // Close the panel and open a bar popup (e.g. "network") in the Quick Settings position.
    function openPopup(name: string, screenName: string) {
        root.setOpen(false);
        Popups.openFromQuickSettings(name + "@" + screenName);
    }

    IpcHandler {
        target: "quicksettings"
        function toggle(): void { root.toggle(); }
        function open(): void { root.setOpen(true); }
        function close(): void { root.setOpen(false); }
    }

    // A bar popup opening closes the panel (only one dropdown at a time).
    Connections {
        target: Popups
        function onCurrentChanged() { if (Popups.current !== "") root.setOpen(false); }
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            visible: !QuickSettingsState.asWindow
            color: "transparent"
            anchors.top: true
            anchors.right: true
            margins.top: Theme.panelMargin + Theme.barHeight + Theme.popupGap
            margins.right: Theme.panelMargin
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            implicitWidth: 400
            implicitHeight: Math.min(card.implicitHeight, (screen?.height ?? 900) - margins.top - Theme.spaceL)

            WlrLayershell.namespace: "hcs-quicksettings"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: !QuickSettingsState.asWindow ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            readonly property string screenName: screen?.name ?? ""

            HyprlandFocusGrab {
                active: !QuickSettingsState.asWindow
                windows: [win]
                onCleared: if (!QuickSettingsState.asWindow) root.setOpen(false)
            }

            FloatingWindow {
                id: floatWin
                title: "HCS — Quick Settings"
                visible: QuickSettingsState.asWindow
                readonly property int targetH: Math.max(200, Math.min(Math.ceil(card.implicitHeight), 740))
                implicitWidth: 400
                implicitHeight: targetH
                minimumSize: Qt.size(400, targetH)
                maximumSize: Qt.size(400, targetH)
                color: "transparent"
                onClosed: root.setOpen(false)
            }

            Rectangle {
                id: card
                parent: QuickSettingsState.asWindow ? floatWin.contentItem : win.contentItem
                anchors.fill: parent
                implicitHeight: col.implicitHeight + 2 * Theme.spaceS
                radius: QuickSettingsState.asWindow ? 0 : Theme.radiusM
                color: Theme.popupBg
                border.color: Theme.popupBorder
                border.width: QuickSettingsState.asWindow ? 0 : 1
                clip: true
                focus: true
                Keys.onEscapePressed: root.setOpen(false)

                ColumnLayout {
                    id: col
                    x: Theme.spaceS
                    y: Theme.spaceS
                    width: parent.width - 2 * Theme.spaceS
                    spacing: Theme.spaceXs

                    // ---- toggles ----
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: Theme.spaceXs
                        rowSpacing: Theme.spaceXs

                        QuickTile {
                            icon: Net.wiredConnected ? "lan" : (Net.wifiEnabled ? "wifi" : "wifi_off")
                            title: Net.wiredConnected ? "Ethernet" : "Wi-Fi"
                            subtitle: Net.wiredConnected ? "Connected"
                                    : !Net.wifiEnabled ? "Off"
                                    : Net.activeWifi ? Net.activeWifi.name : "Not connected"
                            checked: Net.wifiEnabled
                            detail: true
                            onClicked: Net.setWifiEnabled(!Net.wifiEnabled)
                            onDetailClicked: root.openPopup("network", win.screenName)
                        }
                        QuickTile {
                            icon: Bt.icon
                            title: "Bluetooth"
                            subtitle: !Bt.enabled ? "Off"
                                    : Bt.connected.length === 1 ? (Bt.connected[0].name + (Bt.primaryBattery >= 0 ? ` · ${Bt.primaryBattery}%` : ""))
                                    : Bt.connected.length > 1 ? Bt.connected.length + " devices"
                                    : "On"
                            checked: Bt.enabled
                            enabled: Bt.available
                            detail: true
                            onClicked: Bt.toggle()
                            onDetailClicked: root.openPopup("bluetooth", win.screenName)
                        }
                        QuickTile {
                            icon: "nightlight"
                            title: "Night light"
                            subtitle: NightLight.mode === "auto"
                                      ? (NightLight.active ? "On (schedule)" : (NightLight.scheduleText ? "Auto " + NightLight.scheduleText : "Auto"))
                                      : NightLight.active ? NightLight.temperature + " K" : "Off"
                            checked: NightLight.active
                            enabled: NightLight.available
                            detail: true
                            onClicked: NightLight.toggle()
                            onDetailClicked: root.openPopup("nightlight", win.screenName)
                        }
                        QuickTile {
                            icon: Notifs.dnd ? "notifications_off" : "notifications"
                            title: "Do not disturb"
                            subtitle: Notifs.dnd ? "On" : (Notifs.history.length > 0 ? Notifs.history.length + " notifications" : "Off")
                            checked: Notifs.dnd
                            detail: true
                            onClicked: Notifs.toggleDnd()
                            onDetailClicked: root.openPopup("notifications", win.screenName)
                        }
                        QuickTile {
                            icon: "coffee"
                            title: "Caffeine"
                            subtitle: Idle.caffeine ? Idle.statusText : "Off"
                            checked: Idle.caffeine
                            detail: true
                            onClicked: Idle.toggle()
                            onDetailClicked: root.openPopup("caffeine", win.screenName)
                        }
                        QuickTile {
                            icon: "keyboard"
                            title: "Keyboard light"
                            subtitle: Brightness.kbdLevel === 0 ? "Off"
                                    : Brightness.kbdMax === 2 ? (Brightness.kbdLevel === 1 ? "Low" : "High")
                                    : "Level " + Brightness.kbdLevel
                            checked: Brightness.kbdLevel > 0
                            enabled: Brightness.kbdAvailable
                            onClicked: Brightness.cycleKbd()
                        }
                        QuickTile {
                            icon: Hypr.layout === "scrolling" ? "view_column" : "view_quilt"
                            title: "Layout"
                            subtitle: Hypr.layout.charAt(0).toUpperCase() + Hypr.layout.slice(1)
                            checked: Hypr.layout === "scrolling"
                            detail: true
                            onClicked: Hypr.toggleLayout()
                            onDetailClicked: root.openPopup("layout", win.screenName)
                        }
                        QuickTile {
                            icon: PowerProfile.icon
                            title: "Power mode"
                            subtitle: PowerProfile.label
                            checked: PowerProfile.mode === "performance"
                            detail: true
                            onClicked: PowerProfile.cycle()
                            onDetailClicked: root.openPopup("battery", win.screenName)
                        }
                    }

                    // ---- sliders ----
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: sliders.implicitHeight + 2 * Theme.spaceXs
                        radius: Theme.radiusM
                        color: Theme.component

                        ColumnLayout {
                            id: sliders
                            anchors.fill: parent
                            anchors.margins: Theme.spaceXs
                            spacing: Theme.spaceXxs

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spaceXs
                                IconButton { icon: Audio.icon; onClicked: Audio.toggleMute() }
                                StyledSlider {
                                    Layout.fillWidth: true
                                    to: Audio.maxVolume
                                    value: Audio.volume
                                    enabled: !Audio.muted
                                    onMoved: v => Audio.setVolume(v)
                                }
                                IconButton { icon: "chevron_right"; onClicked: root.openPopup("volume", win.screenName) }
                            }
                            RowLayout {
                                visible: !!Audio.source
                                Layout.fillWidth: true
                                spacing: Theme.spaceXs
                                IconButton { icon: Audio.micMuted ? "mic_off" : "mic"; onClicked: Audio.toggleMicMute() }
                                StyledSlider {
                                    Layout.fillWidth: true
                                    to: 1
                                    value: Audio.micVolume
                                    enabled: !Audio.micMuted
                                    onMoved: v => Audio.setNodeVolume(Audio.source, v)
                                }
                                Item { implicitWidth: 32 }
                            }
                            RowLayout {
                                visible: Brightness.available
                                Layout.fillWidth: true
                                spacing: Theme.spaceXs
                                IconButton { icon: "brightness_6"; onClicked: root.openPopup("display", win.screenName) }
                                StyledSlider {
                                    Layout.fillWidth: true
                                    value: Brightness.value
                                    onMoved: v => Brightness.set(v)
                                }
                                Item { implicitWidth: 32 }
                            }
                        }
                    }

                    // ---- removable drives (when plugged in) ----
                    Rectangle {
                        visible: Storage.count > 0
                        Layout.fillWidth: true
                        implicitHeight: qsDrivesCol.implicitHeight + 2 * Theme.spaceXs
                        radius: Theme.radiusM
                        color: Theme.component

                        ColumnLayout {
                            id: qsDrivesCol
                            anchors.fill: parent
                            anchors.margins: Theme.spaceXs
                            spacing: 4

                            Repeater {
                                model: Storage.drives
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: Theme.spaceXs

                                    Icon {
                                        icon: modelData.tran === "mmc" ? "sd_card" : "usb"
                                        color: modelData.mounted ? Theme.accent : Theme.textDim
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: modelData.size + (modelData.mounted ? " · Mounted" : " · Unmounted")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.textDim
                                            elide: Text.ElideRight
                                        }
                                    }
                                    IconButton {
                                        visible: modelData.mounted
                                        icon: "folder_open"
                                        onClicked: {
                                            root.setOpen(false);
                                            Storage.openInFiles(modelData.mountpoint);
                                        }
                                    }
                                    IconButton {
                                        icon: "eject"
                                        onClicked: Storage.eject(modelData.path, modelData.diskPath)
                                    }
                                }
                            }
                        }
                    }

                    // ---- media ----
                    MediaCard {}

                    // ---- footer: battery, capture, record, settings, lock, power ----
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spaceXxxs
                        spacing: Theme.spaceXxs

                        Icon {
                            visible: Battery.available
                            icon: Battery.icon
                            filled: true
                            color: Battery.charging ? Theme.accent : Theme.text
                        }
                        StyledText {
                            visible: Battery.available
                            Layout.fillWidth: true
                            text: Math.round(Battery.percent * 100) + "% · " + Battery.status
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textDim
                            elide: Text.ElideRight
                        }
                        Item { visible: !Battery.available; Layout.fillWidth: true }

                        IconButton {
                            icon: "photo_camera"
                            onClicked: {
                                root.setOpen(false);
                                Recorder.openOverlayFromQuickSettings("shot");
                            }
                        }
                        IconButton {
                            icon: Recorder.recording ? "stop_circle" : "videocam"
                            onClicked: {
                                root.setOpen(false);
                                if (Recorder.recording) Recorder.stopRecording();
                                else Recorder.openOverlayFromQuickSettings("record");
                            }
                        }
                        IconButton {
                            icon: "settings"
                            onClicked: { root.setOpen(false); Quickshell.execDetached(["cosmic-settings"]); }
                        }
                        IconButton {
                            icon: "lock"
                            onClicked: { root.setOpen(false); Quickshell.execDetached(["loginctl", "lock-session"]); }
                        }
                        IconButton {
                            icon: "power_settings_new"
                            onClicked: root.openPopup("power", win.screenName)
                        }
                    }
                }
            }
        }
    }
}
