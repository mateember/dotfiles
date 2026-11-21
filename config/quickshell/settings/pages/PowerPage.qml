import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services
import "../components"

ColumnLayout {
    id: root

    spacing: Theme.spaceM

    Component.onCompleted: {
        PowerProfile.refresh();
        SystemManager.refreshConservation();
        Brightness.refreshExternals();
        Hypr.refreshLayout();
        HyprSettings.refreshLiveOptions();
    }

    SettingsPageHeader {
        icon: "battery_full"
        title: "Power & Battery"
        subtitle: "Battery health, TLP performance profiles, conservation mode, and keep-awake timers"

        SettingsActionButton {
            icon: "refresh"
            text: "Refresh"
            onClicked: {
                PowerProfile.refresh();
                SystemManager.refreshConservation();
            }
        }
    }

    // ---- Battery Status Card ----
    SettingsSection {
        visible: Battery.available
        title: "Battery"

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: Theme.spaceS

            Rectangle {
                implicitWidth: 56
                implicitHeight: 56
                radius: Theme.radiusM
                color: Theme.alpha(Theme.accent, 0.18)

                Icon {
                    anchors.centerIn: parent
                    icon: Battery.icon
                    filled: true
                    size: 32
                    color: Battery.percent <= 0.1 && !Battery.charging ? Theme.destructive
                         : Battery.percent <= 0.2 && !Battery.charging ? Theme.warning
                         : Theme.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: Math.round(Battery.percent * 100) + "%"
                        font.pixelSize: Theme.fontSizeTitle + 4
                        font.weight: Font.Bold
                        color: Theme.textStrong
                        font.features: { "tnum": 1 }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "· " + Battery.status
                        color: Theme.textDim
                        elide: Text.ElideRight
                    }
                }

                // Charge bar
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    radius: 4
                    color: Theme.surface2
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, Battery.percent))
                        height: parent.height
                        radius: 4
                        color: Battery.percent <= 0.1 && !Battery.charging ? Theme.destructive
                             : Battery.percent <= 0.2 && !Battery.charging ? Theme.warning
                             : Theme.accent
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spaceM

                    StyledText {
                        visible: Battery.device?.healthSupported ?? false
                        text: "Health: " + Math.round(Battery.device?.healthPercentage ?? 0) + "%"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textDim
                    }
                    StyledText {
                        visible: (Battery.device?.changeRate ?? 0) > 0.1
                        text: (Battery.charging ? "Charging at " : "Drawing ") + Number(Battery.device?.changeRate ?? 0).toFixed(1) + " W"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textDim
                    }
                }
            }
        }

        // Lenovo IdeaPad Battery Conservation Mode
        SettingsRow {
            visible: SystemManager.conservationAvailable
            icon: "battery_saver"
            highlighted: SystemManager.conservationEnabled
            title: "Battery Conservation Mode (IdeaPad)"
            subtitle: SystemManager.conservationBusy
                ? "Updating hardware charge threshold…"
                : (SystemManager.conservationEnabled
                    ? "Active · Caps charge around 60–80% to extend battery lifespan"
                    : "Off · Battery charges to 100%")

            Toggle {
                checked: SystemManager.conservationEnabled
                enabled: !SystemManager.conservationBusy
                onToggled: SystemManager.setConservationMode(!SystemManager.conservationEnabled)
            }
        }

        StyledText {
            visible: SystemManager.conservationError !== ""
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            text: SystemManager.conservationError
            color: Theme.destructive
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }
    }

    // ---- TLP Power Profile ----
    SettingsSection {
        title: "Power Mode (TLP)"
        description: PowerProfile.manual
            ? "Manual override active — click Auto to return to automatic AC/Battery switching"
            : "Automatic AC/Battery switching active"

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: Theme.spaceXs

            SettingsPillGroup {
                selectedId: PowerProfile.mode
                model: [
                    { id: "low-power",   label: "Power Saver", icon: "energy_savings_leaf" },
                    { id: "balanced",    label: "Balanced",    icon: "speed" },
                    { id: "performance", label: "Performance", icon: "bolt" }
                ]
                onPicked: id => PowerProfile.setMode(id)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs
                StyledText {
                    Layout.fillWidth: true
                    text: "Animated wallpapers and Snow effects require Performance mode."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                    wrapMode: Text.WordWrap
                }
                SettingsActionButton {
                    icon: "hdr_auto"
                    text: PowerProfile.manual ? "Return to Auto" : "Auto Active"
                    active: !PowerProfile.manual
                    buttonEnabled: PowerProfile.manual
                    onClicked: PowerProfile.setAuto()
                }
            }
        }
    }

    // ---- Caffeine / Keep Screen Awake ----
    SettingsSection {
        title: "Caffeine (Keep Screen Awake)"
        description: "Temporarily inhibit screen lock and suspend via Wayland IdleInhibitor"

        SettingsRow {
            icon: "coffee"
            highlighted: Idle.caffeine
            title: "Keep Screen Awake"
            subtitle: Idle.caffeine ? ("Active · " + Idle.statusText) : "Off · Normal idle timers active"

            Toggle {
                checked: Idle.caffeine
                onToggled: Idle.toggle()
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: 6

            Repeater {
                model: [
                    { mins: 0,   label: "Indefinitely" },
                    { mins: 15,  label: "15 min" },
                    { mins: 30,  label: "30 min" },
                    { mins: 60,  label: "1 hour" },
                    { mins: 120, label: "2 hours" },
                    { mins: 240, label: "4 hours" }
                ]
                delegate: SettingsActionButton {
                    required property var modelData
                    active: Idle.caffeine && Idle.durationMinutes === modelData.mins
                    text: modelData.label
                    onClicked: Idle.enableFor(modelData.mins)
                }
            }
        }
    }

    // ---- Quick Battery Savers ----
    SettingsSection {
        title: "Display Power Savers"

        SettingsRow {
            icon: "speed"
            title: "Panel Refresh Rate"
            subtitle: "60 Hz reduces laptop power draw significantly"
            SettingsPillGroup {
                Layout.preferredWidth: 160
                Layout.fillWidth: false
                selectedId: String(Brightness.refreshRate)
                model: [{ id: "60", label: "60 Hz" }, { id: "120", label: "120 Hz" }]
                onPicked: id => Brightness.setRefreshRate(parseInt(id))
            }
        }

        SettingsRow {
            icon: "blur_on"
            title: "Window Blur"
            subtitle: "Disabling compositor blur saves GPU power on battery"
            Toggle {
                checked: HyprSettings.blurEnabled
                onToggled: HyprSettings.setBlurEnabled(!HyprSettings.blurEnabled)
            }
        }
    }
}
