import QtQuick
import qs

// COSMIC-style slider: thin track, amber fill, round handle.
// `value` is display-only (bind it to a service); user input emits moved(newValue).
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real wheelStep: 0.05
    property bool enabled: true
    readonly property real fraction: Math.max(0, Math.min(1, (value - from) / (to - from)))
    readonly property bool dragging: mouse.pressed

    signal moved(real value)

    implicitWidth: 200
    implicitHeight: 20
    opacity: enabled ? 1 : 0.4

    function emitAt(x: real) {
        const f = Math.max(0, Math.min(1, (x - handle.width / 2) / (width - handle.width)));
        root.moved(from + f * (to - from));
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        x: handle.width / 2
        width: parent.width - handle.width
        height: 4
        radius: 2
        color: Theme.componentHover

        Rectangle {
            width: root.fraction * parent.width
            height: parent.height
            radius: parent.radius
            color: Theme.accent
        }
    }

    Rectangle {
        id: handle
        anchors.verticalCenter: parent.verticalCenter
        x: root.fraction * (root.width - width)
        width: 16
        height: 16
        radius: 8
        color: Theme.accent
        border.color: Theme.bg
        border.width: 2
        scale: mouse.pressed ? 1.15 : 1
        Behavior on scale { NumberAnimation { duration: Theme.animFast } }
    }

    ScrollStepper {
        id: stepper
        onStepped: dir => root.moved(Math.max(root.from, Math.min(root.to, root.value + dir * root.wheelStep)))
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: e => root.emitAt(e.x)
        onPositionChanged: e => { if (pressed) root.emitAt(e.x); }
        onWheel: e => stepper.feed(e)
    }
}
