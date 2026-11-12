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

                const allColumns = [];
                let tiledColIdx = 0;
                for (const item of items) {
                    const ratio = Math.max(0.32, Math.min(1.0, item.w / win.monLogicalW));
                    if (!item.floating && allColumns.length > 0 && !allColumns[allColumns.length - 1].floating && Math.abs(item.x - allColumns[allColumns.length - 1].x) <= 24) {
                        const col = allColumns[allColumns.length - 1];
                        col.windows.push({ toplevel: item.toplevel, flatIndex: 0, realStackIdx: col.windows.length, floating: false });
                        col.colWidthRatio = Math.max(col.colWidthRatio, ratio);
                    } else {
                        allColumns.push({
                            x: item.x,
                            floating: item.floating,
                            realColIdx: item.floating ? -1 : tiledColIdx++,
                            colWidthRatio: ratio,
                            totalWindows: 1,
                            windows: [{ toplevel: item.toplevel, flatIndex: 0, realStackIdx: 0, floating: item.floating }]
                        });
                    }
                }

                const columns = [];
                for (const col of allColumns) {
                    col.totalWindows = col.windows.length;
                    const filteredWins = col.windows.filter(wItem => matchesQuery(wItem.toplevel, q));
                    if (filteredWins.length === 0) continue;
                    columns.push({
                        x: col.x,
                        floating: col.floating,
                        realColIdx: col.realColIdx,
                        colWidthRatio: col.colWidthRatio,
                        totalWindows: col.totalWindows,
                        windows: filteredWins
                    });
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

            property bool isDragging: false
            property var dragToplevel: null
            property string dragSrcAddr: ""
            property int dragSrcWsId: -1
            property int dragSrcColIdx: -1
            property int dragSrcStackIdx: -1
            property int dragSrcColSize: 1
            property bool dragSrcFloating: false
            property string dragTitle: ""
            property string dragIconSource: ""
            property real dragStartX: 0
            property real dragStartY: 0
            property real dragX: 0
            property real dragY: 0
            property real dragGhostW: 220
            property real dragGhostH: 140
            property real dragHotspotX: 110
            property real dragHotspotY: 70

            // Drop mode: "" | "workspace" | "column" | "stack" | "swap"
            property string dropMode: ""
            property int dropWsId: -1
            property int dropInsertCol: -1
            property int dropTargetCol: -1
            property int dropInsertStack: -1
            property real dropBarX: 0
            property real dropBarY: 0
            property string dropSwapAddr: ""
            property var hoveredColStrip: null

            function clearDropTarget() {
                win.dropMode = "";
                win.dropWsId = -1;
                win.dropInsertCol = -1;
                win.dropTargetCol = -1;
                win.dropInsertStack = -1;
                win.dropBarX = 0;
                win.dropBarY = 0;
                win.dropSwapAddr = "";
                win.hoveredColStrip = null;
            }

            function clearDragState() {
                win.isDragging = false;
                win.dragToplevel = null;
                win.dragSrcAddr = "";
                win.dragSrcWsId = -1;
                win.dragSrcColIdx = -1;
                win.dragSrcStackIdx = -1;
                win.dragSrcColSize = 1;
                win.dragSrcFloating = false;
                win.dragTitle = "";
                win.dragIconSource = "";
                win.clearDropTarget();
            }

            function startPendingDrag(toplevel, addr: string, wsId: int, colIdx: int, stackIdx: int, colSize: int, floating: bool, title: string, iconSrc: string, sx: real, sy: real, cardW: real, cardH: real, localX: real, localY: real) {
                win.isDragging = false;
                win.dragToplevel = toplevel;
                win.dragSrcAddr = addr;
                win.dragSrcWsId = wsId;
                win.dragSrcColIdx = colIdx;
                win.dragSrcStackIdx = stackIdx;
                win.dragSrcColSize = colSize;
                win.dragSrcFloating = floating;
                win.dragTitle = title;
                win.dragIconSource = iconSrc;
                win.dragStartX = sx;
                win.dragStartY = sy;
                win.dragX = sx;
                win.dragY = sy;
                const gw = Math.max(180, Math.min(270, cardW));
                const gh = Math.max(115, Math.min(175, cardH));
                win.dragGhostW = gw;
                win.dragGhostH = gh;
                win.dragHotspotX = cardW > 0 ? Math.max(20, Math.min(gw - 20, localX * (gw / cardW))) : gw / 2;
                win.dragHotspotY = cardH > 0 ? Math.max(16, Math.min(gh - 16, localY * (gh / cardH))) : gh / 2;
                win.clearDropTarget();
            }

            function updateDragPosition(sx: real, sy: real) {
                win.dragX = sx;
                win.dragY = sy;
                if (!win.isDragging && Math.hypot(sx - win.dragStartX, sy - win.dragStartY) >= 8)
                    win.isDragging = true;
                if (win.isDragging) win.updateDropTarget();
            }

            function updateDropTarget() {
                if (!win.isDragging) { win.clearDropTarget(); return; }
                const pWs = slideContainer.mapToItem(wsList, win.dragX, win.dragY);
                if (pWs.x < 0 || pWs.x > wsList.width || pWs.y < 0 || pWs.y > wsList.height) {
                    win.clearDropTarget();
                    return;
                }
                const pWsContent = slideContainer.mapToItem(wsList.contentItem, win.dragX, win.dragY);
                const rowItem = wsList.itemAt(pWsContent.x, pWsContent.y);
                if (!rowItem || !rowItem.wsCardItem) {
                    win.clearDropTarget();
                    return;
                }
                const pCard = slideContainer.mapToItem(rowItem.wsCardItem, win.dragX, win.dragY);
                if (pCard.x < 0 || pCard.x > rowItem.wsCardItem.width || pCard.y < 0 || pCard.y > rowItem.wsCardItem.height) {
                    win.clearDropTarget();
                    return;
                }

                const cols = rowItem.modelData.columns;
                if (rowItem.isNew || cols.length === 0) {
                    win.clearDropTarget();
                    if (rowItem.wsId !== win.dragSrcWsId) {
                        win.dropMode = "workspace";
                        win.dropWsId = rowItem.wsId;
                    }
                    return;
                }

                const strip = rowItem.colStripItem;
                const pStrip = slideContainer.mapToItem(strip, win.dragX, win.dragY);
                if (pStrip.x < 0 || pStrip.x > strip.width) {
                    win.clearDropTarget();
                    if (rowItem.wsId !== win.dragSrcWsId) {
                        win.dropMode = "workspace";
                        win.dropWsId = rowItem.wsId;
                    }
                    return;
                }

                win.hoveredColStrip = strip;

                if (Hypr.layout !== "scrolling" || win.dragSrcFloating) {
                    if (!win.dragSrcFloating && rowItem.colRepeaterItem) {
                        for (let ci = 0; ci < rowItem.colRepeaterItem.count; ci++) {
                            const colItem = rowItem.colRepeaterItem.itemAt(ci);
                            if (!colItem || !colItem.winRepeaterItem) continue;
                            for (let wi = 0; wi < colItem.winRepeaterItem.count; wi++) {
                                const wCard = colItem.winRepeaterItem.itemAt(wi);
                                if (!wCard) continue;
                                const pWin = slideContainer.mapToItem(wCard, win.dragX, win.dragY);
                                if (pWin.x >= 0 && pWin.x <= wCard.width && pWin.y >= 0 && pWin.y <= wCard.height) {
                                    if (wCard.addr && wCard.addr !== win.dragSrcAddr && !colItem.modelData.floating) {
                                        win.clearDropTarget();
                                        win.hoveredColStrip = strip;
                                        win.dropMode = "swap";
                                        win.dropWsId = rowItem.wsId;
                                        win.dropSwapAddr = wCard.addr;
                                        return;
                                    }
                                }
                            }
                        }
                    }
                    win.clearDropTarget();
                    win.hoveredColStrip = strip;
                    if (rowItem.wsId !== win.dragSrcWsId) {
                        win.dropMode = "workspace";
                        win.dropWsId = rowItem.wsId;
                    }
                    return;
                }

                const pRow = slideContainer.mapToItem(rowItem.colRowItem, win.dragX, win.dragY);

                // Vertical reorder inside the dragged window's own stacked column.
                if (rowItem.wsId === win.dragSrcWsId && win.dragSrcColSize > 1 && rowItem.colRepeaterItem) {
                    for (let ci = 0; ci < rowItem.colRepeaterItem.count; ci++) {
                        const colItem = rowItem.colRepeaterItem.itemAt(ci);
                        if (!colItem || colItem.modelData.realColIdx !== win.dragSrcColIdx || !colItem.winRepeaterItem) continue;
                        if (pRow.x >= colItem.x + 18 && pRow.x <= colItem.x + colItem.width - 18 && colItem.winRepeaterItem.count > 1) {
                            const pCol = slideContainer.mapToItem(colItem, win.dragX, win.dragY);
                            let insertStack = colItem.winRepeaterItem.count;
                            let barY = 0;
                            for (let wi = 0; wi < colItem.winRepeaterItem.count; wi++) {
                                const wCard = colItem.winRepeaterItem.itemAt(wi);
                                if (!wCard) continue;
                                if (pCol.y < wCard.y + wCard.height / 2) {
                                    insertStack = wi;
                                    if (wi === 0) barY = Math.max(2, wCard.y - 2);
                                    else {
                                        const prevW = colItem.winRepeaterItem.itemAt(wi - 1);
                                        barY = (prevW.y + prevW.height + wCard.y) / 2;
                                    }
                                    break;
                                }
                            }
                            if (insertStack === colItem.winRepeaterItem.count) {
                                const lastW = colItem.winRepeaterItem.itemAt(colItem.winRepeaterItem.count - 1);
                                barY = Math.min(colItem.height - 4, lastW.y + lastW.height - 2);
                            }
                            win.clearDropTarget();
                            win.hoveredColStrip = strip;
                            const targetItem = insertStack < colItem.winRepeaterItem.count
                                ? colItem.winRepeaterItem.itemAt(insertStack).modelData.realStackIdx
                                : (colItem.winRepeaterItem.itemAt(colItem.winRepeaterItem.count - 1).modelData.realStackIdx + 1);
                            if (targetItem !== win.dragSrcStackIdx && targetItem !== win.dragSrcStackIdx + 1) {
                                win.dropMode = "stack";
                                win.dropWsId = rowItem.wsId;
                                win.dropTargetCol = win.dragSrcColIdx;
                                win.dropInsertStack = targetItem;
                                win.dropBarY = barY;
                            }
                            return;
                        }
                    }
                }

                // Horizontal column insertion slot on this workspace.
                const tiledCols = [];
                if (rowItem.colRepeaterItem) {
                    for (let ci = 0; ci < rowItem.colRepeaterItem.count; ci++) {
                        const colItem = rowItem.colRepeaterItem.itemAt(ci);
                        if (colItem && !colItem.modelData.floating) tiledCols.push(colItem);
                    }
                }
                if (tiledCols.length === 0) {
                    win.clearDropTarget();
                    win.hoveredColStrip = strip;
                    if (rowItem.wsId !== win.dragSrcWsId) {
                        win.dropMode = "workspace";
                        win.dropWsId = rowItem.wsId;
                    }
                    return;
                }

                let k = tiledCols.length;
                for (let ti = 0; ti < tiledCols.length; ti++) {
                    if (pRow.x < tiledCols[ti].x + tiledCols[ti].width / 2) {
                        k = ti;
                        break;
                    }
                }

                let barX = 0;
                if (k === 0) {
                    barX = tiledCols[0].x - 3;
                } else if (k === tiledCols.length) {
                    const lastC = tiledCols[tiledCols.length - 1];
                    barX = lastC.x + lastC.width + 3;
                } else {
                    const prevC = tiledCols[k - 1];
                    const nextC = tiledCols[k];
                    barX = (prevC.x + prevC.width + nextC.x) / 2;
                }

                const realInsertCol = k < tiledCols.length
                    ? tiledCols[k].modelData.realColIdx
                    : (tiledCols[tiledCols.length - 1].modelData.realColIdx + 1);

                if (rowItem.wsId === win.dragSrcWsId && win.dragSrcColSize === 1
                        && (realInsertCol === win.dragSrcColIdx || realInsertCol === win.dragSrcColIdx + 1)) {
                    win.clearDropTarget();
                    win.hoveredColStrip = strip;
                    return;
                }

                const wantCol = (rowItem.wsId === win.dragSrcWsId && win.dragSrcColSize === 1 && realInsertCol > win.dragSrcColIdx)
                    ? (realInsertCol - 1)
                    : realInsertCol;

                win.clearDropTarget();
                win.hoveredColStrip = strip;
                win.dropMode = "column";
                win.dropWsId = rowItem.wsId;
                win.dropInsertCol = k;
                win.dropTargetCol = wantCol;
                win.dropBarX = barX;
            }

            function commitDragDrop() {
                const mode = win.dropMode;
                const addr = win.dragSrcAddr;
                const srcWs = win.dragSrcWsId;
                const srcCol = win.dragSrcColIdx;
                const srcColSize = win.dragSrcColSize;
                const srcStack = win.dragSrcStackIdx;
                const dstWs = win.dropWsId;
                const dstCol = win.dropTargetCol;
                const dstStack = win.dropInsertStack;
                const swapAddr = win.dropSwapAddr;
                win.clearDragState();
                if (!addr || !mode) return;

                if (mode === "workspace") {
                    Hypr.placeWindowInOverview(addr, srcWs, dstWs, -1, "");
                    win.selectedWsId = dstWs;
                } else if (mode === "column") {
                    const expelDir = (srcWs === dstWs && srcColSize > 1) ? (dstCol <= srcCol ? "prev" : "next") : "";
                    Hypr.placeWindowInOverview(addr, srcWs, dstWs, dstCol, expelDir);
                    win.selectedWsId = dstWs;
                } else if (mode === "stack") {
                    const finalStack = dstStack > srcStack ? (dstStack - 1) : dstStack;
                    const delta = finalStack - srcStack;
                    if (delta !== 0) Hypr.moveWindowInStack(addr, delta);
                } else if (mode === "swap" && swapAddr) {
                    Hypr.swapWindows(addr, swapAddr);
                }
            }

            Timer {
                id: autoScrollTimer
                interval: 16
                repeat: true
                running: win.isDragging
                onTriggered: {
                    let moved = false;
                    const pWs = slideContainer.mapToItem(wsList, win.dragX, win.dragY);
                    if (wsList.contentHeight > wsList.height && pWs.x >= 0 && pWs.x <= wsList.width) {
                        const maxY = wsList.contentHeight - wsList.height;
                        if (pWs.y >= 0 && pWs.y < 54 && wsList.contentY > 0) {
                            wsList.contentY = Math.max(0, wsList.contentY - Math.max(3, Math.round((54 - pWs.y) * 0.25)));
                            moved = true;
                        } else if (pWs.y > wsList.height - 54 && pWs.y <= wsList.height && wsList.contentY < maxY) {
                            wsList.contentY = Math.min(maxY, wsList.contentY + Math.max(3, Math.round((pWs.y - (wsList.height - 54)) * 0.25)));
                            moved = true;
                        }
                    }
                    const strip = win.hoveredColStrip;
                    if (strip && strip.contentWidth > strip.width) {
                        const pStrip = slideContainer.mapToItem(strip, win.dragX, win.dragY);
                        const maxX = strip.contentWidth - strip.width;
                        if (pStrip.x >= 0 && pStrip.x < 48 && strip.contentX > 0) {
                            strip.contentX = Math.max(0, strip.contentX - Math.max(3, Math.round((48 - pStrip.x) * 0.25)));
                            moved = true;
                        } else if (pStrip.x > strip.width - 48 && pStrip.x <= strip.width && strip.contentX < maxX) {
                            strip.contentX = Math.min(maxX, strip.contentX + Math.max(3, Math.round((pStrip.x - (strip.width - 48)) * 0.25)));
                            moved = true;
                        }
                    }
                    if (moved) win.updateDropTarget();
                }
            }

            function resetForOpen() {
                Hyprland.refreshMonitors();
                Hyprland.refreshWorkspaces();
                Hyprland.refreshToplevels();
                win.clearDragState();
                win.query = "";
                searchInput.text = "";
                win.selectedWsId = Hyprland.focusedWorkspace?.id ?? win.monitor?.activeWorkspace?.id ?? 1;
                win.selectedWinIdx = 0;
                focusTimer.restart();
            }

            Shortcut {
                sequences: ["Escape"]
                onActivated: {
                    if (win.isDragging) win.clearDragState();
                    else win.close();
                }
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
                                        if (win.isDragging) win.clearDragState();
                                        else win.close();
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
                                    text: "Search windows (Drag to move/reorder, Enter switch, ↑/↓ ws, ←/→ win)..."
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
                        cacheBuffer: 6000
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
                            ListView.delayRemove: win.isDragging && win.dragSrcWsId === wsRowItem.wsId

                            readonly property int wsId: modelData.wsId
                            readonly property bool isNew: modelData.isNew
                            readonly property bool isCurrentHypr: !isNew && (Hyprland.focusedWorkspace?.id ?? 0) === wsId
                            readonly property bool isSelected: win.selectedWsId === wsId
                            readonly property bool isDropTargetRow: win.isDragging && win.dropWsId === wsId

                            readonly property alias wsCardItem: wsCard
                            readonly property alias colStripItem: colStrip
                            readonly property alias colRowItem: colRow
                            readonly property alias colRepeaterItem: colRepeater

                            Rectangle {
                                id: wsCard
                                width: Math.min(parent.width, 1360)
                                height: parent.height
                                anchors.horizontalCenter: parent.horizontalCenter
                                radius: Theme.radiusL
                                color: (wsRowItem.isDropTargetRow && win.dropMode === "workspace") ? Qt.rgba(1, 0.68, 0, 0.16)
                                     : (wsRowItem.isDropTargetRow ? Qt.rgba(1, 0.68, 0, 0.12)
                                     : (wsRowItem.isSelected ? Qt.rgba(1, 0.68, 0, 0.11)
                                     : (wsRowItem.isCurrentHypr ? Qt.rgba(1, 0.68, 0, 0.05)
                                     : (wsBgHover.containsMouse ? Theme.componentHover : Theme.overviewBg))))
                                border.width: (wsRowItem.isDropTargetRow || wsRowItem.isSelected) ? 2 : 1
                                border.color: (wsRowItem.isDropTargetRow || wsRowItem.isSelected) ? Theme.accent
                                            : (wsRowItem.isCurrentHypr ? Qt.rgba(1, 0.68, 0, 0.48) : Theme.panelBorder)

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                                MouseArea {
                                    id: wsBgHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: if (!win.isDragging) win.selectedWsId = wsRowItem.wsId
                                    onClicked: if (!win.isDragging) win.switchToWorkspace(wsRowItem.wsId)
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
                                                color: (wsRowItem.isNew || (wsRowItem.isDropTargetRow && win.dropMode === "workspace")) ? Theme.accent : Theme.textDim
                                            }
                                            StyledText {
                                                text: (wsRowItem.isDropTargetRow && win.dropMode === "workspace")
                                                    ? ("Drop to move to workspace " + wsRowItem.wsId)
                                                    : (wsRowItem.isNew
                                                        ? ("New workspace " + wsRowItem.wsId + " — click, drop, or press Enter")
                                                        : "Empty workspace — click, drop, or press Enter")
                                                color: (wsRowItem.isDropTargetRow && win.dropMode === "workspace") ? Theme.accent : Theme.textDim
                                            }
                                        }

                                        Row {
                                            id: colRow
                                            x: implicitWidth < colStrip.width ? Math.round((colStrip.width - implicitWidth) / 2) : 0
                                            height: colStrip.height
                                            spacing: Theme.spaceS
                                            visible: wsRowItem.modelData.columns.length > 0

                                            Repeater {
                                                id: colRepeater
                                                model: wsRowItem.modelData.columns

                                                delegate: Item {
                                                    id: colItem
                                                    required property var modelData
                                                    width: Math.max(180, Math.min(480, Math.round(colStrip.basePreviewW * modelData.colWidthRatio)))
                                                    height: colStrip.height

                                                    readonly property alias winRepeaterItem: winRepeater

                                                    ColumnLayout {
                                                        anchors.fill: parent
                                                        spacing: Theme.spaceXxs

                                                        Repeater {
                                                            id: winRepeater
                                                            model: colItem.modelData.windows

                                                            delegate: Rectangle {
                                                                id: winCard
                                                                required property var modelData
                                                                readonly property var toplevel: modelData.toplevel
                                                                readonly property int flatIndex: modelData.flatIndex
                                                                readonly property bool isWinSelected: !win.isDragging && wsRowItem.isSelected && flatIndex === win.selectedWinIdx
                                                                readonly property string iconSource: win.iconFor(toplevel)
                                                                readonly property string addr: toplevel?.address || toplevel?.lastIpcObject?.address || ""
                                                                readonly property bool isDraggedCard: win.isDragging && win.dragSrcAddr === addr
                                                                readonly property bool isSwapTarget: win.isDragging && win.dropMode === "swap" && win.dropSwapAddr === addr
                                                                readonly property bool controlsVisible: !win.isDragging && (isWinSelected || winHover.containsMouse)

                                                                Layout.fillWidth: true
                                                                Layout.fillHeight: true
                                                                radius: Theme.radiusM
                                                                opacity: isDraggedCard ? 0.32 : 1.0
                                                                color: isSwapTarget ? Qt.rgba(1, 0.68, 0, 0.18)
                                                                     : (isWinSelected ? Qt.rgba(0.22, 0.22, 0.25, 0.94) : Qt.rgba(0.10, 0.10, 0.12, 0.92))
                                                                border.width: (isSwapTarget || isWinSelected) ? 2 : 1
                                                                border.color: (isSwapTarget || isWinSelected) ? Theme.accent
                                                                            : (winHover.containsMouse && !win.isDragging ? Qt.rgba(1, 1, 1, 0.42) : Theme.panelBorder)

                                                                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
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
                                                                    preventStealing: true
                                                                    cursorShape: win.isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                                                    onEntered: {
                                                                        if (!win.isDragging) {
                                                                            win.selectedWsId = wsRowItem.wsId;
                                                                            win.selectedWinIdx = winCard.flatIndex;
                                                                        }
                                                                    }
                                                                    onPressed: mouse => {
                                                                        const p = winHover.mapToItem(slideContainer, mouse.x, mouse.y);
                                                                        win.startPendingDrag(
                                                                            winCard.toplevel,
                                                                            winCard.addr,
                                                                            wsRowItem.wsId,
                                                                            colItem.modelData.realColIdx,
                                                                            winCard.modelData.realStackIdx,
                                                                            colItem.modelData.totalWindows,
                                                                            colItem.modelData.floating,
                                                                            winCard.toplevel?.title || win.appNameFor(winCard.toplevel),
                                                                            winCard.iconSource,
                                                                            p.x, p.y,
                                                                            winCard.width, winCard.height,
                                                                            mouse.x, mouse.y
                                                                        );
                                                                    }
                                                                    onPositionChanged: mouse => {
                                                                        if (pressed) {
                                                                            const p = winHover.mapToItem(slideContainer, mouse.x, mouse.y);
                                                                            win.updateDragPosition(p.x, p.y);
                                                                        }
                                                                    }
                                                                    onReleased: mouse => {
                                                                        if (win.isDragging) {
                                                                            win.commitDragDrop();
                                                                        } else {
                                                                            win.clearDragState();
                                                                            win.activateToplevel(winCard.toplevel);
                                                                        }
                                                                    }
                                                                    onCanceled: win.clearDragState()
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

                                                    // Horizontal insertion bar when dragging inside a stacked column.
                                                    Rectangle {
                                                        visible: win.isDragging
                                                                 && win.dropMode === "stack"
                                                                 && win.dropWsId === wsRowItem.wsId
                                                                 && win.dropTargetCol === colItem.modelData.realColIdx
                                                        z: 10
                                                        x: 4
                                                        y: Math.max(0, Math.min(colItem.height - height, win.dropBarY - height / 2))
                                                        width: colItem.width - 8
                                                        height: 4
                                                        radius: 2
                                                        color: Theme.accent
                                                    }
                                                }
                                            }
                                        }

                                        // Vertical insertion bar between columns (visible across workspaces too).
                                        Rectangle {
                                            visible: win.isDragging
                                                     && win.dropMode === "column"
                                                     && win.dropWsId === wsRowItem.wsId
                                            z: 10
                                            x: Math.max(0, Math.min(colStrip.contentWidth - width, colRow.x + win.dropBarX - width / 2))
                                            y: 6
                                            width: 4
                                            height: colStrip.height - 12
                                            radius: 2
                                            color: Theme.accent
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Floating drag preview following the cursor.
                Rectangle {
                    id: dragGhost
                    visible: win.isDragging
                    z: 100
                    width: win.dragGhostW
                    height: win.dragGhostH
                    x: Math.max(0, Math.min(slideContainer.width - width, win.dragX - win.dragHotspotX))
                    y: Math.max(0, Math.min(slideContainer.height - height, win.dragY - win.dragHotspotY))
                    radius: Theme.radiusM
                    color: Qt.rgba(0.15, 0.15, 0.18, 0.96)
                    border.width: 2
                    border.color: Theme.accent
                    opacity: 0.95
                    scale: 1.03

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
                                id: ghostPreview
                                anchors.fill: parent
                                captureSource: win.dragToplevel?.wayland ?? null
                                live: true
                                paintCursor: false
                            }

                            Icon {
                                anchors.centerIn: parent
                                visible: !ghostPreview.hasContent
                                icon: "web_asset"
                                size: 30
                                color: Theme.textDim
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            implicitHeight: 20
                            spacing: 6

                            Image {
                                visible: win.dragIconSource !== ""
                                source: win.dragIconSource
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14
                                sourceSize.width: 28
                                sourceSize.height: 28
                                asynchronous: true
                            }

                            Icon {
                                visible: win.dragIconSource === ""
                                icon: "web_asset"
                                size: 14
                                color: Theme.accent
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: win.dragTitle
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
