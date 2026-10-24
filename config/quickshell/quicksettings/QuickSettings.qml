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

    property bool open: false
    function toggle() { root.open = !root.open; }

    // Close the panel and open a bar popup (e.g. "network") on the same monitor.
    function openPopup(name: string, screenName: string) {
        root.open = false;
        Popups.open(name + "@" + screenName);
    }

    IpcHandler {
        target: "quicksettings"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
    }

    // A bar popup opening closes the panel (only one dropdown at a time).
    Connections {
        target: Popups
        function onCurrentChanged() { if (Popups.current !== "") root.open = false; }
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
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
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            readonly property string screenName: screen?.name ?? ""

            HyprlandFocusGrab {
                active: true
                windows: [win]
                onCleared: root.open = false
            }

            Rectangle {
                id: card
                anchors.fill: parent
                implicitHeight: col.implicitHeight + 2 * Theme.spaceS
                radius: Theme.radiusM
                color: Theme.popupBg
                border.color: Theme.popupBorder
                border.width: 1
                clip: true
                focus: true
                Keys.onEscapePressed: root.open = false

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
                                    : Bt.connected.length === 1 ? Bt.connected[0].name
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
                            subtitle: Idle.caffeine ? "Screen stays awake" : "Off"
                            checked: Idle.caffeine
                            onClicked: Idle.toggle()
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
                            icon: "airplanemode_active"
                            title: "Airplane mode"
                            readonly property bool airplane: !Net.wifiEnabled && !Bt.enabled
                            subtitle: airplane ? "On" : "Off"
                            checked: airplane
                            onClicked: {
                                const on = !airplane;
                                Net.setWifiEnabled(!on);
                                if (Bt.available && Bt.enabled === on) Bt.toggle();
                            }
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

                    // ---- media ----
                    MediaCard {}

                    // ---- footer: battery, screenshot, settings, lock, power ----
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
                            icon: "screenshot_region"
                            onClicked: {
                                root.open = false;
                                Quickshell.execDetached(["sh", "-c", "sleep 0.4; hyprshot -m region --clipboard-only"]);
                            }
                        }
                        IconButton {
                            icon: "settings"
                            onClicked: { root.open = false; Quickshell.execDetached(["cosmic-settings"]); }
                        }
                        IconButton {
                            icon: "lock"
                            onClicked: { root.open = false; Quickshell.execDetached(["loginctl", "lock-session"]); }
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
