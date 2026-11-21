pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Optional subtle UI sound feedback using PipeWire's `pw-play` and Freedesktop sound files.
// Off by default until enabled in Settings -> Sound & Feedback.
Singleton {
    id: root

    readonly property string stateFile: Quickshell.statePath("sound-cues.json")
    readonly property string soundDir: "/run/current-system/sw/share/sounds/freedesktop/stereo"

    property bool enabled: false
    property real volume: 0.45
    property bool cueVolume: true
    property bool cueNotifications: true
    property bool cuePower: true
    property bool cueCapture: true

    property double _lastPlayMs: 0

    function playFile(filename: string, force: bool) {
        if (!force && !root.enabled) return;
        const now = Date.now();
        if (!force && (now - root._lastPlayMs) < 120) return;
        root._lastPlayMs = now;
        const vol = Math.max(0.05, Math.min(1.0, root.volume)).toFixed(2);
        Quickshell.execDetached(["pw-play", "--volume", vol, root.soundDir + "/" + filename]);
    }

    function playVolumeTick() {
        if (root.enabled && root.cueVolume) playFile("audio-volume-change.oga", false);
    }
    function playNotification() {
        if (root.enabled && root.cueNotifications) playFile("message-new-instant.oga", false);
    }
    function playPower(pluggedIn: bool) {
        if (root.enabled && root.cuePower) playFile(pluggedIn ? "device-added.oga" : "device-removed.oga", false);
    }
    function playCapture() {
        if (root.enabled && root.cueCapture) playFile("camera-shutter.oga", false);
    }
    function testSpeaker() {
        playFile("audio-test-signal.oga", true);
    }
    function testChime() {
        playFile("message-new-instant.oga", true);
    }

    function setEnabled(v: bool) { root.enabled = v; save(); }
    function setVolume(v: real) { root.volume = Math.max(0.1, Math.min(1.0, Math.round(v * 20) / 20)); save(); }
    function setCueVolume(v: bool) { root.cueVolume = v; save(); }
    function setCueNotifications(v: bool) { root.cueNotifications = v; save(); }
    function setCuePower(v: bool) { root.cuePower = v; save(); }
    function setCueCapture(v: bool) { root.cueCapture = v; save(); }

    function save() {
        store.setText(JSON.stringify({
            enabled: root.enabled,
            volume: root.volume,
            cueVolume: root.cueVolume,
            cueNotifications: root.cueNotifications,
            cuePower: root.cuePower,
            cueCapture: root.cueCapture
        }, null, 2));
    }

    FileView {
        id: store
        path: root.stateFile
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (d && typeof d === "object") {
                    if (d.enabled !== undefined) root.enabled = Boolean(d.enabled);
                    if (d.volume !== undefined) root.volume = Math.max(0.1, Math.min(1.0, Number(d.volume) || 0.45));
                    if (d.cueVolume !== undefined) root.cueVolume = Boolean(d.cueVolume);
                    if (d.cueNotifications !== undefined) root.cueNotifications = Boolean(d.cueNotifications);
                    if (d.cuePower !== undefined) root.cuePower = Boolean(d.cuePower);
                    if (d.cueCapture !== undefined) root.cueCapture = Boolean(d.cueCapture);
                }
            } catch (e) {}
        }
    }
}
