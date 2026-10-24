pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// PipeWire audio: default sink/source, device lists, per-app streams.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false
    // Same limit as the XF86Audio binds (wpctl -l 1.5).
    readonly property real maxVolume: 1.5

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isSink && n.isStream)

    readonly property string icon: muted || volume <= 0.001 ? "volume_off"
                                 : volume < 0.34 ? "volume_mute"
                                 : volume < 0.67 ? "volume_down" : "volume_up"

    function clamp(v: real): real { return Math.max(0, Math.min(root.maxVolume, v)); }

    function setNodeVolume(node, v: real) {
        if (!node?.audio) return;
        node.audio.muted = false;
        node.audio.volume = clamp(v);
    }
    function setVolume(v: real) { setNodeVolume(root.sink, v); }
    function step(delta: real) { setVolume(root.volume + delta); }
    function toggleMute() { if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted; }
    function toggleMicMute() { if (root.source?.audio) root.source.audio.muted = !root.source.audio.muted; }
    function setDefaultSink(node) { Pipewire.preferredDefaultAudioSink = node; }
    function setDefaultSource(node) { Pipewire.preferredDefaultAudioSource = node; }

    function nodeName(node): string {
        if (!node) return "None";
        if (node.isStream) return node.properties["application.name"] || node.description || node.name;
        return node.description || node.nickname || node.name;
    }

    // Volume/mute of tracked nodes are only live while tracked.
    PwObjectTracker {
        objects: root.sinks.concat(root.sources, root.streams)
    }
}
