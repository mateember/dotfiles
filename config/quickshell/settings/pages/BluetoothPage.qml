import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs
import qs.components
import qs.services
import "../components"

ColumnLayout {
    id: root

    spacing: Theme.spaceM

    property string confirmForgetAddr: ""
    property bool scanning: true

    Component.onCompleted: {
        if (Bt.enabled && root.scanning) Bt.setDiscovering(true);
    }
    Component.onDestruction: {
        Bt.setDiscovering(false);
    }

    Connections {
        target: Bt
        function onEnabledChanged() {
            if (Bt.enabled && root.scanning) Bt.setDiscovering(true);
        }
    }

    function statusText(dev, batPct: int): string {
        if (dev.state === BluetoothDeviceState.Connecting) return "Connecting…";
        if (dev.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
        if (dev.pairing) return "Pairing…";
        if (dev.connected) return "Connected" + (batPct >= 0 ? (" · Battery " + batPct + "%") : "");
        if (dev.paired || dev.bonded) return "Paired" + (dev.trusted ? " · Trusted" : "");
        return "Available to pair";
    }

    SettingsPageHeader {
        icon: "bluetooth"
        title: "Bluetooth"
        subtitle: Bt.available ? ("Adapter: " + Bt.adapterName) : "No Bluetooth adapter detected"

        SettingsActionButton {
            visible: Bt.available && Bt.enabled
            icon: Bt.discovering ? "radar" : "search"
            text: Bt.discovering ? "Scanning…" : "Scan"
            active: Bt.discovering
            onClicked: {
                root.scanning = !Bt.discovering;
                Bt.setDiscovering(root.scanning);
            }
        }
    }

    // ---- Adapter Controls ----
    SettingsSection {
        title: "Adapter"

        SettingsRow {
            icon: Bt.icon
            highlighted: Bt.enabled
            title: "Bluetooth"
            subtitle: !Bt.available ? "Unavailable"
                    : !Bt.enabled ? "Off"
                    : Bt.connected.length > 0 ? (Bt.connected.length + " connected") : "On · Ready"

            Toggle {
                checked: Bt.enabled
                enabled: Bt.available
                onToggled: Bt.toggle()
            }
        }

        SettingsRow {
            visible: Bt.available && Bt.enabled
            icon: "visibility"
            title: "Discoverable to Nearby Devices"
            subtitle: Bt.discoverable ? "Visible as " + Bt.adapterName : "Hidden from new pairing requests"

            Toggle {
                checked: Bt.discoverable
                onToggled: Bt.setDiscoverable(!Bt.discoverable)
            }
        }
    }

    // ---- Paired Devices ----
    SettingsSection {
        visible: Bt.available && Bt.enabled
        title: "Paired Devices"
        description: Bt.pairedDevices.length > 0 ? "Tap to connect/disconnect, or manage trust and removal" : "No paired devices yet"

        Repeater {
            model: Bt.pairedDevices
            delegate: SettingsRow {
                id: devRow
                required property BluetoothDevice modelData
                readonly property int batPct: Bt.deviceBattery(modelData)
                readonly property bool confirming: root.confirmForgetAddr === modelData.address

                icon: Bt.deviceIcon(modelData)
                highlighted: modelData.connected
                clickable: true
                title: modelData.name || modelData.address
                subtitle: root.statusText(modelData, batPct) + " · " + modelData.address
                onClicked: {
                    root.confirmForgetAddr = "";
                    Bt.activate(devRow.modelData);
                }

                SettingsActionButton {
                    variant: devRow.modelData.connected ? "accent" : "subtle"
                    text: devRow.modelData.connected ? "Disconnect" : "Connect"
                    onClicked: Bt.activate(devRow.modelData)
                }

                IconButton {
                    icon: devRow.modelData.trusted ? "verified_user" : "shield"
                    highlighted: devRow.modelData.trusted
                    implicitWidth: 36
                    implicitHeight: 36
                    onClicked: Bt.setTrusted(devRow.modelData, !devRow.modelData.trusted)
                }

                SettingsActionButton {
                    variant: devRow.confirming ? "danger" : "subtle"
                    icon: "delete"
                    text: devRow.confirming ? "Confirm" : ""
                    onClicked: {
                        if (devRow.confirming) {
                            root.confirmForgetAddr = "";
                            Bt.forget(devRow.modelData);
                        } else {
                            root.confirmForgetAddr = devRow.modelData.address;
                        }
                    }
                }
            }
        }
    }

    // ---- Nearby Available Devices ----
    SettingsSection {
        visible: Bt.available && Bt.enabled
        title: "Nearby Devices"
        description: Bt.discovering
            ? ("Scanning for nearby devices… (" + Bt.discoveredDevices.length + " found)")
            : "Press Scan above to search for new Bluetooth devices"

        StyledText {
            visible: Bt.discoveredDevices.length === 0
            Layout.fillWidth: true
            Layout.margins: Theme.spaceS
            horizontalAlignment: Text.AlignHCenter
            color: Theme.textDim
            text: Bt.discovering ? "Looking for nearby Bluetooth devices…" : "No new devices discovered"
        }

        Repeater {
            model: Bt.discoveredDevices
            delegate: SettingsRow {
                id: nearRow
                required property BluetoothDevice modelData
                icon: Bt.deviceIcon(modelData)
                clickable: true
                title: modelData.name || modelData.address
                subtitle: root.statusText(modelData, -1) + " · " + modelData.address
                onClicked: Bt.activate(nearRow.modelData)

                SettingsActionButton {
                    variant: "accent"
                    text: nearRow.modelData.pairing ? "Pairing…" : "Pair"
                    buttonEnabled: !nearRow.modelData.pairing
                    onClicked: Bt.activate(nearRow.modelData)
                }
            }
        }
    }
}
