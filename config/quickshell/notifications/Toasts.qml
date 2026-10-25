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
// Each toast lingers for ~4.5 seconds (paused while hovered) and smoothly fades out.
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

                property bool fadingOut: false

                // Smooth fade-in on arrival
                opacity: 0
                Component.onCompleted: fadeInAnim.start()

                NumberAnimation {
                    id: fadeInAnim
                    target: card
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 180
                    easing.type: Easing.OutCubic
                }

                // If hovered while fading out, cancel fade-out and restore full opacity
                onHoveredChanged: {
                    if (card.hovered && card.fadingOut) {
                        fadeOutAnim.stop();
                        card.fadingOut = false;
                        card.opacity = 1;
                    }
                }

                Timer {
                    interval: Notifs.timeoutFor(card.notification) * 1000
                    running: interval > 0 && !card.hovered && !card.fadingOut
                    onTriggered: {
                        card.fadingOut = true;
                        fadeOutAnim.start();
                    }
                }

                NumberAnimation {
                    id: fadeOutAnim
                    target: card
                    property: "opacity"
                    to: 0
                    duration: 360
                    easing.type: Easing.InCubic
                    onFinished: {
                        if (card.fadingOut)
                            Notifs.toastTimedOut(card.notification);
                    }
                }
            }
        }
    }
}
