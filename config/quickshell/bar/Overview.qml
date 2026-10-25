import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// KDE Plasma-style Overview (SUPER+Tab / SUPER+W / 4-finger swipe up/down / `qs ipc call overview toggle`):
//   - Top row: horizontal strip of virtual desktops (workspaces) with live miniature window previews
//     and a "+ New Desktop" card. Click a desktop to inspect its windows, click again (or double-click)
//     to switch to it.
//   - Middle: search bar to filter open windows across all workspaces by title or app class.
//   - Main area: exposed grid of live window thumbnails (ScreencopyView) with app icon, title,
//     move-to-workspace buttons (← / →), and close button (×).
Scope {
    id: root

    property real animProgress: Hypr.overviewProgress
    Behavior on animProgress {
        enabled: !Hypr.overviewSwiping
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    LazyLoader {
        active: Hypr.overviewOpen || Hypr.overviewSwiping || root.animProgress > 0.005

        PanelWindow {
            id: win

            screen: {
                const mon = Hyprland.focusedMonitor;
                if (mon) {
                    for (const s of Quickshell.screens)
                        if (s.name === mon.name) return s;
                }
                return Quickshell.screens[0];
            }

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.namespace: "hcs-overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (Hypr.overviewOpen || Hypr.overviewSwiping) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.exclusiveZone: -1

        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(win.screen)
        property int selectedWsId: Hyprland.focusedWorkspace?.id ?? monitor?.activeWorkspace?.id ?? 1
        property bool showAllWorkspaces: false
        property string query: ""
        property int selectedIndex: 0

        // Sorted workspace IDs on this monitor (always includes the active & selected workspace).
        readonly property var workspaceIds: {
            const set = {};
            const activeId = monitor?.activeWorkspace?.id ?? Hyprland.focusedWorkspace?.id ?? 1;
            set[activeId] = true;
            if (selectedWsId > 0) set[selectedWsId] = true;
            for (const w of Hyprland.workspaces.values) {
                if (w.id > 0 && (!w.monitor || !monitor || w.monitor.id === monitor.id))
                    set[w.id] = true;
            }
            const list = Object.keys(set).map(k => Number(k)).sort((a, b) => a - b);
            return list.length > 0 ? list : [1];
        }

        readonly property int nextNewWsId: {
            let max = 0;
            for (const w of Hyprland.workspaces.values)
                if (w.id > max) max = w.id;
            for (const id of workspaceIds)
                if (id > max) max = id;
            return max + 1;
        }

        // All mapped toplevels on this monitor (excluding special workspaces unless active).
        readonly property var monitorToplevels: {
            const out = [];
            for (const t of Hyprland.toplevels.values) {
                const wsId = t.workspace?.id ?? 0;
                if (wsId <= 0) continue;
                if (t.monitor && monitor && t.monitor.id !== monitor.id) continue;
                out.push(t);
            }
            return out;
        }

        function toplevelsForWorkspace(wsId: int): var {
            return monitorToplevels.filter(t => (t.workspace?.id ?? 0) === wsId);
        }

        function appNameFor(t): string {
            return t?.wayland?.appId || t?.lastIpcObject?.class || t?.lastIpcObject?.initialClass || "Window";
        }

        function iconFor(t): string {
            const appId = t?.wayland?.appId || t?.lastIpcObject?.class || "";
            if (!appId) return "";
            const entry = DesktopEntries.byId(appId) ?? DesktopEntries.heuristicLookup(appId);
            const iconName = entry?.icon || appId;
            return Quickshell.iconPath(iconName, true) || Quickshell.iconPath(appId.toLowerCase(), true) || "";
        }

        // Windows shown in the main Present Windows grid.
        readonly property var filteredToplevels: {
            const q = query.trim().toLowerCase();
            const showAll = showAllWorkspaces || q.length > 0;
            return monitorToplevels.filter(t => {
                if (!showAll && (t.workspace?.id ?? 0) !== selectedWsId)
                    return false;
                if (!q) return true;
                const title = (t.title ?? "").toLowerCase();
                const app = appNameFor(t).toLowerCase();
                return title.includes(q) || app.includes(q);
            });
        }

        onFilteredToplevelsChanged: {
            if (selectedIndex >= filteredToplevels.length)
                selectedIndex = Math.max(0, filteredToplevels.length - 1);
        }

        function close() {
            Hypr.closeOverview();
        }

        function activateToplevel(t) {
            if (!t) return;
            const wsId = t.workspace?.id ?? 0;
            if (wsId > 0) Hypr.focusWorkspace(wsId);
            if (t.wayland) t.wayland.activate();
            if (t.address) Hypr.focusWindow(t.address);
            win.close();
        }

        function switchToWorkspace(wsId: int) {
            Hypr.focusWorkspace(wsId);
            win.close();
        }

        Shortcut {
            sequences: ["Escape"]
            onActivated: win.close()
        }

        Connections {
            target: Hypr
            function onOverviewOpenChanged() {
                if (Hypr.overviewOpen) {
                    focusTimer.restart();
                }
            }
        }

        Timer {
            id: focusTimer
            interval: 30
            onTriggered: searchInput.forceActiveFocus()
        }

        Component.onCompleted: {
            Popups.close();
            QuickSettingsState.close();
            Hyprland.refreshMonitors();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
            win.selectedWsId = Hyprland.focusedWorkspace?.id ?? win.monitor?.activeWorkspace?.id ?? 1;
            searchInput.forceActiveFocus();
            focusTimer.restart();
        }

        // Dimmed backdrop; clicking empty space closes the Overview.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.06, 0.06, 0.07, 0.78 * root.animProgress)

            MouseArea {
                anchors.fill: parent
                onClicked: win.close()
            }
        }

        Item {
            id: slideContainer
            anchors.fill: parent
            opacity: root.animProgress
            transform: [
                Scale {
                    origin.x: slideContainer.width / 2
                    origin.y: slideContainer.height / 2
                    xScale: 0.94 + 0.06 * root.animProgress
                    yScale: 0.94 + 0.06 * root.animProgress
                },
                Translate {
                    y: (1.0 - root.animProgress) * 180
                }
            ]

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: Theme.barHeight + Theme.spaceM
                anchors.bottomMargin: Theme.spaceL
                anchors.leftMargin: Theme.spaceXl
                anchors.rightMargin: Theme.spaceXl
                spacing: Theme.spaceM

            // =================================================================
            // 1. TOP STRIP: Virtual Desktops (Workspaces) like KDE Plasma
            // =================================================================
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.spaceS

                Repeater {
                    model: win.workspaceIds

                    delegate: Rectangle {
                        id: wsCard
                        required property int modelData
                        readonly property int wsId: modelData
                        readonly property bool isCurrentHypr: (Hyprland.focusedWorkspace?.id ?? 0) === wsId
                        readonly property bool isSelected: !win.showAllWorkspaces && win.selectedWsId === wsId
                        readonly property var wsWindows: win.toplevelsForWorkspace(wsId)

                        implicitWidth: 210
                        implicitHeight: 132
                        radius: Theme.radiusM
                        color: isSelected ? Qt.rgba(1, 0.68, 0, 0.14)
                             : (wsHover.containsMouse ? Theme.componentHover : Theme.overviewBg)
                        border.width: isSelected ? 2 : 1
                        border.color: isSelected ? Theme.accent
                                    : (isCurrentHypr ? Qt.rgba(1, 0.68, 0, 0.55) : Theme.panelBorder)

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            // Desktop header
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: wsCard.isCurrentHypr ? Theme.accent : Theme.component
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: String(wsCard.wsId)
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        font.weight: Font.Bold
                                        color: wsCard.isCurrentHypr ? Theme.accentText : Theme.text
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: "Desktop " + wsCard.wsId
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: wsCard.isSelected ? Font.DemiBold : Font.Normal
                                    color: wsCard.isSelected ? Theme.text : Theme.textDim
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: wsCard.wsWindows.length > 0 ? String(wsCard.wsWindows.length) : ""
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.textDim
                                }
                            }

                            // Miniature live preview box
                            ClippingRectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.radiusS
                                color: Qt.rgba(0.11, 0.11, 0.12, 0.9)

                                StyledText {
                                    anchors.centerIn: parent
                                    visible: wsCard.wsWindows.length === 0
                                    text: "Empty"
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.textDim
                                }

                                GridLayout {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    visible: wsCard.wsWindows.length > 0
                                    columns: wsCard.wsWindows.length <= 1 ? 1 : 2
                                    rowSpacing: 3
                                    columnSpacing: 3

                                    Repeater {
                                        model: wsCard.wsWindows.slice(0, 4)

                                        delegate: ClippingRectangle {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            radius: 4
                                            color: Theme.component

                                            ScreencopyView {
                                                anchors.fill: parent
                                                captureSource: modelData?.wayland ?? null
                                                live: true
                                                paintCursor: false
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: wsHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.MiddleButton || (win.selectedWsId === wsCard.wsId && !win.showAllWorkspaces)) {
                                    win.switchToWorkspace(wsCard.wsId);
                                } else {
                                    win.showAllWorkspaces = false;
                                    win.selectedWsId = wsCard.wsId;
                                    win.selectedIndex = 0;
                                    searchInput.forceActiveFocus();
                                }
                            }
                            onDoubleClicked: win.switchToWorkspace(wsCard.wsId)
                        }
                    }
                }

                // "+ New Desktop" card
                Rectangle {
                    implicitWidth: 120
                    implicitHeight: 132
                    radius: Theme.radiusM
                    color: newWsHover.containsMouse ? Theme.componentHover : Theme.overviewBg
                    border.width: 1
                    border.color: Theme.panelBorder

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Icon {
                            Layout.alignment: Qt.AlignHCenter
                            icon: "add_circle"
                            size: 28
                            color: Theme.accent
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "New Desktop"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textDim
                        }
                    }

                    MouseArea {
                        id: newWsHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.switchToWorkspace(win.nextNewWsId)
                    }
                }
            }

            // =================================================================
            // 2. SEARCH & FILTER BAR
            // =================================================================
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.spaceS

                Rectangle {
                    implicitWidth: 460
                    implicitHeight: 42
                    radius: 21
                    color: Theme.overviewBg
                    border.width: searchInput.activeFocus ? 2 : 1
                    border.color: searchInput.activeFocus ? Theme.accent : Theme.panelBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spaceS
                        anchors.rightMargin: Theme.spaceS
                        spacing: Theme.spaceXs

                        Icon { icon: "search"; size: 20; color: Theme.textDim }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.accentText
                            clip: true
                            onTextChanged: {
                                win.query = text;
                                win.selectedIndex = 0;
                            }

                            Keys.onPressed: event => {
                                const count = win.filteredToplevels.length;
                                if (event.key === Qt.Key_Escape) {
                                    win.close();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (count > 0 && win.selectedIndex >= 0 && win.selectedIndex < count) {
                                        win.activateToplevel(win.filteredToplevels[win.selectedIndex]);
                                    } else {
                                        win.switchToWorkspace(win.selectedWsId);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                                    if (event.modifiers & Qt.ControlModifier) {
                                        const idx = win.workspaceIds.indexOf(win.selectedWsId);
                                        if (idx >= 0 && idx + 1 < win.workspaceIds.length)
                                            win.selectedWsId = win.workspaceIds[idx + 1];
                                    } else if (count > 0) {
                                        win.selectedIndex = (win.selectedIndex + 1) % count;
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                                    if (event.modifiers & Qt.ControlModifier) {
                                        const idx = win.workspaceIds.indexOf(win.selectedWsId);
                                        if (idx > 0)
                                            win.selectedWsId = win.workspaceIds[idx - 1];
                                    } else if (count > 0) {
                                        win.selectedIndex = (win.selectedIndex - 1 + count) % count;
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    const cols = Math.max(1, windowGrid.columns);
                                    if (count > 0)
                                        win.selectedIndex = Math.min(count - 1, win.selectedIndex + cols);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    const cols = Math.max(1, windowGrid.columns);
                                    if (count > 0)
                                        win.selectedIndex = Math.max(0, win.selectedIndex - cols);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_PageDown) {
                                    const idx = win.workspaceIds.indexOf(win.selectedWsId);
                                    if (idx >= 0 && idx + 1 < win.workspaceIds.length)
                                        win.selectedWsId = win.workspaceIds[idx + 1];
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_PageUp) {
                                    const idx = win.workspaceIds.indexOf(win.selectedWsId);
                                    if (idx > 0)
                                        win.selectedWsId = win.workspaceIds[idx - 1];
                                    event.accepted = true;
                                }
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !searchInput.text
                                text: "Search windows (Enter focus, Ctrl+←/→ desktop, Esc close)..."
                                color: Theme.textDim
                            }
                        }

                        IconButton {
                            visible: searchInput.text !== ""
                            icon: "close"
                            implicitWidth: 26
                            implicitHeight: 26
                            iconSize: 16
                            onClicked: searchInput.text = ""
                        }
                    }
                }

                // Toggle "All Desktops" vs selected desktop
                Rectangle {
                    implicitWidth: allRow.implicitWidth + 24
                    implicitHeight: 42
                    radius: 21
                    color: win.showAllWorkspaces ? Theme.accent : (allHover.containsMouse ? Theme.componentHover : Theme.overviewBg)
                    border.width: 1
                    border.color: win.showAllWorkspaces ? Theme.accent : Theme.panelBorder

                    RowLayout {
                        id: allRow
                        anchors.centerIn: parent
                        spacing: 6
                        Icon {
                            icon: "grid_view"
                            size: 18
                            color: win.showAllWorkspaces ? Theme.accentText : Theme.text
                        }
                        StyledText {
                            text: "All Desktops"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: win.showAllWorkspaces ? Font.DemiBold : Font.Normal
                            color: win.showAllWorkspaces ? Theme.accentText : Theme.text
                        }
                    }

                    MouseArea {
                        id: allHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.showAllWorkspaces = !win.showAllWorkspaces;
                            win.selectedIndex = 0;
                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }

            // =================================================================
            // 3. MAIN AREA: Exposed Windows Grid (Present Windows)
            // =================================================================
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Empty state when the selected workspace has no open windows
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: win.filteredToplevels.length === 0
                    spacing: Theme.spaceS

                    Icon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: win.query.trim() !== "" ? "search_off" : "desktop_windows"
                        size: 48
                        color: Theme.textDim
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: win.query.trim() !== ""
                            ? "No windows matching \"" + win.query + "\""
                            : "No open windows on Desktop " + win.selectedWsId
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.textDim
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        visible: win.query.trim() === "" && (Hyprland.focusedWorkspace?.id ?? 0) !== win.selectedWsId
                        implicitWidth: switchLbl.implicitWidth + 28
                        implicitHeight: 36
                        radius: 18
                        color: Theme.accent

                        StyledText {
                            id: switchLbl
                            anchors.centerIn: parent
                            text: "Switch to Desktop " + win.selectedWsId
                            font.weight: Font.DemiBold
                            color: Theme.accentText
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.switchToWorkspace(win.selectedWsId)
                        }
                    }
                }

                // Grid of live window thumbnails
                GridLayout {
                    id: windowGrid
                    anchors.fill: parent
                    visible: win.filteredToplevels.length > 0
                    columns: {
                        const n = win.filteredToplevels.length;
                        if (n <= 1) return 1;
                        if (n <= 4) return 2;
                        if (n <= 9) return 3;
                        return 4;
                    }
                    rowSpacing: Theme.spaceM
                    columnSpacing: Theme.spaceM

                    Repeater {
                        model: win.filteredToplevels

                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            required property int index

                            readonly property bool isHighlighted: index === win.selectedIndex || cardHover.containsMouse
                            readonly property int wsId: modelData?.workspace?.id ?? 1
                            readonly property string iconSource: win.iconFor(modelData)

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.maximumWidth: win.filteredToplevels.length === 1 ? 820 : 620
                            Layout.maximumHeight: win.filteredToplevels.length === 1 ? 520 : 400
                            Layout.alignment: Qt.AlignCenter

                            radius: Theme.radiusL
                            color: isHighlighted ? Qt.rgba(0.2, 0.2, 0.22, 0.92) : Theme.overviewBg
                            border.width: index === win.selectedIndex ? 2 : 1
                            border.color: index === win.selectedIndex ? Theme.accent
                                        : (cardHover.containsMouse ? Qt.rgba(1, 1, 1, 0.35) : Theme.panelBorder)

                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spaceXs
                                spacing: Theme.spaceXs

                                // Live window thumbnail
                                ClippingRectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Theme.radiusM
                                    color: Qt.rgba(0.09, 0.09, 0.1, 1)

                                    ScreencopyView {
                                        id: preview
                                        anchors.fill: parent
                                        captureSource: card.modelData?.wayland ?? null
                                        live: true
                                        paintCursor: false
                                    }

                                    // Fallback if screencopy isn't ready
                                    Icon {
                                        anchors.centerIn: parent
                                        visible: !preview.hasContent
                                        icon: "web_asset"
                                        size: 48
                                        color: Theme.textDim
                                    }

                                    MouseArea {
                                        id: cardHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: win.selectedIndex = card.index
                                        onClicked: win.activateToplevel(card.modelData)
                                    }
                                }

                                // Window footer: app icon, title, move-to-desktop buttons, close button
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spaceXs

                                    Image {
                                        visible: card.iconSource !== ""
                                        source: card.iconSource
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        sourceSize.width: 44
                                        sourceSize.height: 44
                                        asynchronous: true
                                    }

                                    Icon {
                                        visible: card.iconSource === ""
                                        icon: "web_asset"
                                        size: 20
                                        color: Theme.accent
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: card.modelData?.title || win.appNameFor(card.modelData)
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: win.appNameFor(card.modelData) + "  ·  Desktop " + card.wsId
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Theme.textDim
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Move window to previous workspace
                                    IconButton {
                                        icon: "chevron_left"
                                        implicitWidth: 28
                                        implicitHeight: 28
                                        iconSize: 18
                                        enabled: card.wsId > 1
                                        onClicked: {
                                            if (card.modelData?.address && card.wsId > 1) {
                                                Hypr.moveWindowToWorkspace(card.modelData.address, card.wsId - 1, false);
                                                Hyprland.refreshWorkspaces();
                                                Hyprland.refreshToplevels();
                                            }
                                        }
                                    }

                                    // Move window to next workspace
                                    IconButton {
                                        icon: "chevron_right"
                                        implicitWidth: 28
                                        implicitHeight: 28
                                        iconSize: 18
                                        onClicked: {
                                            if (card.modelData?.address) {
                                                Hypr.moveWindowToWorkspace(card.modelData.address, card.wsId + 1, false);
                                                Hyprland.refreshWorkspaces();
                                                Hyprland.refreshToplevels();
                                            }
                                        }
                                    }

                                    // Close window
                                    IconButton {
                                        icon: "close"
                                        implicitWidth: 28
                                        implicitHeight: 28
                                        iconSize: 18
                                        onClicked: {
                                            if (card.modelData?.wayland) card.modelData.wayland.close();
                                            else if (card.modelData?.address) Hypr.closeWindow(card.modelData.address);
                                            searchInput.forceActiveFocus();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        }
    }
    }
}
