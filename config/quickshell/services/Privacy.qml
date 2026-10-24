pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Real-time privacy monitor: tracks active Microphone, Camera, and Screen Sharing streams.
Singleton {
    id: root

    property var rawMicApps: []
    property var rawCameraApps: []
    property var rawScreenApps: []

    readonly property var micApps: rawMicApps
    readonly property var cameraApps: rawCameraApps
    readonly property var screenApps: {
        const list = rawScreenApps.slice();
        if (Recorder.recording && list.indexOf("Screen Recorder") < 0)
            list.unshift("Screen Recorder");
        return list;
    }

    readonly property bool micActive: micApps.length > 0
    readonly property bool cameraActive: cameraApps.length > 0
    readonly property bool screenActive: screenApps.length > 0
    readonly property bool active: micActive || cameraActive || screenActive

    readonly property string scriptPath: Quickshell.shellPath("scripts/hardware-status.py")

    readonly property string summaryText: {
        const parts = [];
        if (micActive) parts.push("Mic: " + micApps.join(", "));
        if (cameraActive) parts.push("Cam: " + cameraApps.join(", "));
        if (screenActive) parts.push("Screen: " + screenApps.join(", "));
        return parts.join(" · ");
    }

    function refresh() {
        if (!proc.running) proc.running = true;
    }

    // Immediate refresh when PipeWire node count changes
    readonly property int _pwNodeCount: Pipewire.nodes.values.length
    on_PwNodeCountChanged: refresh()

    Timer {
        interval: 2500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: proc
        command: ["python3", root.scriptPath, "privacy"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text.trim());
                    root.rawMicApps = Array.isArray(d.mic) ? d.mic : [];
                    root.rawCameraApps = Array.isArray(d.camera) ? d.camera : [];
                    root.rawScreenApps = Array.isArray(d.screenshare) ? d.screenshare : [];
                } catch (e) {}
            }
        }
    }
}
