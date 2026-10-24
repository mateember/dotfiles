import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs
import qs.components
import qs.services

// Bluetooth: on/off and device list. Scans for new devices while the popup is open.
BarButton {
    id: root

    visible: Bt.available
    active: pop.open
    onClicked: button => button === Qt.MiddleButton ? Bt.toggle() : pop.toggle()

    Icon { icon: Bt.icon; color: Bt.connected.length > 0 ? Theme.accent : Theme.text }

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
                required property BluetoothDevice modelData
                width: ListView.view.width
                icon: Bt.deviceIcon(modelData)
                text: modelData.name
                highlighted: modelData.connected
                subtext: modelData.state === BluetoothDeviceState.Connecting ? "Connecting…"
                       : modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                       : modelData.pairing ? "Pairing…"
                       : modelData.connected ? ("Connected" + (modelData.batteryAvailable ? ` · ${Math.round(modelData.battery * 100)}%` : ""))
                       : modelData.paired ? "Paired" : "Click to pair"
                onClicked: Bt.activate(modelData)
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
