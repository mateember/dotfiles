import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Laptop battery (UPower). Hidden on machines without one.
BarButton {
    id: root

    visible: Battery.available
    active: pop.open
    onClicked: pop.toggle()

    Icon {
        icon: Battery.icon
        filled: true
        color: Battery.percent <= 0.1 && !Battery.charging ? Theme.destructive
             : Battery.percent <= 0.2 && !Battery.charging ? Theme.warning
             : Theme.text
    }

    Popup {
        id: pop
        name: "battery"
        anchorItem: root
        contentWidth: 280

        PopupHeader {
            title: "Battery"
            AppButton { command: ["cosmic-settings", "power"] }
        }

        RowLayout {
            spacing: Theme.spaceS
            Icon { icon: Battery.icon; filled: true; size: 40; color: Theme.accent }
            ColumnLayout {
                spacing: 0
                StyledText {
                    text: Math.round(Battery.percent * 100) + "%"
                    font.pixelSize: Theme.fontSizeTitle
                    font.weight: Font.Bold
                }
                StyledText { text: Battery.status; color: Theme.textDim }
            }
        }

        StyledText {
            visible: Battery.device?.healthSupported ?? false
            text: "Battery health: " + Math.round(Battery.device?.healthPercentage ?? 0) + "%"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textDim
        }
    }
}
