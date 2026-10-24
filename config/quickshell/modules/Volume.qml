import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services

// Volume. Scroll to change, middle click to mute, click for the mixer.
BarButton {
    id: root

    active: pop.open
    onClicked: button => button === Qt.MiddleButton ? Audio.toggleMute() : pop.toggle()
    onScrolled: delta => Audio.step(delta > 0 ? 0.05 : -0.05)

    Icon { icon: Audio.icon }

    component VolumeRow: RowLayout {
        id: row
        property PwNode node
        property string icon
        property string mutedIcon
        Layout.fillWidth: true
        spacing: Theme.spaceXs
        IconButton {
            icon: (row.node?.audio?.muted ?? false) ? row.mutedIcon : row.icon
            onClicked: if (row.node?.audio) row.node.audio.muted = !row.node.audio.muted
        }
        StyledSlider {
            Layout.fillWidth: true
            to: Audio.maxVolume
            value: row.node?.audio?.volume ?? 0
            enabled: !(row.node?.audio?.muted ?? true)
            onMoved: v => Audio.setNodeVolume(row.node, v)
        }
        StyledText {
            text: Math.round((row.node?.audio?.volume ?? 0) * 100) + "%"
            Layout.preferredWidth: 44
            horizontalAlignment: Text.AlignRight
            font.features: { "tnum": 1 }
        }
    }

    component SectionLabel: StyledText {
        Layout.fillWidth: true
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textDim
    }

    Popup {
        id: pop
        name: "volume"
        anchorItem: root
        contentWidth: 360

        property bool outputsOpen: false
        property bool inputsOpen: false
        onOpenChanged: if (!open) { outputsOpen = false; inputsOpen = false; }

        PopupHeader {
            title: "Sound"
            AppButton { icon: "tune"; command: ["pavucontrol"] }
            AppButton { command: ["cosmic-settings", "sound"] }
        }

        SectionLabel { text: "Output · " + Audio.nodeName(Audio.sink) }
        VolumeRow { node: Audio.sink; icon: "volume_up"; mutedIcon: "volume_off" }

        SectionLabel { text: "Input · " + Audio.nodeName(Audio.source); visible: !!Audio.source }
        VolumeRow { node: Audio.source; icon: "mic"; mutedIcon: "mic_off"; visible: !!Audio.source }

        Separator {}

        ListItem {
            icon: pop.outputsOpen ? "expand_less" : "expand_more"
            text: "Output device"
            subtext: Audio.nodeName(Audio.sink)
            onClicked: pop.outputsOpen = !pop.outputsOpen
        }
        Repeater {
            model: pop.outputsOpen ? Audio.sinks : []
            delegate: ListItem {
                required property PwNode modelData
                icon: "speaker"
                Layout.leftMargin: Theme.spaceM
                text: Audio.nodeName(modelData)
                highlighted: modelData === Audio.sink
                onClicked: Audio.setDefaultSink(modelData)
            }
        }

        ListItem {
            visible: Audio.sources.length > 0
            icon: pop.inputsOpen ? "expand_less" : "expand_more"
            text: "Input device"
            subtext: Audio.nodeName(Audio.source)
            onClicked: pop.inputsOpen = !pop.inputsOpen
        }
        Repeater {
            model: pop.inputsOpen ? Audio.sources : []
            delegate: ListItem {
                required property PwNode modelData
                icon: "mic"
                Layout.leftMargin: Theme.spaceM
                text: Audio.nodeName(modelData)
                highlighted: modelData === Audio.source
                onClicked: Audio.setDefaultSource(modelData)
            }
        }

        Separator { visible: Audio.streams.length > 0 }
        SectionLabel { text: "Applications"; visible: Audio.streams.length > 0 }
        Repeater {
            model: Audio.streams
            delegate: ColumnLayout {
                required property PwNode modelData
                Layout.fillWidth: true
                spacing: 0
                StyledText { text: Audio.nodeName(modelData); elide: Text.ElideRight; Layout.fillWidth: true }
                VolumeRow { node: modelData; icon: "volume_up"; mutedIcon: "volume_off" }
            }
        }
    }
}
