import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.components
import qs.services

// Indicators for the workspaces that exist on the monitor this bar is on.
// Active workspace: smooth sliding filled accent circle behind the digits.
// Urgent workspaces get a red tint.
Item {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? -1

    readonly property var ids: Hyprland.workspaces.values
        .filter(w => w.id > 0 && root.monitor && w.monitor === root.monitor)
        .map(w => w.id)
        .sort((a, b) => a - b)

    readonly property int activeIndex: ids.indexOf(activeId)
    readonly property int cellSize: Theme.barHeight
    readonly property int circleSize: Math.min(Theme.workspaceCircle, Math.max(16, Theme.barHeight - 4))

    implicitWidth: Math.max(cellSize, ids.length * cellSize)
    implicitHeight: cellSize

    function workspaceFor(id: int): HyprlandWorkspace {
        const all = Hyprland.workspaces.values;
        for (let i = 0; i < all.length; i++)
            if (all[i].id === id) return all[i];
        return null;
    }

    // Smooth sliding active workspace pill
    Rectangle {
        id: activePill
        visible: root.activeIndex >= 0
        width: root.circleSize
        height: root.circleSize
        radius: width / 2
        color: Theme.accent
        y: Math.round((root.cellSize - height) / 2)
        x: Math.round(Math.max(0, root.activeIndex) * root.cellSize + (root.cellSize - width) / 2)

        Behavior on x {
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Easing.OutCubic
            }
        }
    }

    Row {
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: root.ids

            delegate: Item {
                id: ws
                required property int modelData
                readonly property bool isActive: modelData === root.activeId
                readonly property HyprlandWorkspace workspace: root.workspaceFor(modelData)
                readonly property bool urgent: workspace?.urgent ?? false

                width: root.cellSize
                height: root.cellSize

                Rectangle {
                    id: circle
                    anchors.centerIn: parent
                    width: root.circleSize
                    height: width
                    radius: width / 2
                    color: ws.isActive ? "transparent"
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
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    // Optical adjustment for digits with asymmetrical visual weight.
                    // "1" is nudged left so its vertical stem aligns with the circle's center.
                    readonly property var opticalOffsets: ({
                        "1": -1.5,
                    })
                    readonly property real opticalShiftX: opticalOffsets[text] ?? 0

                    x: circle.x + (circle.width - metrics.tightBoundingRect.width) / 2 - metrics.tightBoundingRect.x + opticalShiftX
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
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: TooltipState.requestShow(ws, "Workspace " + ws.modelData, "Right-click for Overview · Scroll to switch")
                    onExited: TooltipState.hide(ws)
                    onPressed: TooltipState.hide(ws)
                    onClicked: m => {
                        if (m.button === Qt.LeftButton) Hypr.focusWorkspace(ws.modelData);
                        else Hypr.toggleOverview();
                    }
                }
            }
        }
    }

    // Scroll over the indicators to move between workspaces on this monitor.
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
