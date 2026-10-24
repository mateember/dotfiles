import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

// Themed dropdown below a bar button.
// Implemented as its own layer-shell surface (not an xdg popup): Hyprland routes clicks
// and keyboard focus to layer surfaces reliably, so clicks inside never fall through to
// the window underneath. HyprlandFocusGrab closes it on a click outside.
//
// Usage inside a bar module:
//   BarButton { id: btn; active: pop.open; onClicked: pop.toggle()
//       Popup { id: pop; name: "volume"; anchorItem: btn; ...content... } }
// Content children are stacked in a ColumnLayout.
PanelWindow {
    id: root

    required property Item anchorItem
    required property string name
    default property alias content: body.data
    property int padding: Theme.spaceS
    property int contentWidth: Theme.popupWidth - 2 * padding

    readonly property var barWindow: anchorItem.QsWindow.window
    readonly property string popupId: name + "@" + (barWindow?.screen?.name ?? "")
    readonly property bool open: Popups.current === popupId

    function toggle() { Popups.toggle(popupId); }
    function close() { if (root.open) Popups.close(); }

    // Horizontal position: centered under the button (or screen-centered if the bar item is hidden), kept on screen.
    property real anchorCenter: 0
    function reposition() {
        if (!barWindow) return;
        if (!anchorItem.visible) {
            anchorCenter = (screen?.width ?? 1000) / 2;
            return;
        }
        const r = barWindow.itemRect(anchorItem);
        anchorCenter = Theme.panelMargin + r.x + r.width / 2;
    }
    onOpenChanged: if (open) reposition()

    screen: barWindow?.screen ?? null
    visible: open
    color: "transparent"

    anchors.top: true
    anchors.left: true
    margins.top: Theme.panelMargin + Theme.barHeight + Theme.popupGap
    margins.left: Math.max(Theme.panelMargin, Math.min((screen?.width ?? 0) - width - Theme.panelMargin, anchorCenter - width / 2))
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    implicitWidth: contentWidth + 2 * padding
    // Never taller than the screen below the bar.
    implicitHeight: Math.min(body.implicitHeight + 2 * padding,
                             (screen?.height ?? 1000) - margins.top - Theme.spaceL)

    WlrLayershell.namespace: "hcs-popup"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: root.visible
        windows: root.barWindow ? [root, root.barWindow] : [root]
        onCleared: root.close()
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.radiusM
        color: Theme.popupBg
        border.color: Theme.popupBorder
        border.width: 1
        clip: true
        focus: true
        Keys.onEscapePressed: root.close()

        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        ColumnLayout {
            id: body
            x: root.padding
            y: root.padding
            width: root.contentWidth
            spacing: Theme.spaceXs
        }
    }
}
