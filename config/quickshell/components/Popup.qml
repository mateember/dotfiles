import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

// Themed popup for a bar module.
// - Clicked on the bar (`Popups.open` / `Popups.toggle`): opens as a layer-shell dropdown
//   below the bar button with HyprlandFocusGrab.
// - Launched from the Launcher (`Popups.openWindow`): opens as a real Wayland window
//   (`FloatingWindow`, title "HCS — <Name>"), floated and centered by Hyprland window rules.
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
    readonly property bool openDropdown: open && !Popups.asWindow
    readonly property bool openAsWindow: open && Popups.asWindow

    function toggle() { Popups.toggle(popupId); }
    function close() { if (root.open) Popups.close(); }

    // Horizontal position: centered under the button (or screen-centered if hidden), kept on screen.
    // Computed reactively from the RowLayout + Loader + BarButton x/width in Bar.qml so it is
    // always up-to-date before the popup maps on Wayland.
    readonly property int popupWidth: contentWidth + 2 * padding
    readonly property real anchorCenter: {
        const loader = anchorItem?.parent;
        const row = loader?.parent;
        if (!anchorItem || !loader || !loader.visible)
            return (screen?.width ?? 1000) / 2;
        return Theme.panelMargin
             + (row?.x ?? 0)
             + loader.x
             + anchorItem.x
             + anchorItem.width / 2;
    }
    onOpenChanged: if (open) bg.forceActiveFocus()

    screen: barWindow?.screen ?? null
    visible: openDropdown
    color: "transparent"

    anchors.top: true
    anchors.left: true
    margins.top: Theme.panelMargin + Theme.barHeight + Theme.popupGap
    margins.left: Popups.fromQuickSettings
        ? Math.max(Theme.panelMargin, (screen?.width ?? 0) - popupWidth - Theme.panelMargin)
        : Math.max(Theme.panelMargin, Math.min((screen?.width ?? 0) - popupWidth - Theme.panelMargin, anchorCenter - popupWidth / 2))
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    implicitWidth: popupWidth
    // Never taller than the screen below the bar.
    implicitHeight: Math.min(body.implicitHeight + 2 * padding,
                             (screen?.height ?? 1000) - margins.top - Theme.spaceL)

    WlrLayershell.namespace: "hcs-popup"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: openDropdown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: root.openDropdown
        windows: root.barWindow ? [root, root.barWindow] : [root]
        onCleared: if (root.openDropdown) root.close()
    }

    // Real Wayland XDG window when launched from the Launcher (`!`).
    FloatingWindow {
        id: floatWin
        title: "HCS — " + root.name.charAt(0).toUpperCase() + root.name.slice(1)
        visible: root.openAsWindow
        readonly property int targetW: root.contentWidth + 2 * root.padding
        readonly property int targetH: Math.max(120, Math.min(Math.ceil(body.implicitHeight) + 2 * root.padding, 740))
        implicitWidth: targetW
        implicitHeight: targetH
        minimumSize: Qt.size(targetW, targetH)
        maximumSize: Qt.size(targetW, targetH)
        color: "transparent"
        onClosed: root.close()
    }

    Rectangle {
        id: bg
        parent: root.openAsWindow ? floatWin.contentItem : root.contentItem
        anchors.fill: parent
        radius: root.openAsWindow ? 0 : Theme.radiusM
        color: Theme.popupBg
        border.color: Theme.popupBorder
        border.width: root.openAsWindow ? 0 : 1
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
