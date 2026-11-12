import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// Niri-style vertical workspace Overview (SUPER+Tab / SUPER+W / 4-finger swipe / `qs ipc call overview toggle`).
// Workspaces are stacked vertically with live window columns arranged horizontally inside each strip.
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
            mask: (Hypr.overviewOpen || Hypr.overviewSwiping) ? fullMask : emptyMask

            Region { id: emptyMask }
            Region { id: fullMask; item: slideContainer }

            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(win.screen)
            readonly property real monLogicalW: (monitor && monitor.width > 0 && monitor.scale > 0) ? (monitor.width / monitor.scale) : 1440
            readonly property real monLogicalH: (monitor && monitor.height > 0 && monitor.scale > 0) ? (monitor.height / monitor.scale) : 900

            property int selectedWsId: Hyprland.focusedWorkspace?.id ?? monitor?.activeWorkspace?.id ?? 1
            property int selectedWinIdx: 0
            property string query: ""

            // Sorted positive workspace IDs on this monitor.
            readonly property var workspaceIds: {
                const set = {};
                const activeId = monitor?.activeWorkspace?.id ?? Hyprland.focusedWorkspace?.id ?? 1;
                if (activeId > 0) set[activeId] = true;
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

            // All mapped non-special toplevels on this monitor.
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

            function matchesQuery(t, q: string): bool {
                if (!q) return true;
                const title = (t?.title ?? "").toLowerCase();
                const app = appNameFor(t).toLowerCase();
                return title.includes(q) || app.includes(q);
            }

            // Group workspace toplevels into scrolling-strip columns (preserving column order & stacked windows).
            function buildWorkspaceColumns(wsId: int, q: string): var {
                const items = [];
                let fallbackIdx = 0;
                for (const t of monitorToplevels) {
                    if ((t.workspace?.id ?? 0) !== wsId) continue;
                    if (!matchesQuery(t, q)) continue;
                    const ipc = t.lastIpcObject;
                    const x = (ipc && ipc.at && ipc.at.length >= 2) ? Number(ipc.at[0]) : (fallbackIdx * 1000);
                    const y = (ipc && ipc.at && ipc.at.length >= 2) ? Number(ipc.at[1]) : 0;
                    const w = (ipc && ipc.size && ipc.size.length >= 2) ? Number(ipc.size[0]) : win.monLogicalW * 0.5;
                    const floating = Boolean(ipc && ipc.floating);
                    items.push({ toplevel: t, x: x, y: y, w: w, floating: floating, seq: fallbackIdx++ });
                }

                items.sort((a, b) => {
                    if (a.floating !== b.floating) return a.floating ? 1 : -1;
                    if (Math.abs(a.x - b.x) > 24) return a.x - b.x;
                    if (a.y !== b.y) return a.y - b.y;
                    return a.seq - b.seq;
                });

                const columns = [];
                for (const item of items) {
                    const ratio = Math.max(0.32, Math.min(1.0, item.w / win.monLogicalW));
                    if (!item.floating && columns.length > 0 && !columns[columns.length - 1].floating && Math.abs(item.x - columns[columns.length - 1].x) <= 24) {
                        const col = columns[columns.length - 1];
                        col.windows.push({ toplevel: item.toplevel, flatIndex: 0 });
                        col.colWidthRatio = Math.max(col.colWidthRatio, ratio);
                    } else {
                        columns.push({
                            x: item.x,
                            floating: item.floating,
                            colWidthRatio: ratio,
                            windows: [{ toplevel: item.toplevel, flatIndex: 0 }]
                        });
                    }
                }

                const flatWindows = [];
                for (const col of columns) {
                    for (const wItem of col.windows) {
                        wItem.flatIndex = flatWindows.length;
                        flatWindows.push(wItem.toplevel);
                    }
                }
                return { columns: columns, flatWindows: flatWindows };
            }

            // Vertical list of workspace strips (includes a trailing empty workspace when not searching).
            readonly property var workspaceModels: {
                const q = query.trim().toLowerCase();
                const out = [];
                for (const id of workspaceIds) {
                    const built = buildWorkspaceColumns(id, q);
                    if (q.length > 0 && built.flatWindows.length === 0) continue;
                    out.push({
                        wsId: id,
                        isNew: false,
                        columns: built.columns,
                        flatWindows: built.flatWindows
                    });
                }
                if (q.length === 0) {
                    out.push({
                        wsId: nextNewWsId,
                        isNew: true,
                        columns: [],
                        flatWindows: []
                    });
                }
                return out;
            }

            readonly property int selectedWsRowIdx: {
                for (let i = 0; i < workspaceModels.length; i++) {
                    if (workspaceModels[i].wsId === selectedWsId) return i;
                }
                return 0;
            }

            onWorkspaceModelsChanged: {
                if (workspaceModels.length === 0) {
                    selectedWinIdx = 0;
                    return;
                }
                let found = null;
                for (const m of workspaceModels) {
                    if (m.wsId === selectedWsId) { found = m; break; }
                }
                if (!found) {
                    found = workspaceModels[0];
                    selectedWsId = found.wsId;
                    selectedWinIdx = 0;
                } else if (selectedWinIdx >= found.flatWindows.length) {
                    selectedWinIdx = Math.max(0, found.flatWindows.length - 1);
                }
            }

            function close() {
                Hypr.closeOverview();
            }

            function activateToplevel(t) {
                Hypr.activateWindow(t);
            }

            function switchToWorkspace(wsId: int) {
                Hypr.closeOverview();
                Hypr.focusWorkspace(wsId);
            }

            function moveWorkspaceSelection(delta: int) {
                const list = win.workspaceModels;
                if (list.length === 0) return;
                const nextIdx = Math.max(0, Math.min(list.length - 1, win.selectedWsRowIdx + delta));
                win.selectedWsId = list[nextIdx].wsId;
                win.selectedWinIdx = 0;
                wsList.positionViewAtIndex(nextIdx, ListView.Contain);
            }

            function moveWindowSelection(delta: int) {
                const list = win.workspaceModels;
                if (list.length === 0) return;
                const m = list[win.selectedWsRowIdx];
                if (!m || m.flatWindows.length === 0) return;
                const n = m.flatWindows.length;
                win.selectedWinIdx = (win.selectedWinIdx + delta + n) % n;
            }

            function activateCurrentSelection() {
                const list = win.workspaceModels;
                if (list.length === 0) return;
                const m = list[win.selectedWsRowIdx];
                if (!m) return;
                if (m.flatWindows.length > 0) {
                    const idx = Math.max(0, Math.min(m.flatWindows.length - 1, win.selectedWinIdx));
                    win.activateToplevel(m.flatWindows[idx]);
                } else {
                    win.switchToWorkspace(m.wsId);
                }
            }

            function resetForOpen() {
                Hyprland.refreshMonitors();
                Hyprland.refreshWorkspaces();
                Hyprland.refreshToplevels();
                win.query = "";
                searchInput.text = "";
                win.selectedWsId = Hyprland.focusedWorkspace?.id ?? win.monitor?.activeWorkspace?.id ?? 1;
                win.selectedWinIdx = 0;
                focusTimer.restart();
            }

            Shortcut {
                sequences: ["Escape"]
                onActivated: win.close()
            }

            Connections {
                target: Hypr
                function onOverviewOpenChanged() {
                    if (Hypr.overviewOpen) win.resetForOpen();
                }
            }

            Timer {
                id: focusTimer
                interval: 30
                onTriggered: {
                    searchInput.forceActiveFocus();
                    wsList.positionViewAtIndex(win.selectedWsRowIdx, ListView.Contain);
                }
            }

            Component.onCompleted: {
                Popups.close();
                QuickSettingsState.close();
                win.resetForOpen();
            }

            // Dimmed backdrop; clicking outside closes the Overview.
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
                        y: (1.0 - root.animProgress) * 160
                    }
                ]

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: Theme.barHeight + Theme.spaceM
                    anchors.bottomMargin: Theme.spaceL
                    anchors.leftMargin: Theme.spaceXl
                    anchors.rightMargin: Theme.spaceXl
                    spacing: Theme.spaceM

                    // Search pill
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Math.min(500, parent.width)
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
                                    win.selectedWinIdx = 0;
                                }

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Escape) {
                                        win.close();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        win.activateCurrentSelection();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown) {
                                        win.moveWorkspaceSelection(1);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_PageUp) {
                                        win.moveWorkspaceSelection(-1);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                                        win.moveWindowSelection(1);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                                        win.moveWindowSelection(-1);
                                        event.accepted = true;
                                    }
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    visible: !searchInput.text
                                    text: "Search windows (Enter switch, ↑/↓ workspace, ←/→ window, Esc close)..."
                                    color: Theme.textDim
                                    elide: Text.ElideRight
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

                    // Empty search state
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: win.workspaceModels.length === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Theme.spaceS

                            Icon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: "search_off"
                                size: 48
                                color: Theme.textDim
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: "No windows matching \"" + win.query + "\""
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.textDim
                            }
                        }
                    }

                    // Vertical stack of workspace strips (Niri-style)
                    ListView {
                        id: wsList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: win.workspaceModels.length > 0
                        orientation: ListView.Vertical
                        spacing: Theme.spaceM
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: win.workspaceModels

                        readonly property int rowHeight: Math.max(196, Math.min(280, Math.floor((height - 2 * Theme.spaceM) / 2.55)))

                        delegate: Item {
                            id: wsRowItem
                            required property var modelData
                            required property int index

                            width: wsList.width
                            height: wsRowItem.modelData.isNew && win.query.trim() === ""
                                ? Math.min(116, wsList.rowHeight)
                                : wsList.rowHeight

                            readonly property int wsId: modelData.wsId
                            readonly property bool isNew: modelData.isNew
                            readonly property bool isCurrentHypr: !isNew && (Hyprland.focusedWorkspace?.id ?? 0) === wsId
                            readonly property bool isSelected: win.selectedWsId === wsId

                            Rectangle {
                                id: wsCard
                                width: Math.min(parent.width, 1360)
                                height: parent.height
                                anchors.horizontalCenter: parent.horizontalCenter
                                radius: Theme.radiusL
                                color: wsRowItem.isSelected ? Qt.rgba(1, 0.68, 0, 0.11)
                                     : (wsRowItem.isCurrentHypr ? Qt.rgba(1, 0.68, 0, 0.05)
                                     : (wsBgHover.containsMouse ? Theme.componentHover : Theme.overviewBg))
                                border.width: wsRowItem.isSelected ? 2 : 1
                                border.color: wsRowItem.isSelected ? Theme.accent
                                            : (wsRowItem.isCurrentHypr ? Qt.rgba(1, 0.68, 0, 0.48) : Theme.panelBorder)

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                                MouseArea {
                                    id: wsBgHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: win.selectedWsId = wsRowItem.wsId
                                    onClicked: win.switchToWorkspace(wsRowItem.wsId)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spaceS
                                    spacing: Theme.spaceS

                                    // Left workspace badge rail
                                    ColumnLayout {
                                        Layout.preferredWidth: 52
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 6

                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 30
                                            height: 30
                                            radius: 15
                                            color: wsRowItem.isCurrentHypr ? Theme.accent
                                                 : (wsRowItem.isSelected ? Theme.primaryComponent : Theme.component)
                                            border.width: wsRowItem.isSelected && !wsRowItem.isCurrentHypr ? 1 : 0
                                            border.color: Theme.accent

                                            Icon {
                                                anchors.centerIn: parent
                                                visible: wsRowItem.isNew
                                                icon: "add"
                                                size: 18
                                                color: Theme.accent
                                            }
                                            StyledText {
                                                anchors.centerIn: parent
                                                visible: !wsRowItem.isNew
                                                text: String(wsRowItem.wsId)
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Bold
                                                color: wsRowItem.isCurrentHypr ? Theme.accentText : Theme.text
                                            }
                                        }

                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: wsRowItem.isNew ? "New" : (wsRowItem.modelData.flatWindows.length + (wsRowItem.modelData.flatWindows.length === 1 ? " win" : " wins"))
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Theme.textDim
                                        }
                                    }

                                    // Vertical separator
                                    Rectangle {
                                        Layout.fillHeight: true
                                        Layout.topMargin: 4
                                        Layout.bottomMargin: 4
                                        width: 1
                                        color: Theme.panelBorder
                                    }

                                    // Horizontal scrolling strip of window columns
                                    Flickable {
                                        id: colStrip
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds
                                        contentWidth: Math.max(width, colRow.implicitWidth)
                                        contentHeight: height

                                        readonly property int basePreviewW: Math.max(200, Math.round(height * (win.monLogicalW / win.monLogicalH)))

                                        // Empty workspace / New workspace state
                                        RowLayout {
                                            anchors.centerIn: parent
                                            visible: wsRowItem.modelData.columns.length === 0
                                            spacing: Theme.spaceXs

                                            Icon {
                                                icon: wsRowItem.isNew ? "add_circle" : "desktop_windows"
                                                size: 24
                                                color: wsRowItem.isNew ? Theme.accent : Theme.textDim
                                            }
                                            StyledText {
                                                text: wsRowItem.isNew
                                                    ? "New workspace " + wsRowItem.wsId + " — click or press Enter"
                                                    : "Empty workspace — click or press Enter to switch"
                                                color: Theme.textDim
                                            }
                                        }

                                        Row {
                                            id: colRow
                                            x: implicitWidth < colStrip.width ? Math.round((colStrip.width - implicitWidth) / 2) : 0
                                            height: colStrip.height
                                            spacing: Theme.spaceS
                                            visible: wsRowItem.modelData.columns.length > 0

                                            Repeater {
                                                model: wsRowItem.modelData.columns

                                                delegate: Item {
                                                    id: colItem
                                                    required property var modelData
                                                    width: Math.max(180, Math.min(480, Math.round(colStrip.basePreviewW * modelData.colWidthRatio)))
                                                    height: colStrip.height

                                                    ColumnLayout {
                                                        anchors.fill: parent
                                                        spacing: Theme.spaceXxs

                                                        Repeater {
                                                            model: colItem.modelData.windows

                                                            delegate: Rectangle {
                                                                id: winCard
                                                                required property var modelData
                                                                readonly property var toplevel: modelData.toplevel
                                                                readonly property int flatIndex: modelData.flatIndex
                                                                readonly property bool isWinSelected: wsRowItem.isSelected && flatIndex === win.selectedWinIdx
                                                                readonly property string iconSource: win.iconFor(toplevel)
                                                                readonly property string addr: toplevel?.address || toplevel?.lastIpcObject?.address || ""
                                                                readonly property bool controlsVisible: isWinSelected || winHover.containsMouse

                                                                Layout.fillWidth: true
                                                                Layout.fillHeight: true
                                                                radius: Theme.radiusM
                                                                color: isWinSelected ? Qt.rgba(0.22, 0.22, 0.25, 0.94) : Qt.rgba(0.10, 0.10, 0.12, 0.92)
                                                                border.width: isWinSelected ? 2 : 1
                                                                border.color: isWinSelected ? Theme.accent
                                                                            : (winHover.containsMouse ? Qt.rgba(1, 1, 1, 0.42) : Theme.panelBorder)

                                                                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                                                                onIsWinSelectedChanged: {
                                                                    if (isWinSelected && colStrip.contentWidth > colStrip.width) {
                                                                        const p = winCard.mapToItem(colStrip.contentItem, 0, 0);
                                                                        if (p.x < colStrip.contentX)
                                                                            colStrip.contentX = Math.max(0, p.x);
                                                                        else if (p.x + winCard.width > colStrip.contentX + colStrip.width)
                                                                            colStrip.contentX = Math.min(colStrip.contentWidth - colStrip.width, p.x + winCard.width - colStrip.width);
                                                                    }
                                                                }

                                                                MouseArea {
                                                                    id: winHover
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onEntered: {
                                                                        win.selectedWsId = wsRowItem.wsId;
                                                                        win.selectedWinIdx = winCard.flatIndex;
                                                                    }
                                                                    onClicked: win.activateToplevel(winCard.toplevel)
                                                                }

                                                                ColumnLayout {
                                                                    anchors.fill: parent
                                                                    anchors.margins: 6
                                                                    spacing: 4

                                                                    ClippingRectangle {
                                                                        Layout.fillWidth: true
                                                                        Layout.fillHeight: true
                                                                        radius: Theme.radiusS
                                                                        color: Qt.rgba(0.08, 0.08, 0.09, 1)

                                                                        ScreencopyView {
                                                                            id: preview
                                                                            anchors.fill: parent
                                                                            captureSource: winCard.toplevel?.wayland ?? null
                                                                            live: true
                                                                            paintCursor: false
                                                                        }

                                                                        Icon {
                                                                            anchors.centerIn: parent
                                                                            visible: !preview.hasContent
                                                                            icon: "web_asset"
                                                                            size: 36
                                                                            color: Theme.textDim
                                                                        }
                                                                    }

                                                                    // Compact window footer
                                                                    RowLayout {
                                                                        Layout.fillWidth: true
                                                                        implicitHeight: 24
                                                                        spacing: 6

                                                                        Image {
                                                                            visible: winCard.iconSource !== ""
                                                                            source: winCard.iconSource
                                                                            Layout.preferredWidth: 16
                                                                            Layout.preferredHeight: 16
                                                                            sourceSize.width: 32
                                                                            sourceSize.height: 32
                                                                            asynchronous: true
                                                                        }

                                                                        Icon {
                                                                            visible: winCard.iconSource === ""
                                                                            icon: "web_asset"
                                                                            size: 16
                                                                            color: Theme.accent
                                                                        }

                                                                        StyledText {
                                                                            Layout.fillWidth: true
                                                                            text: winCard.toplevel?.title || win.appNameFor(winCard.toplevel)
                                                                            font.pixelSize: Theme.fontSizeSmall
                                                                            font.weight: winCard.isWinSelected ? Font.DemiBold : Font.Normal
                                                                            elide: Text.ElideRight
                                                                        }

                                                                        IconButton {
                                                                            visible: winCard.controlsVisible
                                                                            icon: "keyboard_arrow_up"
                                                                            implicitWidth: 22
                                                                            implicitHeight: 22
                                                                            iconSize: 15
                                                                            enabled: wsRowItem.wsId > 1
                                                                            onClicked: {
                                                                                if (winCard.addr && wsRowItem.wsId > 1) {
                                                                                    Hypr.moveWindowToWorkspace(winCard.addr, wsRowItem.wsId - 1, false);
                                                                                    Hyprland.refreshWorkspaces();
                                                                                    Hyprland.refreshToplevels();
                                                                                }
                                                                            }
                                                                        }

                                                                        IconButton {
                                                                            visible: winCard.controlsVisible
                                                                            icon: "keyboard_arrow_down"
                                                                            implicitWidth: 22
                                                                            implicitHeight: 22
                                                                            iconSize: 15
                                                                            onClicked: {
                                                                                if (winCard.addr) {
                                                                                    Hypr.moveWindowToWorkspace(winCard.addr, wsRowItem.wsId + 1, false);
                                                                                    Hyprland.refreshWorkspaces();
                                                                                    Hyprland.refreshToplevels();
                                                                                }
                                                                            }
                                                                        }

                                                                        IconButton {
                                                                            visible: winCard.controlsVisible
                                                                            icon: "close"
                                                                            implicitWidth: 22
                                                                            implicitHeight: 22
                                                                            iconSize: 15
                                                                            onClicked: {
                                                                                if (winCard.toplevel?.wayland) winCard.toplevel.wayland.close();
                                                                                else if (winCard.addr) Hypr.closeWindow(winCard.addr);
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
                        }
                    }
                }
            }
        }
    }
}
