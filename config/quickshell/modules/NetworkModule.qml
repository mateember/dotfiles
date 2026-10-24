import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs
import qs.components
import qs.services

// Wi-Fi / Ethernet via NetworkManager. Click a network to connect; secured unknown
// networks ask for the password inline.
BarButton {
    id: root

    active: pop.open
    onClicked: pop.toggle()

    Icon { icon: Net.icon; filled: true }

    Popup {
        id: pop
        name: "network"
        anchorItem: root
        contentWidth: 340

        property var pending: null      // network waiting for a password
        property string error: ""

        onOpenChanged: {
            Net.scanning = open;
            if (!open) { pending = null; error = ""; }
        }

        function activate(n) {
            pop.error = "";
            if (n.connected) n.disconnect();
            else if (n.known || !Net.isSecure(n)) n.connect();
            else { pop.pending = n; psk.text = ""; psk.focusInput(); }
        }

        PopupHeader {
            title: "Wi-Fi"
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

        StyledText {
            visible: !Net.wifiEnabled
            text: Networking.wifiHardwareEnabled ? "Wi-Fi is off" : "Wi-Fi is blocked by a hardware switch"
            color: Theme.textDim
        }

        ListView {
            id: list
            visible: Net.wifiEnabled
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 360)
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
