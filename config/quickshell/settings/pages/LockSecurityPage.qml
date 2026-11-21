import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.components
import qs.services
import "../components"

ColumnLayout {
    id: root

    spacing: Theme.spaceM

    Component.onCompleted: LockConfig.refreshProbes()

    SettingsPageHeader {
        icon: "lock"
        title: "Lock Screen & Security"
        subtitle: "Howdy IR facial recognition, lock appearance, badges, and hypridle timeouts"

        SettingsActionButton {
            variant: "accent"
            icon: "lock"
            text: "Lock Now"
            onClicked: LockConfig.testLockNow()
        }
        SettingsActionButton {
            icon: "restart_alt"
            text: "Reset"
            onClicked: LockConfig.reset()
        }
    }

    // ---- Biometric / Howdy ----
    SettingsSection {
        title: "Biometric Unlock (Howdy IR)"
        description: "Parallel PAM conversation (qs-lock-face) alongside instant password unlock (qs-lock)"

        SettingsRow {
            icon: "face"
            highlighted: LockConfig.howdyEnabled && LockConfig.howdyInstalled
            title: "Enable Howdy Face Scan on Lock Screen"
            subtitle: LockConfig.howdyStatusText

            Toggle {
                checked: LockConfig.howdyEnabled
                onToggled: LockConfig.setHowdyEnabled(!LockConfig.howdyEnabled)
            }
        }
    }

    // ---- Lock Screen Personalization ----
    SettingsSection {
        title: "User & Lock Appearance"

        SettingsRow {
            icon: "account_circle"
            title: "User Avatar"
            subtitle: LockConfig.avatarPath !== "" ? LockConfig.avatarPath : "Using accent initial circle"

            Rectangle {
                visible: LockConfig.avatarPath !== ""
                width: 34; height: 34; radius: 17
                color: Theme.accent
                ClippingRectangle {
                    anchors.fill: parent
                    radius: 17
                    color: "transparent"
                    Image {
                        anchors.fill: parent
                        source: LockConfig.avatarPath ? ("file://" + LockConfig.avatarPath) : ""
                        fillMode: Image.PreserveAspectCrop
                    }
                }
            }

            SettingsActionButton {
                icon: "image"
                text: "Choose…"
                onClicked: LockConfig.pickAvatar()
            }
            SettingsActionButton {
                visible: LockConfig.avatarPath !== ""
                icon: "close"
                text: "Clear"
                onClicked: LockConfig.setAvatarPath("")
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: 6

            StyledText { text: "Custom Greeting (blank = automatic time-of-day greeting)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXxs

                TextField {
                    id: greetField
                    Layout.fillWidth: true
                    implicitHeight: 38
                    text: LockConfig.customGreeting
                    placeholder: "e.g. Welcome back, Mate"
                    onAccepted: LockConfig.setCustomGreeting(text)
                }
                SettingsActionButton {
                    variant: "accent"
                    text: "Save"
                    onClicked: LockConfig.setCustomGreeting(greetField.text)
                }
            }
        }

        SettingsRow {
            icon: "keyboard_capslock"
            title: "Show Caps Lock & Keyboard Layout Badges"
            subtitle: "Displays a warning badge when Caps Lock is active and lets you click to switch layout"
            Toggle {
                checked: LockConfig.showCapsAndLayout
                onToggled: LockConfig.setShowCapsAndLayout(!LockConfig.showCapsAndLayout)
            }
        }

        SettingsRow {
            icon: "partly_cloudy_day"
            title: "Show Weather Pill on Lock Screen"
            subtitle: "Compact temperature and condition chip in the bottom-right corner"
            Toggle {
                checked: LockConfig.showWeather
                onToggled: LockConfig.setShowWeather(!LockConfig.showWeather)
            }
        }

        SettingsRow {
            icon: "event_upcoming"
            title: "Show Upcoming Event Time (Privacy-Safe)"
            subtitle: "Shows only when your next calendar event starts — never its title or location"
            Toggle {
                checked: LockConfig.showNextEvent
                onToggled: LockConfig.setShowNextEvent(!LockConfig.showNextEvent)
            }
        }

        SettingsRow {
            icon: "notifications"
            title: "Show Unread Notification Count (Privacy-Safe)"
            subtitle: "Shows only the unread notification count badge — never message contents"
            Toggle {
                checked: LockConfig.showNotifCount
                onToggled: LockConfig.setShowNotifCount(!LockConfig.showNotifCount)
            }
        }

        SettingsRow {
            icon: "power_settings_new"
            title: "Show Reboot & Shut Down Actions"
            subtitle: "Two-click confirmed power buttons alongside Suspend on the lock screen"
            Toggle {
                checked: LockConfig.showPowerActions
                onToggled: LockConfig.setShowPowerActions(!LockConfig.showPowerActions)
            }
        }
    }

    // ---- Idle & Sleep Timeouts (hypridle.conf) ----
    SettingsSection {
        title: "Idle & Sleep Schedule (hypridle.conf)"
        description: "Configured timeouts handled by systemd user service hypridle.service"

        Repeater {
            model: LockConfig.idleListeners
            delegate: SettingsRow {
                required property var modelData
                icon: modelData.label.includes("Lock") ? "lock"
                    : modelData.label.includes("Suspend") ? "bedtime"
                    : "monitor_heart"
                title: modelData.label
                subtitle: "After " + modelData.formatted + " of inactivity"

                StyledText {
                    text: modelData.formatted
                    font.weight: Font.DemiBold
                    color: Theme.accent
                    font.features: { "tnum": 1 }
                }
            }
        }
    }
}
