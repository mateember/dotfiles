import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs
import qs.components
import qs.services

// Wi-Fi, Ethernet & VPN manager via NetworkManager.
// Click a network or VPN to connect/disconnect; secured unknown Wi-Fi networks or
// prompt-only VPNs ask for the password inline.
BarButton {
    id: root

    active: pop.open
    onClicked: pop.toggle()

    Row {
        spacing: 3
        Icon {
            icon: Net.icon
            filled: true
            anchors.verticalCenter: parent.verticalCenter
        }
        Icon {
            visible: Net.vpnConnected
            icon: "vpn_key"
            size: 14
            color: Theme.accent
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Popup {
        id: pop
        name: "network"
        anchorItem: root
        contentWidth: 350

        property var pending: null      // Wi-Fi network waiting for a password
        property string error: ""

        onOpenChanged: {
            Net.scanning = open;
            if (open) {
                Net.refreshVpns();
            } else {
                pending = null;
                error = "";
                Net.vpnError = "";
                Net.vpnSecretUuid = "";
            }
        }

        function activate(n) {
            pop.error = "";
            if (n.connected) n.disconnect();
            else if (n.known || !Net.isSecure(n)) n.connect();
            else { pop.pending = n; psk.text = ""; psk.focusInput(); }
        }

        PopupHeader {
            title: "Network"
            Toggle {
                checked: Net.wifiEnabled
                enabled: Networking.wifiHardwareEnabled
                onToggled: Net.setWifiEnabled(!Net.wifiEnabled)
                anchors.verticalCenter: parent.verticalCenter
            }
            AppButton { command: ["cosmic-settings", "wireless"] }
        }

        ListItem {
            visible: Net.wiredDevice !== null
            icon: "lan"
            text: "Ethernet"
            subtext: Net.wiredConnected ? "Connected" : "Disconnected"
            highlighted: Net.wiredConnected
            enabled: false
        }

        // ---- VPN Manager ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            Icon {
                icon: Net.vpnConnected ? "vpn_lock" : "vpn_key"
                size: 18
                color: Net.vpnConnected ? Theme.accent : Theme.textDim
            }
            StyledText {
                Layout.fillWidth: true
                text: Net.vpnConnected ? ("VPN · " + Net.activeVpn.name) : "VPN"
                font.weight: Font.DemiBold
                color: Net.vpnConnected ? Theme.accent : Theme.text
                elide: Text.ElideRight
            }
            IconButton {
                icon: "add_circle"
                implicitWidth: 28
                implicitHeight: 28
                iconSize: 18
                onClicked: {
                    Popups.close();
                    Net.createVpn();
                }
            }
            IconButton {
                icon: "tune"
                implicitWidth: 28
                implicitHeight: 28
                iconSize: 18
                onClicked: {
                    Popups.close();
                    Net.openConnectionEditor();
                }
            }
        }

        StyledText {
            visible: Net.vpns.length === 0
            Layout.fillWidth: true
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textDim
            text: "No VPN profiles configured — click + to add one."
        }

        ColumnLayout {
            visible: Net.vpns.length > 0
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: Net.vpns
                delegate: ColumnLayout {
                    id: vpnEntry
                    required property var modelData
                    readonly property bool busy: Net.vpnBusyUuid === modelData.uuid || modelData.connecting
                    readonly property string subtitleText: {
                        if (busy) return modelData.connected ? "Disconnecting…" : "Connecting…";
                        if (modelData.connected)
                            return "Connected" + (modelData.server ? " · " + modelData.server : "");
                        return [modelData.server, modelData.kindLabel].filter(Boolean).join(" · ");
                    }

                    Layout.fillWidth: true
                    spacing: Theme.spaceXxs

                    ListItem {
                        icon: vpnEntry.modelData.connected ? "vpn_lock" : "vpn_key"
                        iconFilled: vpnEntry.modelData.connected
                        text: vpnEntry.modelData.name
                        subtext: vpnEntry.subtitleText
                        highlighted: vpnEntry.modelData.connected
                        enabled: !vpnEntry.busy
                        onClicked: button => {
                            if (button === Qt.RightButton) {
                                Popups.close();
                                Net.editVpn(vpnEntry.modelData.uuid);
                            } else {
                                Net.toggleVpn(vpnEntry.modelData);
                            }
                        }

                        IconButton {
                            icon: "settings"
                            implicitWidth: 28
                            implicitHeight: 28
                            iconSize: 16
                            onClicked: {
                                Popups.close();
                                Net.editVpn(vpnEntry.modelData.uuid);
                            }
                        }
                        Toggle {
                            checked: vpnEntry.modelData.connected
                            enabled: !vpnEntry.busy
                            onToggled: Net.toggleVpn(vpnEntry.modelData)
                        }
                    }

                    // Inline password prompt if the VPN requires interactive secrets
                    RowLayout {
                        visible: Net.vpnSecretUuid === vpnEntry.modelData.uuid
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.spaceXs
                        Layout.rightMargin: Theme.spaceXs
                        spacing: Theme.spaceXxs

                        TextField {
                            id: vpnPsk
                            Layout.fillWidth: true
                            placeholder: "VPN password"
                            echoMode: TextInput.Password
                            onVisibleChanged: if (visible) { text = ""; focusInput(); }
                            onAccepted: vpnConnectBtn.clicked()
                        }
                        IconButton {
                            id: vpnConnectBtn
                            icon: "arrow_forward"
                            highlighted: true
                            onClicked: {
                                const pw = vpnPsk.text;
                                vpnPsk.text = "";
                                Net.connectVpn(vpnEntry.modelData.uuid, pw);
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            visible: Net.vpnError !== ""
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Net.vpnError
            color: Theme.destructive
            font.pixelSize: Theme.fontSizeSmall
        }

        Separator {}

        // ---- Wi-Fi ----
        StyledText {
            text: "Wi-Fi"
            font.weight: Font.DemiBold
        }

        StyledText {
            visible: !Net.wifiEnabled
            text: Networking.wifiHardwareEnabled ? "Wi-Fi is off" : "Wi-Fi is blocked by a hardware switch"
            color: Theme.textDim
        }

        ListView {
            id: list
            visible: Net.wifiEnabled
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 280)
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: Net.wifiEnabled ? Net.wifiNetworks : []

            delegate: ColumnLayout {
                id: entry
                required property WifiNetwork modelData
                width: ListView.view.width
                spacing: Theme.spaceXxs

                ListItem {
                    icon: Net.strengthIcon(entry.modelData.signalStrength)
                    iconFilled: true
                    text: entry.modelData.name
                    highlighted: entry.modelData.connected
                    subtext: entry.modelData.stateChanging ? "Connecting…"
                           : entry.modelData.connected ? "Connected"
                           : entry.modelData.known ? "Saved" : ""
                    onClicked: button => button === Qt.RightButton && entry.modelData.known
                               ? entry.modelData.forget() : pop.activate(entry.modelData)

                    Icon {
                        visible: Net.isSecure(entry.modelData)
                        icon: "lock"
                        size: 14
                        color: Theme.textDim
                    }
                }

                // Inline password prompt for this network.
                RowLayout {
                    visible: pop.pending === entry.modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.spaceXs
                    Layout.rightMargin: Theme.spaceXs
                    spacing: Theme.spaceXxs
                    TextField {
                        id: psk
                        Layout.fillWidth: true
                        placeholder: "Password"
                        echoMode: TextInput.Password
                        onAccepted: connectBtn.clicked()
                    }
                    IconButton {
                        id: connectBtn
                        icon: "arrow_forward"
                        highlighted: true
                        onClicked: {
                            entry.modelData.connectWithPsk(psk.text);
                            pop.pending = null;
                        }
                    }
                }

                Connections {
                    target: entry.modelData
                    function onConnectionFailed(reason) {
                        pop.error = `Couldn't connect to ${entry.modelData.name}: ${ConnectionFailReason.toString(reason)}`;
                    }
                }
            }
        }

        StyledText {
            visible: pop.error !== ""
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: pop.error
            color: Theme.destructive
            font.pixelSize: Theme.fontSizeSmall
        }

        StyledText {
            visible: Net.wifiEnabled
            Layout.fillWidth: true
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textDim
            text: "Right click a saved network to forget it."
        }

        Separator {}
        ListItem {
            icon: "settings_ethernet"
            text: "Network settings"
            subtext: "Wired, VPN and advanced connection settings"
            onClicked: { Popups.close(); Quickshell.execDetached(["cosmic-settings", "network"]); }
        }
    }
}
