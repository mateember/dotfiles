pragma Singleton

import QtQuick
import Quickshell
import qs

// On-screen display state. Osd.show("volume_up", "Volume", 0.45) shows a pill with a bar;
// value < 0 shows only icon + label. The window is in osd/OsdWindow.qml.
Singleton {
    id: root

    property string icon: ""
    property string label: ""
    property real value: -1          // 0..1 (or up to `max`), -1 = no bar
    property real max: 1
    property color swatch: "transparent"   // color picker result
    property bool visible: false

    // Ignore the burst of "changes" while services load at startup / hot reload.
    property bool ready: false
    Timer { running: true; interval: 3000; onTriggered: root.ready = true }

    function show(icon: string, label: string, value: real, max: real) {
        if (!root.ready) return;
        root.icon = icon;
        root.label = label;
        root.value = value === undefined ? -1 : value;
        root.max = max === undefined || max <= 0 ? 1 : max;
        root.swatch = "transparent";
        root.visible = true;
        hide.restart();
    }

    function showColor(hex: string) {
        root.show("colorize", hex + " copied", -1, 1);
        root.swatch = hex;
    }

    Timer {
        id: hide
        interval: 1600
        onTriggered: root.visible = false
    }
}
