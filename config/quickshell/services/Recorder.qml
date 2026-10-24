pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording & interactive screenshot capture service.
Singleton {
    id: root

    property bool overlayOpen: false
    property string tab: "shot"               // "shot" | "record"

    // Screenshot options
    property string shotAction: "copy"        // "copy" | "save" | "annotate"
    property int shotDelay: 0                 // 0 | 3 | 5

    // Recording options & state
    property string recordAudio: "none"       // "none" | "system" | "mic"
    property string recordMode: "screen"      // "screen" | "region" | "window"
    property bool recording: false
    property bool starting: false
    property int elapsedSeconds: 0
    property string outputFile: ""

    readonly property string scriptPath: Quickshell.shellPath("scripts/capture.sh")

    readonly property string formattedTime: {
        const m = Math.floor(root.elapsedSeconds / 60);
        const s = root.elapsedSeconds % 60;
        return (m < 10 ? "0" + m : String(m)) + ":" + (s < 10 ? "0" + s : String(s));
    }

    function openOverlay(initialTab: string) {
        if (initialTab === "shot" || initialTab === "record")
            root.tab = initialTab;
        Popups.close();
        QuickSettingsState.close();
        root.overlayOpen = true;
    }

    function closeOverlay() {
        root.overlayOpen = false;
    }

    function toggleOverlay(initialTab: string) {
        if (root.overlayOpen) root.closeOverlay();
        else root.openOverlay(initialTab || "shot");
    }

    function takeScreenshot(mode: string) {
        const m = mode || "region";
        const act = root.shotAction;
        const dly = String(root.shotDelay);
        root.overlayOpen = false;
        Quickshell.execDetached(["bash", root.scriptPath, "shot", m, act, dly]);
    }

    function startRecording(mode: string, audio: string) {
        if (root.recording || root.starting) return;
        const m = mode || root.recordMode || "screen";
        const a = audio || root.recordAudio || "none";
        root.recordMode = m;
        root.recordAudio = a;
        root.overlayOpen = false;
        root.starting = true;
        root.elapsedSeconds = 0;
        recProc.running = false;
        recProc.command = ["bash", root.scriptPath, "record", m, a];
        recProc.running = true;
    }

    function stopRecording() {
        // Send SIGINT directly to wf-recorder / wl-screenrec via capture.sh stop
        Quickshell.execDetached(["bash", root.scriptPath, "stop"]);
        if (recProc.running) {
            recProc.signal(2);
        } else {
            root.recording = false;
            root.starting = false;
        }
        stopFallbackTimer.restart();
    }

    function toggleRecording(mode: string) {
        if (root.recording || root.starting) root.stopRecording();
        else root.startRecording(mode || "screen", root.recordAudio);
    }

    Timer {
        id: stopFallbackTimer
        interval: 1500
        onTriggered: {
            root.recording = false;
            root.starting = false;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsedSeconds += 1
    }

    Process {
        id: recProc
        stdout: SplitParser {
            onRead: line => {
                const s = line.trim();
                if (s.startsWith("STARTED:")) {
                    root.outputFile = s.slice(8);
                    root.starting = false;
                    root.recording = true;
                    root.elapsedSeconds = 0;
                }
            }
        }
        onExited: {
            stopFallbackTimer.stop();
            root.recording = false;
            root.starting = false;
        }
    }

    IpcHandler {
        target: "capture"
        function toggle(): void { root.toggleOverlay("shot"); }
        function open(): void { root.openOverlay("shot"); }
        function recordMenu(): void { root.openOverlay("record"); }
        function close(): void { root.closeOverlay(); }
        function shot(mode: string): void { root.takeScreenshot(mode || "region"); }
        function recordToggle(): void { root.toggleRecording("screen"); }
        function recordStop(): void { root.stopRecording(); }
    }
}
