import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs
import qs.components
import qs.services

// Bluetooth: on/off, device list, and connected device battery levels.
BarButton {
    id: root

    visible: Bt.available
    active: pop.open
    onClicked: button => button === Qt.MiddleButton ? Bt.toggle() : pop.toggle()

    Icon { icon: Bt.icon; color: Bt.connected.length > 0 ? Theme.accent : Theme.text }

    StyledText {
        visible: Bt.enabled && Bt.primaryBattery >= 0
        text: Bt.primaryBattery + "%"
        font.pixelSize: Theme.fontSizeSmall
        font.features: { "tnum": 1 }
    }

    Popup {
        id: pop
        name: "bluetooth"
        anchorItem: root

        property bool discoveredOpen: false
        property string confirmForgetAddr: ""
        readonly property bool shouldScan: pop.open && Bt.enabled && pop.discoveredOpen

        function armConfirmForget(addr: string) {
            pop.confirmForgetAddr = addr;
            forgetResetTimer.restart();
        }

        function clearConfirmForget() {
            pop.confirmForgetAddr = "";
            forgetResetTimer.stop();
        }

        function statusText(dev, batPct: int): string {
            if (dev.state === BluetoothDeviceState.Connecting) return "Connecting…";
            if (dev.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
            if (dev.pairing) return "Pairing…";
            if (dev.connected) return "Connected" + (batPct >= 0 ? ` · ${batPct}%` : "");
            if (dev.paired || dev.bonded) return "Paired";
            return "Click to pair";
        }

        Timer {
            id: forgetResetTimer
            interval: 4000
            onTriggered: pop.confirmForgetAddr = ""
        }

        onOpenChanged: {
            clearConfirmForget();
            discoveredOpen = open && Bt.pairedDevices.length === 0;
        }
        onShouldScanChanged: Bt.setDiscovering(shouldScan)

        Connections {
            target: Bt
            function onEnabledChanged() {
                if (pop.shouldScan) Bt.setDiscovering(true);
            }
            function onPairedDevicesChanged() {
                if (pop.open && Bt.pairedDevices.length === 0)
                    pop.discoveredOpen = true;
            }
        }

        PopupHeader {
            title: "Bluetooth"
            Toggle { checked: Bt.enabled; onToggled: Bt.toggle(); anchors.verticalCenter: parent.verticalCenter }
            AppButton { command: ["cosmic-settings", "bluetooth"] }
        }

        StyledText {
            visible: !Bt.enabled
            text: "Bluetooth is off"
            color: Theme.textDim
        }

        // ---- Paired devices (hidden when none are paired) ----
        StyledText {
            visible: Bt.enabled && Bt.pairedDevices.length > 0
            Layout.fillWidth: true
            text: "Paired devices"
            font.weight: Font.DemiBold
        }

        ListView {
            visible: Bt.enabled && Bt.pairedDevices.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 200)
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: Bt.enabled ? Bt.pairedDevices : []
            delegate: ListItem {
                id: pairedRow
                required property BluetoothDevice modelData
                readonly property bool confirmingForget: pop.confirmForgetAddr !== "" && pop.confirmForgetAddr === modelData.address
                readonly property int batPct: Bt.deviceBattery(modelData)

                width: ListView.view.width
                icon: confirmingForget ? "delete" : Bt.deviceIcon(modelData)
                iconColor: confirmingForget ? Theme.destructive : (highlighted ? Theme.accent : Theme.text)
                text: modelData.name || modelData.address
                highlighted: modelData.connected && !confirmingForget
                subtextColor: confirmingForget ? Theme.destructive : Theme.textDim
                subtext: confirmingForget ? "Right-click again to forget" : pop.statusText(modelData, batPct)

                onClicked: button => {
                    if (button === Qt.RightButton) {
                        if (pairedRow.confirmingForget) {
                            pop.clearConfirmForget();
                            Bt.forget(pairedRow.modelData);
                        } else {
                            pop.armConfirmForget(pairedRow.modelData.address);
                        }
                    } else {
                        if (pairedRow.confirmingForget) {
                            pop.clearConfirmForget();
                            return;
                        }
                        pop.clearConfirmForget();
                        Bt.activate(pairedRow.modelData);
                    }
                }

                RowLayout {
                    visible: pairedRow.batPct >= 0 && !pairedRow.confirmingForget
                    spacing: 2
                    Icon {
                        icon: Bt.batteryIcon(pairedRow.batPct)
                        size: 16
                        color: pairedRow.batPct <= 20 ? Theme.danger : Theme.textDim
                    }
                    StyledText {
                        text: pairedRow.batPct + "%"
                        font.pixelSize: Theme.fontSizeSmall
                        color: pairedRow.batPct <= 20 ? Theme.danger : Theme.textDim
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }

        StyledText {
            visible: Bt.enabled && Bt.pairedDevices.length > 0
            Layout.fillWidth: true
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textDim
            text: "Right-click twice to forget a device."
        }

        Separator {
            visible: Bt.enabled && Bt.pairedDevices.length > 0
        }

        // ---- Discovered / Available devices (collapsible dropdown) ----
        ListItem {
            visible: Bt.enabled
            icon: pop.discoveredOpen ? "expand_less" : "expand_more"
            text: "Available devices"
            subtext: !pop.discoveredOpen ? "Click to scan for new devices"
                   : Bt.discovering ? (Bt.discoveredDevices.length > 0
                       ? `Searching… · ${Bt.discoveredDevices.length} found`
                       : "Searching for devices…")
                   : `${Bt.discoveredDevices.length} found`
            onClicked: {
                pop.clearConfirmForget();
                pop.discoveredOpen = !pop.discoveredOpen;
            }

            Icon {
                visible: pop.discoveredOpen && Bt.discovering
                icon: "radar"
                size: 16
                color: Theme.accent
            }
        }

        ListView {
            visible: Bt.enabled && pop.discoveredOpen && Bt.discoveredDevices.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 220)
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: (Bt.enabled && pop.discoveredOpen) ? Bt.discoveredDevices : []
            delegate: ListItem {
                id: discRow
                required property BluetoothDevice modelData
                width: ListView.view.width
                icon: Bt.deviceIcon(modelData)
                text: modelData.name || modelData.address
                subtext: pop.statusText(modelData, -1)
                onClicked: button => {
                    if (button === Qt.LeftButton) {
                        pop.clearConfirmForget();
                        Bt.activate(discRow.modelData);
                    }
                }
            }
        }
    }
}
