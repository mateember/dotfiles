import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services
import "../components"

ColumnLayout {
    id: root

    spacing: Theme.spaceM

    SettingsPageHeader {
        icon: "volume_up"
        title: "Sound & Feedback"
        subtitle: "PipeWire output/input devices, per-app volume mixer, and subtle UI sound cues"

        SettingsActionButton {
            icon: "campaign"
            text: "Test Audio"
            onClicked: SoundCues.testSpeaker()
        }
        SettingsActionButton {
            icon: "tune"
            text: "pavucontrol"
            onClicked: Quickshell.execDetached(["pavucontrol"])
        }
    }

    // ---- Master Volume & Input ----
    SettingsSection {
        title: "Volume"

        SettingsSliderRow {
            icon: Audio.icon
            title: "Output · " + Audio.nodeName(Audio.sink)
            valueText: Audio.muted ? "Muted" : (Math.round(Audio.volume * 100) + "%")
            from: 0
            to: Audio.maxVolume
            step: 0.05
            value: Audio.volume
            sliderEnabled: !Audio.muted
            onMoved: v => Audio.setVolume(v)
        }

        SettingsRow {
            icon: Audio.muted ? "volume_off" : "volume_up"
            title: "Mute Output"
            subtitle: "Silence the default output device"
            Toggle { checked: Audio.muted; onToggled: Audio.toggleMute() }
        }

        SettingsRow {
            icon: "graphic_eq"
            title: "Over-Amplification (up to 150%)"
            subtitle: "Allow raising volume past 100% for quiet media"
            Toggle {
                checked: Audio.overAmplification
                onToggled: Audio.setOverAmplification(!Audio.overAmplification)
            }
        }

        SettingsSliderRow {
            visible: !!Audio.source
            icon: Audio.micMuted ? "mic_off" : "mic"
            title: "Input · " + Audio.nodeName(Audio.source)
            valueText: Audio.micMuted ? "Muted" : (Math.round(Audio.micVolume * 100) + "%")
            from: 0
            to: 1.0
            step: 0.05
            value: Audio.micVolume
            sliderEnabled: !Audio.micMuted
            onMoved: v => Audio.setNodeVolume(Audio.source, v)
        }

        SettingsRow {
            visible: !!Audio.source
            icon: Audio.micMuted ? "mic_off" : "mic"
            title: "Mute Microphone"
            subtitle: "Silence default audio input"
            Toggle { checked: Audio.micMuted; onToggled: Audio.toggleMicMute() }
        }
    }

    // ---- Output Devices ----
    SettingsSection {
        title: "Output Devices"
        Repeater {
            model: Audio.sinks
            delegate: SettingsRow {
                required property PwNode modelData
                icon: "speaker"
                highlighted: modelData === Audio.sink
                clickable: true
                title: Audio.nodeName(modelData)
                subtitle: modelData === Audio.sink ? "Default output" : ""
                onClicked: Audio.setDefaultSink(modelData)
                Icon {
                    visible: modelData === Audio.sink
                    icon: "check_circle"
                    color: Theme.accent
                }
            }
        }
    }

    // ---- Input Devices ----
    SettingsSection {
        visible: Audio.sources.length > 0
        title: "Input Devices"
        Repeater {
            model: Audio.sources
            delegate: SettingsRow {
                required property PwNode modelData
                icon: "mic"
                highlighted: modelData === Audio.source
                clickable: true
                title: Audio.nodeName(modelData)
                subtitle: modelData === Audio.source ? "Default input" : ""
                onClicked: Audio.setDefaultSource(modelData)
                Icon {
                    visible: modelData === Audio.source
                    icon: "check_circle"
                    color: Theme.accent
                }
            }
        }
    }

    // ---- Per-Application Mixer ----
    SettingsSection {
        visible: Audio.streams.length > 0
        title: "Application Volumes"
        description: "Adjust active PipeWire playback streams individually"

        Repeater {
            model: Audio.streams
            delegate: SettingsSliderRow {
                id: appRow
                required property PwNode modelData
                icon: (modelData?.audio?.muted ?? false) ? "volume_off" : "music_note"
                title: Audio.nodeName(modelData)
                valueText: (modelData?.audio?.muted ?? false) ? "Muted" : (Math.round((modelData?.audio?.volume ?? 0) * 100) + "%")
                from: 0
                to: Audio.maxVolume
                step: 0.05
                value: modelData?.audio?.volume ?? 0
                onMoved: v => Audio.setNodeVolume(appRow.modelData, v)
            }
        }
    }

    // ---- UI Sound Feedback Cues ----
    SettingsSection {
        title: "Desktop Sound Feedback"
        description: "Optional subtle Freedesktop chimes played directly via PipeWire"

        SettingsRow {
            icon: "notifications_active"
            highlighted: SoundCues.enabled
            title: "Enable UI Sound Cues"
            subtitle: "Play gentle feedback sounds for system events"
            Toggle {
                checked: SoundCues.enabled
                onToggled: SoundCues.setEnabled(!SoundCues.enabled)
            }
        }

        SettingsSliderRow {
            visible: SoundCues.enabled
            icon: "tune"
            title: "Feedback Volume"
            valueText: Math.round(SoundCues.volume * 100) + "%"
            from: 0.1
            to: 1.0
            step: 0.05
            value: SoundCues.volume
            onMoved: v => SoundCues.setVolume(v)
        }

        SettingsRow {
            visible: SoundCues.enabled
            icon: "volume_up"
            title: "Volume Step Tick"
            subtitle: "Soft click when adjusting system volume"
            Toggle { checked: SoundCues.cueVolume; onToggled: SoundCues.setCueVolume(!SoundCues.cueVolume) }
        }

        SettingsRow {
            visible: SoundCues.enabled
            icon: "notifications"
            title: "Notification Chime"
            subtitle: "Chime on incoming non-muted notifications"
            Toggle { checked: SoundCues.cueNotifications; onToggled: SoundCues.setCueNotifications(!SoundCues.cueNotifications) }
        }

        SettingsRow {
            visible: SoundCues.enabled
            icon: "power"
            title: "Power Adapter Plug / Unplug"
            subtitle: "Confirm charger connection changes"
            Toggle { checked: SoundCues.cuePower; onToggled: SoundCues.setCuePower(!SoundCues.cuePower) }
        }

        SettingsRow {
            visible: SoundCues.enabled
            icon: "photo_camera"
            title: "Screenshot Shutter"
            subtitle: "Soft camera shutter cue when capturing screenshots"
            Toggle { checked: SoundCues.cueCapture; onToggled: SoundCues.setCueCapture(!SoundCues.cueCapture) }
        }

        RowLayout {
            visible: SoundCues.enabled
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            SettingsActionButton {
                icon: "play_arrow"
                text: "Preview Chime"
                onClicked: SoundCues.testChime()
            }
        }
    }
}
