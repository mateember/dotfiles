import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.components
import qs.services

// Indicators for the workspaces that exist on the monitor this bar is on (Hyprland keeps a
// workspace while it has windows or is shown; special workspaces like the scratchpad are hidden).
// Active workspace: filled amber circle with dark number. Others: plain light number.
// Urgent workspaces get a red tint.
Row {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? -1

    readonly property var ids: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.monitor === root.monitor)
        .map(w => w.id)
        .sort((a, b) => a - b)

    function workspaceFor(id: int): HyprlandWorkspace {
        const all = Hyprland.workspaces.values;
        for (let i = 0; i < all.length; i++)
            if (all[i].id === id) return all[i];
        return null;
    }

    spacing: 0

    Repeater {
        model: root.ids

        delegate: Item {
            id: ws
            required property int modelData
            readonly property bool isActive: modelData === root.activeId
            readonly property HyprlandWorkspace workspace: root.workspaceFor(modelData)
            readonly property bool urgent: workspace?.urgent ?? false

            // One cell per workspace; the circle is smaller than the bar.
            width: Theme.barHeight
            height: Theme.barHeight

            Rectangle {
                id: circle
                anchors.centerIn: parent
                width: Theme.workspaceCircle
                height: width
                radius: width / 2
                color: ws.isActive ? Theme.accent
                     : ws.urgent ? Theme.alpha(Theme.destructive, 0.35)
                     : mouse.containsMouse ? Theme.componentHover
                     : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            // Center the digits' visible shape (not the text line box, whose ascent/descent
            // pushed the number down and to one side inside the circle).
            StyledText {
                id: number
                text: ws.modelData
                font.pixelSize: Theme.barFontSize - 1
                font.weight: Font.Bold
                color: ws.isActive ? Theme.fgOnAccent : Theme.text
                x: circle.x + (circle.width - metrics.tightBoundingRect.width) / 2 - metrics.tightBoundingRect.x
                // tightBoundingRect.y is relative to the baseline (negative = above it)
                y: circle.y + (circle.height - metrics.tightBoundingRect.height) / 2 - (baselineOffset + metrics.tightBoundingRect.y)
                TextMetrics {
                    id: metrics
                    font: number.font
                    text: number.text
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.focusWorkspace(ws.modelData)
            }
        }
    }

    // Scroll over the indicators to move between workspaces on this monitor.
    // One workspace per mouse notch / per touchpad "notch", at most every 250 ms.
    ScrollStepper {
        id: stepper
        cooldown: 250
        onStepped: dir => Hypr.focusWorkspace(dir > 0 ? "m-1" : "m+1")
    }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => stepper.feed(e)
    }
}
