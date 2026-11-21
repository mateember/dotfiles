import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services
import "../components"

ColumnLayout {
    id: root

    spacing: Theme.spaceM

    SettingsPageHeader {
        icon: "notifications"
        title: "Notifications & Privacy"
        subtitle: "Do Not Disturb, smart auto-silencing, per-app mutes, and live mic/camera/screen audit"

        SettingsActionButton {
            icon: "clear_all"
            text: "Clear History (" + Notifs.history.length + ")"
            buttonEnabled: Notifs.history.length > 0
            onClicked: Notifs.clearAll()
        }
    }

    // ---- Do Not Disturb & Smart Auto-DND ----
    SettingsSection {
        title: "Do Not Disturb"

        SettingsRow {
            icon: Notifs.dnd ? "notifications_off" : "notifications"
            highlighted: Notifs.effectiveDnd
            title: "Do Not Disturb"
            subtitle: Notifs.dnd ? "On · Pop-up toasts paused (critical alerts still show)"
                    : Notifs.smartDndActive ? "Smart Auto-DND currently active"
                    : "Off · Showing incoming notification toasts"
            Toggle {
                checked: Notifs.dnd
                onToggled: Notifs.toggleDnd()
            }
        }

        SettingsRow {
            icon: "fullscreen"
            title: "Auto-Silence During Fullscreen Apps"
            subtitle: "Suppress non-critical notification toasts while gaming or watching fullscreen video"
            Toggle {
                checked: Notifs.autoDndFullscreen
                onToggled: Notifs.setAutoDndFullscreen(!Notifs.autoDndFullscreen)
            }
        }

        SettingsRow {
            icon: "screen_share"
            title: "Auto-Silence While Screen Sharing"
            subtitle: "Automatically hide pop-up toasts when a screen capture or call share is active"
            Toggle {
                checked: Notifs.autoDndScreenshare
                onToggled: Notifs.setAutoDndScreenshare(!Notifs.autoDndScreenshare)
            }
        }

        SettingsSliderRow {
            icon: "timer"
            title: "Toast Display Duration"
            subtitle: "How long non-critical pop-ups remain visible before fading out"
            valueText: Notifs.defaultTimeoutSec.toFixed(1) + " s"
            from: 2.0
            to: 12.0
            step: 0.5
            value: Notifs.defaultTimeoutSec
            onMoved: v => Notifs.setDefaultTimeoutSec(v)
        }
    }

    // ---- Per-App Mute Rules ----
    SettingsSection {
        title: "Per-App Notification Mutes"
        description: "Muted apps still appear in Notification Center history without popping up toasts"

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: Theme.spaceXxs

            TextField {
                id: muteAppField
                Layout.fillWidth: true
                implicitHeight: 38
                placeholder: "Add app name to mute (e.g. Discord, Slack, Spotify)…"
                onAccepted: {
                    const n = text.trim();
                    if (n) {
                        Notifs.rememberApp(n);
                        if (!Notifs.isAppMuted(n)) Notifs.toggleAppMute(n);
                        text = "";
                    }
                }
            }
            SettingsActionButton {
                variant: "accent"
                icon: "notifications_off"
                text: "Mute App"
                onClicked: {
                    const n = muteAppField.text.trim();
                    if (n) {
                        Notifs.rememberApp(n);
                        if (!Notifs.isAppMuted(n)) Notifs.toggleAppMute(n);
                        muteAppField.text = "";
                    }
                }
            }
        }

        StyledText {
            visible: Notifs.knownApps.length === 0
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            color: Theme.textDim
            font.pixelSize: Theme.fontSizeSmall
            text: "Apps will appear here automatically as they send notifications, or add one above."
        }

        Repeater {
            model: Notifs.knownApps
            delegate: SettingsRow {
                required property string modelData
                readonly property bool muted: Notifs.isAppMuted(modelData)
                icon: muted ? "notifications_off" : "notifications_active"
                highlighted: muted
                title: modelData
                subtitle: muted ? "Muted (history only)" : "Toasts enabled"

                Toggle {
                    checked: !muted
                    onToggled: Notifs.toggleAppMute(modelData)
                }
            }
        }
    }

    // ---- Active Privacy Sensors Audit ----
    SettingsSection {
        title: "Live Privacy Audit"
        description: "Applications currently accessing your microphone, camera, or screen"

        SettingsRow {
            icon: "mic"
            highlighted: Privacy.micActive
            title: "Microphone"
            subtitle: Privacy.micActive ? ("In use by: " + Privacy.micApps.join(", ")) : "Not in use"

            SettingsActionButton {
                visible: Privacy.micActive
                variant: Audio.micMuted ? "accent" : "danger"
                icon: Audio.micMuted ? "mic_off" : "mic"
                text: Audio.micMuted ? "Unmute Mic" : "Mute Mic"
                onClicked: Audio.toggleMicMute()
            }
        }

        SettingsRow {
            icon: "photo_camera"
            highlighted: Privacy.cameraActive
            title: "Camera"
            subtitle: Privacy.cameraActive ? ("In use by: " + Privacy.cameraApps.join(", ")) : "Not in use"
        }

        SettingsRow {
            icon: "screen_share"
            highlighted: Privacy.screenActive
            title: "Screen Capture / Sharing"
            subtitle: Privacy.screenActive ? ("Active: " + Privacy.screenApps.join(", ")) : "Not in use"

            SettingsActionButton {
                visible: Recorder.recording
                variant: "danger"
                icon: "stop_circle"
                text: "Stop Recording"
                onClicked: Recorder.stopRecording()
            }
        }
    }
}
