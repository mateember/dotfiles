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

        onOpenChanged: Bt.setDiscovering(open)
        Connections {
            target: Bt
            function onEnabledChanged() { if (pop.open) Bt.setDiscovering(true); }
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

        ListView {
            visible: Bt.enabled
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 360)
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            // Unnamed devices advertise their MAC as the name; hide those unless already paired.
            model: Bt.enabled ? Bt.devices.filter(d => d.paired || d.connected || !/^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$/i.test(d.name)) : []
            delegate: ListItem {
                id: devRow
                required property BluetoothDevice modelData
                readonly property int batPct: Bt.deviceBattery(modelData)
                width: ListView.view.width
                icon: Bt.deviceIcon(modelData)
                text: modelData.name
                highlighted: modelData.connected
                subtext: modelData.state === BluetoothDeviceState.Connecting ? "Connecting…"
                       : modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                       : modelData.pairing ? "Pairing…"
                       : modelData.connected ? ("Connected" + (batPct >= 0 ? ` · ${batPct}%` : ""))
                       : modelData.paired ? "Paired" : "Click to pair"
                onClicked: Bt.activate(modelData)

                RowLayout {
                    visible: devRow.batPct >= 0
                    spacing: 2
                    Icon {
                        icon: Bt.batteryIcon(devRow.batPct)
                        size: 16
                        color: devRow.batPct <= 20 ? Theme.danger : Theme.textDim
                    }
                    StyledText {
                        text: devRow.batPct + "%"
                        font.pixelSize: Theme.fontSizeSmall
                        color: devRow.batPct <= 20 ? Theme.danger : Theme.textDim
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }

        RowLayout {
            visible: Bt.enabled
            Layout.fillWidth: true
            Icon { icon: "radar"; color: Theme.textDim; size: 16 }
            StyledText {
                Layout.fillWidth: true
                text: Bt.discovering ? "Searching for devices…" : "Not searching"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textDim
            }
        }
    }
}
