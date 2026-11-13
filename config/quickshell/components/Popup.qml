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
    // Take keyboard focus as soon as the dropdown opens so Escape and keyboard navigation
    // work immediately without clicking inside first. Clicking outside still closes via the focus grab.
    property bool grabKeyboard: true
    // Optional key handler (event) => void, called before the built-in Escape handling.
    property var keyHandler: null
    // Optional () => bool handler for intra-widget subpages/prompts; return true to consume Escape/Back.
    property var backHandler: null

    // Latched presentation state so closing popups fade out in place instead of jumping
    // horizontally or flashing between window/dropdown modes while `bg.opacity > 0`.
    property bool latchedAsWindow: false
    property bool latchedFromQs: false
    property bool latchedCanGoBack: false
    property int latchedLeft: Theme.panelMargin
    property bool allowHeightAnim: false

    readonly property var barWindow: anchorItem.QsWindow.window
    readonly property string popupId: name + "@" + (barWindow?.screen?.name ?? "")
    readonly property bool open: Popups.current === popupId
    readonly property bool effectiveAsWindow: open ? Popups.asWindow : latchedAsWindow
    readonly property bool openDropdown: open && !Popups.asWindow
    readonly property bool openAsWindow: open && Popups.asWindow
    readonly property bool canGoBack: open ? WidgetHistory.canGoBack : (bg.opacity > 0 && latchedCanGoBack)

    function toggle() { Popups.toggle(popupId); }
    function back() {
        if (root.backHandler && root.backHandler()) {
            Qt.callLater(() => root.ensureFocus());
            return;
        }
        if (root.open) WidgetHistory.backFromPopup();
    }
    function close() { if (root.open) Popups.close(); }

    function hasFocusedDescendant(item: Item): bool {
        if (!item) return false;
        const kids = item.children;
        for (let i = 0; i < kids.length; i++) {
            const c = kids[i];
            if (c.activeFocus || hasFocusedDescendant(c)) return true;
        }
        return false;
    }

    function ensureFocus() {
        if (root.open && !bg.activeFocus && !hasFocusedDescendant(bg))
            bg.forceActiveFocus();
    }

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
    readonly property int liveLeft: (open ? Popups.fromQuickSettings : latchedFromQs)
        ? Math.max(Theme.panelMargin, (screen?.width ?? 0) - popupWidth - Theme.panelMargin)
        : Math.max(Theme.panelMargin, Math.min((screen?.width ?? 0) - popupWidth - Theme.panelMargin, Math.round(anchorCenter - popupWidth / 2)))

    onLiveLeftChanged: if (open) latchedLeft = liveLeft

    // Deferred so it runs after `bg` has been reparented into the floating window (window mode).
    onOpenChanged: {
        if (open) {
            latchedAsWindow = Popups.asWindow;
            latchedFromQs = Popups.fromQuickSettings;
            latchedCanGoBack = WidgetHistory.canGoBack;
            latchedLeft = liveLeft;
            Qt.callLater(() => {
                root.ensureFocus();
                if (root.openDropdown) root.allowHeightAnim = true;
            });
        } else {
            allowHeightAnim = false;
        }
    }

    Connections {
        target: Popups
        function onAsWindowChanged() { if (root.open) root.latchedAsWindow = Popups.asWindow; }
        function onFromQuickSettingsChanged() {
            if (root.open) {
                root.latchedFromQs = Popups.fromQuickSettings;
                root.latchedLeft = root.liveLeft;
            }
        }
    }

    Connections {
        target: WidgetHistory
        function onCanGoBackChanged() { if (root.open) root.latchedCanGoBack = WidgetHistory.canGoBack; }
    }

    screen: barWindow?.screen ?? null
    visible: openDropdown || (!effectiveAsWindow && bg.opacity > 0)
    color: "transparent"

    anchors.top: true
    anchors.left: true
    margins.top: Theme.panelMargin + Theme.barHeight + Theme.popupGap
    margins.left: root.open ? root.liveLeft : root.latchedLeft
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    readonly property int maxDropdownHeight: Math.max(120, (screen?.height ?? 1000) - margins.top - Theme.spaceL)

    implicitWidth: popupWidth
    // Keep the layer surface at fixed max height so shrinking popup content does not
    // resize zwlr_layer_surface_v1 (which triggers a compositor ghost/blur flash on Hyprland).
    implicitHeight: maxDropdownHeight

    WlrLayershell.namespace: "hcs-popup"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: !openDropdown ? WlrKeyboardFocus.None
        : grabKeyboard ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.OnDemand

    mask: !effectiveAsWindow && (openDropdown || bg.opacity > 0) ? bgMask : emptyMask
    Region { id: emptyMask }
    Region { id: bgMask; item: bg }

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
        onVisibleChanged: if (visible) Qt.callLater(() => root.ensureFocus())
        onClosed: root.close()
    }

    Rectangle {
        id: bg
        parent: root.effectiveAsWindow ? floatWin.contentItem : root.contentItem
        x: 0
        y: 0
        width: parent ? parent.width : root.popupWidth
        height: root.effectiveAsWindow
            ? (parent ? parent.height : floatWin.targetH)
            : Math.min(Math.ceil(body.implicitHeight) + 2 * root.padding, root.maxDropdownHeight)
        Behavior on height {
            enabled: !root.effectiveAsWindow && root.allowHeightAnim
            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
        }
        radius: root.effectiveAsWindow ? 0 : Theme.radiusM
        color: root.name === "notifications" ? Theme.notificationsBg : Theme.widgetsBg
        border.color: Theme.popupBorder
        border.width: root.effectiveAsWindow ? 0 : Theme.popupBorderWidth
        clip: true
        focus: true
        Keys.onPressed: e => { if (root.keyHandler) root.keyHandler(e); }
        Keys.onEscapePressed: root.back()

        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        ColumnLayout {
            id: body
            readonly property var popupRoot: root
            x: root.padding
            y: root.padding
            width: root.contentWidth
            spacing: Theme.spaceXs
        }
    }
}
