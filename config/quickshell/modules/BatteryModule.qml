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
        contentWidth: 290

        onOpenChanged: if (open) {
            PowerProfile.refresh();
            Brightness.refreshExternals();
            Hypr.refreshLayout();
        }

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

        Separator {}

        StyledText {
            text: "Power mode"
            font.weight: Font.DemiBold
        }

        Repeater {
            model: [
                { mode: "low-power", label: "Power Saver", sub: "Battery mode · low power", icon: "energy_savings_leaf" },
                { mode: "balanced", label: "Balanced", sub: "Standard performance and battery", icon: "speed" },
                { mode: "performance", label: "Performance", sub: "AC mode · maximum speed", icon: "bolt" }
            ]
            delegate: ListItem {
                required property var modelData
                icon: modelData.icon
                text: modelData.label
                subtext: modelData.sub
                highlighted: PowerProfile.mode === modelData.mode
                onClicked: PowerProfile.setMode(modelData.mode)
            }
        }

        Separator {}

        StyledText {
            text: "Display & effects"
            font.weight: Font.DemiBold
        }

        // Refresh rate toggle (60 Hz / 120 Hz, synced with Display menu)
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs
            Icon {
                icon: "speed"
                color: Brightness.refreshRate === 60 ? Theme.accent : Theme.text
            }
            StyledText {
                text: "Refresh rate"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Repeater {
                model: [60, 120]
                delegate: Rectangle {
                    id: batHzPill
                    required property int modelData
                    readonly property bool current: Brightness.refreshRate === modelData
                    implicitWidth: batHzText.implicitWidth + 2 * Theme.spaceXs
                    implicitHeight: 26
                    radius: height / 2
                    color: current ? Theme.accent : batHzMouse.containsMouse ? Theme.componentHover : Theme.button
                    StyledText {
                        id: batHzText
                        anchors.centerIn: parent
                        text: batHzPill.modelData + " Hz"
                        font.pixelSize: Theme.fontSizeSmall
                        color: batHzPill.current ? Theme.fgOnAccent : Theme.text
                        font.features: { "tnum": 1 }
                    }
                    MouseArea {
                        id: batHzMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Brightness.setRefreshRate(batHzPill.modelData)
                    }
                }
            }
        }

        // Session-only blur toggle (resets on logout / reboot)
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs
            Icon {
                icon: "blur_on"
                color: Hypr.blurEnabled ? Theme.accent : Theme.textDim
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: "Window blur"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                StyledText {
                    text: "Resets after logout"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                }
            }
            Toggle {
                checked: Hypr.blurEnabled
                onToggled: Hypr.toggleBlur()
            }
        }
    }
}
