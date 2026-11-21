import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs
import qs.components
import qs.services
import "../components"

ColumnLayout {
    id: root

    spacing: Theme.spaceM

    property var pendingWifi: null
    property string wifiError: ""
    property bool showHiddenForm: false
    property bool showSavedWifi: false
    property string confirmForgetUuid: ""

    Component.onCompleted: {
        Net.scanning = true;
        Net.refreshVpns();
        Net.refreshDetails();
        SystemManager.refreshTailscale();
    }
    Component.onDestruction: {
        Net.scanning = false;
    }

    function activateWifi(n) {
        root.wifiError = "";
        if (n.connected) n.disconnect();
        else if (n.known || !Net.isSecure(n)) n.connect();
        else { root.pendingWifi = n; }
    }

    SettingsPageHeader {
        icon: "wifi"
        title: "Network & VPN"
        subtitle: "Manage Wi-Fi networks, Ethernet, VPN profiles, and Tailscale exit nodes"

        SettingsActionButton {
            icon: "refresh"
            text: "Refresh"
            onClicked: {
                Net.refreshVpns();
                Net.refreshDetails();
                SystemManager.refreshTailscale();
            }
        }
        SettingsActionButton {
            icon: "tune"
            text: "Advanced"
            onClicked: Net.openConnectionEditor()
        }
    }

    // ---- Active Connection & Details ----
    SettingsSection {
        title: "Connection Status"

        SettingsRow {
            visible: Net.wiredDevice !== null
            icon: "lan"
            iconFilled: Net.wiredConnected
            highlighted: Net.wiredConnected
            title: "Ethernet"
            subtitle: Net.wiredConnected
                ? ("Connected" + (Net.activeDetails.speed ? (" · " + Net.activeDetails.speed) : ""))
                : "Cable unplugged"
        }

        SettingsRow {
            icon: Net.wifiEnabled ? "wifi" : "wifi_off"
            iconFilled: Net.wifiEnabled
            highlighted: Net.activeWifi !== null
            title: "Wi-Fi"
            subtitle: !Networking.wifiHardwareEnabled ? "Disabled by hardware switch"
                    : !Net.wifiEnabled ? "Turned off"
                    : Net.activeWifi ? ("Connected to " + Net.activeWifi.name + " (" + Math.round(Net.activeWifi.signalStrength * 100) + "%)")
                    : "Not connected"

            Toggle {
                checked: Net.wifiEnabled
                enabled: Networking.wifiHardwareEnabled
                onToggled: Net.setWifiEnabled(!Net.wifiEnabled)
            }
        }

        // Live IP / Gateway / DNS / MAC readout
        ColumnLayout {
            visible: Boolean(Net.activeDetails.device)
            Layout.fillWidth: true
            Layout.leftMargin: Theme.spaceXs
            Layout.rightMargin: Theme.spaceXs
            Layout.topMargin: 4
            Layout.bottomMargin: 6
            spacing: 4

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                columns: 2
                columnSpacing: Theme.spaceM
                rowSpacing: 4

                StyledText { text: "Interface"; font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim }
                StyledText { text: Net.activeDetails.device || "—"; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.monoFamily }

                StyledText { visible: Boolean(Net.activeDetails.ip4); text: "IPv4 Address"; font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim }
                StyledText { visible: Boolean(Net.activeDetails.ip4); text: Net.activeDetails.ip4 || ""; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.monoFamily }

                StyledText { visible: Boolean(Net.activeDetails.gateway); text: "Gateway"; font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim }
                StyledText { visible: Boolean(Net.activeDetails.gateway); text: Net.activeDetails.gateway || ""; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.monoFamily }

                StyledText { visible: Boolean(Net.activeDetails.dnsText); text: "DNS"; font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim }
                StyledText { visible: Boolean(Net.activeDetails.dnsText); text: Net.activeDetails.dnsText || ""; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.monoFamily; Layout.fillWidth: true; elide: Text.ElideRight }

                StyledText { visible: Boolean(Net.activeDetails.mac); text: "MAC Address"; font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim }
                StyledText { visible: Boolean(Net.activeDetails.mac); text: Net.activeDetails.mac || ""; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.monoFamily }
            }
        }
    }

    // ---- Wi-Fi Networks ----
    SettingsSection {
        visible: Net.wifiEnabled
        title: "Available Wi-Fi Networks"
        description: "Tap a network to connect or disconnect"

        Repeater {
            model: Net.wifiEnabled ? Net.wifiNetworks.slice(0, 18) : []
            delegate: ColumnLayout {
                id: wifiEntry
                required property WifiNetwork modelData
                Layout.fillWidth: true
                spacing: 6

                SettingsRow {
                    icon: Net.strengthIcon(wifiEntry.modelData.signalStrength)
                    iconFilled: true
                    highlighted: wifiEntry.modelData.connected
                    clickable: true
                    title: wifiEntry.modelData.name || "(Hidden network)"
                    subtitle: wifiEntry.modelData.stateChanging ? "Connecting…"
                            : wifiEntry.modelData.connected ? "Connected"
                            : wifiEntry.modelData.known ? "Saved" : "Available"
                    onClicked: root.activateWifi(wifiEntry.modelData)

                    Icon {
                        visible: Net.isSecure(wifiEntry.modelData)
                        icon: "lock"
                        size: 16
                        color: Theme.textDim
                    }

                    SettingsActionButton {
                        visible: wifiEntry.modelData.connected
                        text: "Disconnect"
                        onClicked: wifiEntry.modelData.disconnect()
                    }
                }

                // Inline Password Input
                RowLayout {
                    visible: root.pendingWifi === wifiEntry.modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.spaceM
                    Layout.rightMargin: Theme.spaceXs
                    Layout.bottomMargin: 6
                    spacing: Theme.spaceXxs

                    TextField {
                        id: pskField
                        Layout.fillWidth: true
                        implicitHeight: 38
                        placeholder: "Wi-Fi password for " + wifiEntry.modelData.name
                        echoMode: TextInput.Password
                        onVisibleChanged: if (visible) { text = ""; focusInput(); }
                        onAccepted: {
                            wifiEntry.modelData.connectWithPsk(text);
                            root.pendingWifi = null;
                        }
                    }
                    SettingsActionButton {
                        variant: "accent"
                        text: "Connect"
                        onClicked: {
                            wifiEntry.modelData.connectWithPsk(pskField.text);
                            root.pendingWifi = null;
                        }
                    }
                    SettingsActionButton {
                        text: "Cancel"
                        onClicked: root.pendingWifi = null
                    }
                }

                Connections {
                    target: wifiEntry.modelData
                    function onConnectionFailed(reason) {
                        root.wifiError = "Failed to connect to " + wifiEntry.modelData.name + ": " + ConnectionFailReason.toString(reason);
                    }
                }
            }
        }

        StyledText {
            visible: root.wifiError !== ""
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            text: root.wifiError
            color: Theme.destructive
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }

        // Hidden Network & Saved Networks expandable actions
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: Theme.spaceXxs

            SettingsActionButton {
                icon: "wifi_find"
                text: "Join Hidden Network"
                active: root.showHiddenForm
                onClicked: root.showHiddenForm = !root.showHiddenForm
            }

            SettingsActionButton {
                icon: "bookmarks"
                text: "Saved Networks (" + Net.savedWifi.length + ")"
                active: root.showSavedWifi
                onClicked: {
                    root.showSavedWifi = !root.showSavedWifi;
                    if (root.showSavedWifi) Net.refreshDetails();
                }
            }
        }

        // Hidden network form
        ColumnLayout {
            visible: root.showHiddenForm
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: Theme.spaceXxs

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXxs
                TextField {
                    id: hiddenSsid
                    Layout.fillWidth: true
                    implicitHeight: 38
                    placeholder: "Network Name (SSID)"
                }
                TextField {
                    id: hiddenPass
                    Layout.fillWidth: true
                    implicitHeight: 38
                    placeholder: "Password (optional)"
                    echoMode: TextInput.Password
                }
                SettingsActionButton {
                    variant: "accent"
                    text: Net.hiddenBusy ? "Joining…" : "Join"
                    buttonEnabled: !Net.hiddenBusy && hiddenSsid.text.trim() !== ""
                    onClicked: Net.connectHiddenWifi(hiddenSsid.text, hiddenPass.text)
                }
            }

            StyledText {
                visible: Net.hiddenError !== ""
                Layout.fillWidth: true
                text: Net.hiddenError
                color: Theme.destructive
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }

        // Saved Wi-Fi list
        ColumnLayout {
            visible: root.showSavedWifi
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: Net.savedWifi
                delegate: SettingsRow {
                    id: savedRow
                    required property var modelData
                    readonly property bool confirming: root.confirmForgetUuid === modelData.uuid
                    icon: "wifi"
                    title: modelData.name
                    subtitle: (modelData.active ? "Active · " : "") + (modelData.autoconnect ? "Auto-connect on" : "Manual connect")

                    Toggle {
                        checked: savedRow.modelData.autoconnect
                        onToggled: Net.setConnectionAutoconnect(savedRow.modelData.uuid, !savedRow.modelData.autoconnect)
                    }

                    SettingsActionButton {
                        variant: savedRow.confirming ? "danger" : "subtle"
                        icon: "delete"
                        text: savedRow.confirming ? "Confirm" : "Forget"
                        onClicked: {
                            if (savedRow.confirming) {
                                root.confirmForgetUuid = "";
                                Net.forgetSavedConnection(savedRow.modelData.uuid);
                            } else {
                                root.confirmForgetUuid = savedRow.modelData.uuid;
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- VPN & WireGuard ----
    SettingsSection {
        title: "VPN & WireGuard"
        description: "NetworkManager VPN tunnels"

        SettingsRow {
            visible: Net.vpns.length === 0
            icon: "vpn_key"
            title: "No VPN profiles configured"
            subtitle: "Create a WireGuard, OpenVPN, or IPsec profile"

            SettingsActionButton {
                variant: "accent"
                icon: "add"
                text: "Add VPN"
                onClicked: Net.createVpn()
            }
        }

        Repeater {
            model: Net.vpns
            delegate: ColumnLayout {
                id: vpnRow
                required property var modelData
                readonly property bool busy: Net.vpnBusyUuid === modelData.uuid || modelData.connecting
                Layout.fillWidth: true
                spacing: 6

                SettingsRow {
                    icon: vpnRow.modelData.connected ? "vpn_lock" : "vpn_key"
                    iconFilled: vpnRow.modelData.connected
                    highlighted: vpnRow.modelData.connected
                    title: vpnRow.modelData.name
                    subtitle: vpnRow.busy ? (vpnRow.modelData.connected ? "Disconnecting…" : "Connecting…")
                            : vpnRow.modelData.connected ? ("Connected" + (vpnRow.modelData.server ? (" · " + vpnRow.modelData.server) : ""))
                            : [vpnRow.modelData.server, vpnRow.modelData.kindLabel].filter(Boolean).join(" · ")

                    IconButton {
                        icon: "edit"
                        implicitWidth: 36
                        implicitHeight: 36
                        onClicked: Net.editVpn(vpnRow.modelData.uuid)
                    }
                    Toggle {
                        checked: vpnRow.modelData.connected
                        enabled: !vpnRow.busy
                        onToggled: Net.toggleVpn(vpnRow.modelData)
                    }
                }

                RowLayout {
                    visible: Net.vpnSecretUuid === vpnRow.modelData.uuid
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.spaceM
                    Layout.rightMargin: Theme.spaceXs
                    spacing: Theme.spaceXxs

                    TextField {
                        id: vpnPwField
                        Layout.fillWidth: true
                        implicitHeight: 38
                        placeholder: "VPN password"
                        echoMode: TextInput.Password
                        onAccepted: {
                            const pw = text;
                            text = "";
                            Net.connectVpn(vpnRow.modelData.uuid, pw);
                        }
                    }
                    SettingsActionButton {
                        variant: "accent"
                        text: "Connect"
                        onClicked: {
                            const pw = vpnPwField.text;
                            vpnPwField.text = "";
                            Net.connectVpn(vpnRow.modelData.uuid, pw);
                        }
                    }
                }
            }
        }

        RowLayout {
            visible: Net.vpns.length > 0
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: Theme.spaceXxs

            SettingsActionButton {
                icon: "add"
                text: "Add VPN Profile"
                onClicked: Net.createVpn()
            }
        }

        StyledText {
            visible: Net.vpnError !== ""
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            text: Net.vpnError
            color: Theme.destructive
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }
    }

    // ---- Tailscale Exit Nodes ----
    SettingsSection {
        visible: SystemManager.tailscaleAvailable
        title: "Tailscale"
        description: SystemManager.tailscaleRunning
            ? ("Connected as " + SystemManager.tailscaleSelfName + (SystemManager.tailscaleSelfIp ? (" · " + SystemManager.tailscaleSelfIp) : ""))
            : "Tailscale daemon is installed but not running"

        SettingsRow {
            icon: "hub"
            highlighted: SystemManager.tailscaleActiveExitId !== ""
            title: SystemManager.tailscaleActiveExitName !== ""
                ? ("Exit Node: " + SystemManager.tailscaleActiveExitName)
                : "Direct Routing (No Exit Node)"
            subtitle: SystemManager.tailscaleBusy ? "Updating Tailscale exit node…"
                    : (SystemManager.tailscaleExitNodes.length > 0
                        ? (SystemManager.tailscaleExitNodes.length + " exit nodes advertised on your tailnet")
                        : "No exit nodes advertised on your tailnet")

            SettingsActionButton {
                visible: SystemManager.tailscaleActiveExitId !== ""
                variant: "danger"
                text: "Clear Exit Node"
                buttonEnabled: !SystemManager.tailscaleBusy
                onClicked: SystemManager.setTailscaleExitNode("")
            }
        }

        Repeater {
            model: SystemManager.tailscaleExitNodes
            delegate: SettingsRow {
                required property var modelData
                icon: modelData.active ? "public" : "dns"
                highlighted: modelData.active
                clickable: !SystemManager.tailscaleBusy && modelData.online
                rowEnabled: modelData.online
                title: modelData.name
                subtitle: (modelData.online ? "Online" : "Offline") + (modelData.ip ? (" · " + modelData.ip) : "")
                onClicked: SystemManager.setTailscaleExitNode(modelData.active ? "" : (modelData.dnsName || modelData.name))

                SettingsActionButton {
                    variant: modelData.active ? "accent" : "subtle"
                    text: modelData.active ? "Active" : "Use Node"
                    buttonEnabled: !SystemManager.tailscaleBusy && modelData.online
                    onClicked: SystemManager.setTailscaleExitNode(modelData.active ? "" : (modelData.dnsName || modelData.name))
                }
            }
        }

        StyledText {
            visible: SystemManager.tailscaleError !== ""
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            text: SystemManager.tailscaleError
            color: Theme.destructive
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }
    }
}
