pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording & interactive screenshot capture service.
Singleton {
    id: root

    property bool overlayOpen: false
    property bool fromQuickSettings: false
    property string tab: "shot"               // "shot" | "record"

    property string shotAction: "copy"        // "copy" | "save" | "annotate"
    property int shotDelay: 0                 // 0 | 3 | 5

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
        WidgetHistory.clear();
        root.fromQuickSettings = false;
        Popups.hide();
        QuickSettingsState.hide();
        root.overlayOpen = true;
    }

    function openOverlayFromQuickSettings(initialTab: string, qsScreen: string, qsAsWindow: bool) {
        if (initialTab === "shot" || initialTab === "record")
            root.tab = initialTab;
        WidgetHistory.push({ kind: "quicksettings", screen: qsScreen || "", asWindow: Boolean(qsAsWindow) });
        root.fromQuickSettings = !qsAsWindow;
        Popups.hide();
        QuickSettingsState.hide();
        root.overlayOpen = true;
    }

    function openOverlayFromPopup(initialTab: string, popupEntry: var) {
        if (initialTab === "shot" || initialTab === "record")
            root.tab = initialTab;
        if (popupEntry)
            WidgetHistory.push(popupEntry);
        root.fromQuickSettings = Boolean(popupEntry?.fromQuickSettings);
        Popups.hide();
        QuickSettingsState.hide();
        root.overlayOpen = true;
    }

    function hideOverlay() {
        root.overlayOpen = false;
        root.fromQuickSettings = false;
    }

    function backOverlay() {
        WidgetHistory.backFromCapture();
    }

    function closeOverlay() {
        WidgetHistory.clear();
        root.hideOverlay();
    }

    function toggleOverlay(initialTab: string) {
        if (root.overlayOpen) root.closeOverlay();
        else root.openOverlay(initialTab || "shot");
    }

    function takeScreenshot(mode: string) {
        const m = mode || "region";
        const act = root.shotAction;
        const dly = String(root.shotDelay);
        WidgetHistory.clear();
        root.hideOverlay();
        Quickshell.execDetached(["bash", root.scriptPath, "shot", m, act, dly]);
    }

    function startRecording(mode: string, audio: string) {
        if (root.recording) return;
        const m = mode || root.recordMode || "screen";
        const a = audio || root.recordAudio || "none";
        root.recordMode = m;
        root.recordAudio = a;
        WidgetHistory.clear();
        root.hideOverlay();
        root.starting = true;
        root.elapsedSeconds = 0;
        if (recProc.running) recProc.running = false;
        recProc.command = ["bash", root.scriptPath, "record", m, a];
        recProc.running = true;
    }

    function stopRecording() {
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
