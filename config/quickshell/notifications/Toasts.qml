import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Notification pop-ups, top right under the bar on the focused monitor.
// Each toast hides after its timeout (paused while hovered); critical ones stay until closed.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Notifs.toasts.length > 0
    color: "transparent"

    anchors.top: true
    anchors.right: true
    margins.top: Theme.panelMargin + Theme.barHeight + Theme.popupGap
    margins.right: Theme.panelMargin
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    implicitWidth: 380
    implicitHeight: Math.max(1, column.implicitHeight)

    WlrLayershell.namespace: "hcs-toast"
    WlrLayershell.layer: WlrLayer.Overlay

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.spaceXs

        Repeater {
            model: Notifs.toasts

            delegate: NotificationCard {
                id: card
                required property Notification modelData
                notification: modelData
                toast: true
                Layout.fillWidth: true

                Timer {
                    interval: Notifs.timeoutFor(card.notification) * 1000
                    running: interval > 0 && !card.hovered
                    onTriggered: Notifs.toastTimedOut(card.notification)
                }
            }
        }
    }
}
