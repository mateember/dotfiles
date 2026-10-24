import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Night light status + control (hyprsunset). Amber moon when the screen is warmed.
// Left click: popup. Right/middle click: toggle.
BarButton {
    id: root

    visible: NightLight.available
    active: pop.open
    onClicked: button => button === Qt.LeftButton ? pop.toggle() : NightLight.toggle()

    Icon {
        icon: "nightlight"
        filled: NightLight.active
        color: NightLight.active ? Theme.accent : Theme.text
    }

    Popup {
        id: pop
        name: "nightlight"
        anchorItem: root
        contentWidth: 300

        PopupHeader {
            title: "Night light"
            Toggle {
                checked: NightLight.active
                onToggled: NightLight.toggle()
                anchors.verticalCenter: parent.verticalCenter
            }
            AppButton { command: ["cosmic-settings", "displays"] }
        }

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.textDim
            font.pixelSize: Theme.fontSizeSmall
            text: NightLight.mode === "auto"
                  ? (NightLight.scheduleText ? `Automatic: on ${NightLight.scheduleText}` : "Automatic: follows the schedule")
                  : NightLight.mode === "on" ? "On until you turn it off" : "Off until you turn it on"
        }

        // Warmth: 6000 K (neutral) … 2500 K (very warm). Moving it switches night light on.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs
            Icon { icon: "wb_sunny"; size: 16 }
            StyledSlider {
                Layout.fillWidth: true
                from: 0
                to: 1
                // left = cool, right = warm
                value: (NightLight.maxTemperature - NightLight.temperature) / (NightLight.maxTemperature - NightLight.minTemperature)
                onMoved: v => NightLight.setTemperature(NightLight.maxTemperature - v * (NightLight.maxTemperature - NightLight.minTemperature))
            }
            Icon { icon: "nightlight"; size: 16; filled: true; color: Theme.accent }
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: NightLight.temperature + " K"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textDim
            font.features: { "tnum": 1 }
        }

        Separator {}

        ListItem {
            icon: "schedule"
            text: "Follow schedule"
            subtext: NightLight.scheduleText ? `Warm screen ${NightLight.scheduleText}` : "hyprsunset.conf"
            highlighted: NightLight.mode === "auto"
            onClicked: NightLight.setMode("auto")
        }
    }
}
