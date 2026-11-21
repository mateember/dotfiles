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
// Features: smooth fade-in/out, countdown progress bar (pauses on hover/drag/reply),
// horizontal drag/swipe-to-dismiss (touch + mouse), and inline reply keyboard focus.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Notifs.toasts.length > 0
    color: "transparent"

    property int activeReplyCount: 0

    anchors.top: true
    anchors.right: true
    margins.top: Theme.panelMargin + Theme.barHeight + Theme.popupGap
    margins.right: Theme.panelMargin
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    implicitWidth: 380
    // Keep the layer surface at fixed max height so dismissing one toast while others
    // stay does not shrink zwlr_layer_surface_v1 (ghost/blur flash on Hyprland).
    implicitHeight: Math.max(120, (screen?.height ?? 900) - margins.top - Theme.spaceL)

    WlrLayershell.namespace: "hcs-toast"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: activeReplyCount > 0 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: visible ? toastMask : emptyMask
    Region { id: emptyMask }
    Region { id: toastMask; item: column }

    ColumnLayout {
        id: column
        x: 0
        y: 0
        width: root.width
        spacing: Theme.spaceXs

        Repeater {
            model: Notifs.toasts

            delegate: Item {
                id: wrapper
                required property Notification modelData
                Layout.fillWidth: true
                implicitHeight: card.implicitHeight

                property real totalMs: Math.max(1000, Notifs.timeoutFor(wrapper.modelData) * 1000)
                property real elapsedMs: 0
                property bool fadingOut: false
                property bool swipedOut: false
                property bool dragging: swipeDrag.active
                readonly property bool paused: card.hovered || wrapper.dragging || card.replying || wrapper.fadingOut || wrapper.swipedOut

                Component.onCompleted: fadeInAnim.start()
                Component.onDestruction: {
                    if (card.replying) root.activeReplyCount = Math.max(0, root.activeReplyCount - 1);
                }

                NotificationCard {
                    id: card
                    width: parent.width
                    notification: wrapper.modelData
                    toast: true
                    showProgress: wrapper.totalMs > 0
                    progress: Math.max(0, 1.0 - (wrapper.elapsedMs / wrapper.totalMs))

                    // Fade smoothly as user drags horizontally
                    opacity: 0
                    transform: Translate { id: swipeTranslate; x: 0 }

                    onReplyingChanged: {
                        root.activeReplyCount = Math.max(0, root.activeReplyCount + (replying ? 1 : -1));
                    }

                    onHoveredChanged: {
                        if (card.hovered && wrapper.fadingOut && !wrapper.swipedOut) {
                            fadeOutAnim.stop();
                            wrapper.fadingOut = false;
                            wrapper.elapsedMs = Math.min(wrapper.elapsedMs, wrapper.totalMs * 0.75);
                            card.opacity = 1;
                        }
                    }

                    // Horizontal swipe/drag-to-dismiss (works with both touch and mouse)
                    DragHandler {
                        id: swipeDrag
                        target: null
                        yAxis.enabled: false
                        xAxis.enabled: true
                        grabPermissions: PointerHandler.CanTakeOverFromAnything

                        onTranslationChanged: {
                            if (!active || wrapper.swipedOut) return;
                            const dx = translation.x;
                            swipeTranslate.x = dx;
                            card.opacity = Math.max(0.15, 1.0 - Math.abs(dx) / (card.width * 0.72));
                        }

                        onActiveChanged: {
                            if (active || wrapper.swipedOut) return;
                            if (Math.abs(swipeTranslate.x) > 96) {
                                wrapper.swipedOut = true;
                                swipeDismissAnim.to = swipeTranslate.x >= 0 ? (card.width + 40) : -(card.width + 40);
                                swipeDismissAnim.start();
                            } else {
                                snapBackAnim.start();
                            }
                        }
                    }
                }

                ParallelAnimation {
                    id: fadeInAnim
                    NumberAnimation {
                        target: card
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: swipeTranslate
                        property: "x"
                        from: 24
                        to: 0
                        duration: 210
                        easing.type: Easing.OutCubic
                    }
                }

                ParallelAnimation {
                    id: snapBackAnim
                    NumberAnimation {
                        target: swipeTranslate
                        property: "x"
                        to: 0
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: card
                        property: "opacity"
                        to: 1
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                ParallelAnimation {
                    id: swipeDismissAnim
                    property alias to: slideOutX.to
                    NumberAnimation {
                        id: slideOutX
                        target: swipeTranslate
                        property: "x"
                        duration: 160
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: card
                        property: "opacity"
                        to: 0
                        duration: 160
                        easing.type: Easing.InCubic
                    }
                    onFinished: Notifs.toastTimedOut(wrapper.modelData)
                }

                // 50ms progress countdown tick; pauses cleanly on hover, drag, or inline reply
                Timer {
                    interval: 50
                    repeat: true
                    running: !wrapper.paused
                    onTriggered: {
                        wrapper.elapsedMs += 50;
                        if (wrapper.elapsedMs >= wrapper.totalMs) {
                            wrapper.fadingOut = true;
                            fadeOutAnim.start();
                        }
                    }
                }

                NumberAnimation {
                    id: fadeOutAnim
                    target: card
                    property: "opacity"
                    to: 0
                    duration: 340
                    easing.type: Easing.InCubic
                    onFinished: {
                        if (wrapper.fadingOut && !wrapper.swipedOut)
                            Notifs.toastTimedOut(wrapper.modelData);
                    }
                }
            }
        }
    }
}
