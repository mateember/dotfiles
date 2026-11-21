import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// COSMIC-style interactive fullscreen screenshot overlay.
// Freezes all monitors at native DPI, supports Rectangle / Window / Screen selection
// with 8 resize handles and drag-to-move so any selection can be post-adjusted freely.
Scope {
    id: root

    Variants {
        model: Snip.active ? Quickshell.screens : []

        PanelWindow {
            id: win

            required property ShellScreen modelData
            screen: win.modelData

            readonly property string screenName: win.modelData?.name ?? ""
            readonly property bool isActiveScreen: Snip.activeScreen === win.screenName
            readonly property var monInfo: Snip.monitors[win.screenName] ?? null
            readonly property real dpr: (monInfo && monInfo.scale > 0) ? monInfo.scale : (win.modelData?.devicePixelRatio ?? 1)

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: -1
            color: "#000000"

            WlrLayershell.namespace: "hcs-screenshot"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: win.isActiveScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

            property var hoveredWindow: null

            Component.onCompleted: {
                if (win.isActiveScreen && Snip.mode === "window" && Snip.initialHoveredWindow)
                    win.hoveredWindow = Snip.initialHoveredWindow;
            }

            Connections {
                target: Snip
                function onModeChanged() {
                    if (Snip.mode !== "window") win.hoveredWindow = null;
                }
                function onActiveScreenChanged() {
                    if (!win.isActiveScreen) win.hoveredWindow = null;
                }
            }

            FocusScope {
                id: keyScope
                anchors.fill: parent
                focus: win.isActiveScreen

                Keys.onPressed: event => {
                    if (!Snip.active) return;
                    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                    const commitWithHover = action => {
                        if (!Snip.hasSelection && Snip.mode === "window" && win.hoveredWindow) {
                            const hw = win.hoveredWindow;
                            Snip.setSelection(win.screenName, hw.x, hw.y, hw.w, hw.h, hw.title || hw.className);
                        }
                        if (Snip.hasSelection || Snip.mode === "output")
                            Snip.commit(action);
                    };
                    if (event.key === Qt.Key_Escape) {
                        Snip.cancel();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        commitWithHover(Snip.defaultAction);
                        event.accepted = true;
                    } else if (ctrl && event.key === Qt.Key_C) {
                        commitWithHover("copy");
                        event.accepted = true;
                    } else if (ctrl && event.key === Qt.Key_S) {
                        commitWithHover("save");
                        event.accepted = true;
                    } else if (ctrl && event.key === Qt.Key_E) {
                        commitWithHover("annotate");
                        event.accepted = true;
                    } else if (!ctrl && (event.key === Qt.Key_1 || event.key === Qt.Key_R)) {
                        Snip.setMode("region");
                        event.accepted = true;
                    } else if (!ctrl && (event.key === Qt.Key_2 || event.key === Qt.Key_W)) {
                        Snip.setMode("window");
                        event.accepted = true;
                    } else if (!ctrl && (event.key === Qt.Key_3 || event.key === Qt.Key_S)) {
                        Snip.setMode("output");
                        event.accepted = true;
                    }
                }

                // Frozen monitor frame rendered 1:1 at native DPI.
                Image {
                    anchors.fill: parent
                    source: Snip.sessionDir ? ("file://" + Snip.sessionDir + "/" + win.screenName + ".png") : ""
                    fillMode: Image.Stretch
                    cache: false
                    asynchronous: false
                    smooth: true
                }

                readonly property bool showSelection: win.isActiveScreen && Snip.hasSelection
                readonly property bool showHoverWin: !Snip.hasSelection && Snip.mode === "window" && win.hoveredWindow !== null
                readonly property bool hasCutout: showSelection || showHoverWin
                readonly property real cutX: showSelection ? Snip.selX : (showHoverWin ? win.hoveredWindow.x : 0)
                readonly property real cutY: showSelection ? Snip.selY : (showHoverWin ? win.hoveredWindow.y : 0)
                readonly property real cutW: showSelection ? Snip.selW : (showHoverWin ? win.hoveredWindow.w : 0)
                readonly property real cutH: showSelection ? Snip.selH : (showHoverWin ? win.hoveredWindow.h : 0)

                // Uniform dim when no selection/hover cutout is active.
                Rectangle {
                    anchors.fill: parent
                    visible: !keyScope.hasCutout
                    color: Qt.rgba(0, 0, 0, 0.45)
                }

                // 4-rectangle dim mask surrounding the active cutout.
                Item {
                    anchors.fill: parent
                    visible: keyScope.hasCutout

                    Rectangle {
                        x: 0; y: 0
                        width: parent.width
                        height: Math.max(0, keyScope.cutY)
                        color: Qt.rgba(0, 0, 0, 0.48)
                    }
                    Rectangle {
                        x: 0; y: keyScope.cutY + keyScope.cutH
                        width: parent.width
                        height: Math.max(0, parent.height - (keyScope.cutY + keyScope.cutH))
                        color: Qt.rgba(0, 0, 0, 0.48)
                    }
                    Rectangle {
                        x: 0; y: keyScope.cutY
                        width: Math.max(0, keyScope.cutX)
                        height: Math.max(0, keyScope.cutH)
                        color: Qt.rgba(0, 0, 0, 0.48)
                    }
                    Rectangle {
                        x: keyScope.cutX + keyScope.cutW; y: keyScope.cutY
                        width: Math.max(0, parent.width - (keyScope.cutX + keyScope.cutW))
                        height: Math.max(0, keyScope.cutH)
                        color: Qt.rgba(0, 0, 0, 0.48)
                    }
                }

                // Crisp selection / hover outline.
                Rectangle {
                    visible: keyScope.hasCutout
                    x: keyScope.cutX
                    y: keyScope.cutY
                    width: keyScope.cutW
                    height: keyScope.cutH
                    color: "transparent"
                    border.color: keyScope.showSelection ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85)
                    border.width: 2
                }

                // 8 resize handles when a selection is active on this monitor.
                Item {
                    visible: keyScope.showSelection
                    x: keyScope.cutX
                    y: keyScope.cutY
                    width: keyScope.cutW
                    height: keyScope.cutH

                    // Corner handles (4).
                    Repeater {
                        model: [
                            { hx: 0, hy: 0 },
                            { hx: 1, hy: 0 },
                            { hx: 0, hy: 1 },
                            { hx: 1, hy: 1 }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            width: 12
                            height: 12
                            radius: 6
                            color: "#FFFFFF"
                            border.color: Theme.accent
                            border.width: 2
                            x: Math.round(modelData.hx * parent.width - width / 2)
                            y: Math.round(modelData.hy * parent.height - height / 2)
                        }
                    }

                    // Horizontal edge midpoint pills (top / bottom).
                    Repeater {
                        model: keyScope.cutW >= 44 ? [0, 1] : []
                        delegate: Rectangle {
                            required property int modelData
                            width: 24
                            height: 6
                            radius: 3
                            color: "#FFFFFF"
                            border.color: Theme.accent
                            border.width: 1.5
                            x: Math.round(parent.width / 2 - width / 2)
                            y: Math.round(modelData * parent.height - height / 2)
                        }
                    }

                    // Vertical edge midpoint pills (left / right).
                    Repeater {
                        model: keyScope.cutH >= 44 ? [0, 1] : []
                        delegate: Rectangle {
                            required property int modelData
                            width: 6
                            height: 24
                            radius: 3
                            color: "#FFFFFF"
                            border.color: Theme.accent
                            border.width: 1.5
                            x: Math.round(modelData * parent.width - width / 2)
                            y: Math.round(parent.height / 2 - height / 2)
                        }
                    }
                }

                // Dimension & label badge on active cutout.
                Rectangle {
                    id: dimBadge
                    visible: keyScope.hasCutout && keyScope.cutW >= 20 && keyScope.cutH >= 20
                    radius: Theme.radiusS
                    color: Theme.popupBg
                    border.color: Theme.popupBorder
                    border.width: 1
                    implicitWidth: dimText.implicitWidth + 16
                    implicitHeight: dimText.implicitHeight + 8
                    x: Math.max(8, Math.min(parent.width - width - 8, keyScope.cutX))
                    y: keyScope.cutY >= height + 10
                        ? keyScope.cutY - height - 8
                        : Math.min(parent.height - height - 8, keyScope.cutY + 8)

                    readonly property string labelText: {
                        const dims = Math.round(keyScope.cutW * win.dpr) + " × " + Math.round(keyScope.cutH * win.dpr);
                        if (keyScope.showHoverWin && win.hoveredWindow) {
                            const t = win.hoveredWindow.title || win.hoveredWindow.className || "";
                            return t ? (t.length > 36 ? t.slice(0, 35) + "… · " : t + " · ") + dims : dims;
                        }
                        return dims;
                    }

                    StyledText {
                        id: dimText
                        anchors.centerIn: parent
                        text: dimBadge.labelText
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                    }
                }

                // Fullscreen pointer canvas for hover, draw, move, and 8-handle resize.
                MouseArea {
                    id: canvasMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    property string dragKind: "none"   // "none" | "new" | "move" | "resize" | "win"
                    property string dragHandle: ""
                    property bool dragging: false
                    property real startX: 0
                    property real startY: 0
                    property real startW: 0
                    property real startH: 0
                    property real pressMouseX: 0
                    property real pressMouseY: 0
                    property var candidateWin: null

                    function hitTest(mx: real, my: real): string {
                        if (!win.isActiveScreen || !Snip.hasSelection) return "none";
                        const sx = Snip.selX, sy = Snip.selY, sw = Snip.selW, sh = Snip.selH;
                        const pad = 12;
                        const nearL = Math.abs(mx - sx) <= pad;
                        const nearR = Math.abs(mx - (sx + sw)) <= pad;
                        const nearT = Math.abs(my - sy) <= pad;
                        const nearB = Math.abs(my - (sy + sh)) <= pad;
                        const inX = mx >= sx - pad && mx <= sx + sw + pad;
                        const inY = my >= sy - pad && my <= sy + sh + pad;

                        if (nearL && nearT) return "tl";
                        if (nearR && nearT) return "tr";
                        if (nearL && nearB) return "bl";
                        if (nearR && nearB) return "br";
                        if (nearT && inX) return "t";
                        if (nearB && inX) return "b";
                        if (nearL && inY) return "l";
                        if (nearR && inY) return "r";
                        if (mx >= sx && mx <= sx + sw && my >= sy && my <= sy + sh) return "move";
                        return "none";
                    }

                    function cursorForHit(hit: string): int {
                        if (hit === "tl" || hit === "br") return Qt.SizeFDiagCursor;
                        if (hit === "tr" || hit === "bl") return Qt.SizeBDiagCursor;
                        if (hit === "t" || hit === "b") return Qt.SizeVerCursor;
                        if (hit === "l" || hit === "r") return Qt.SizeHorCursor;
                        if (hit === "move") {
                            const full = Snip.selW >= canvasMouse.width - 2 && Snip.selH >= canvasMouse.height - 2;
                            return full ? Qt.CrossCursor : Qt.SizeAllCursor;
                        }
                        if (Snip.mode === "window" && !Snip.hasSelection) return Qt.PointingHandCursor;
                        return Qt.CrossCursor;
                    }

                    cursorShape: {
                        if (dragKind === "resize") return cursorForHit(dragHandle);
                        if (dragKind === "move") return Qt.SizeAllCursor;
                        if (dragKind === "new") return Qt.CrossCursor;
                        return cursorForHit(hitTest(mouseX, mouseY));
                    }

                    onPressed: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            dragKind = "none";
                            dragHandle = "none";
                            dragging = false;
                            if (Snip.hasSelection) Snip.clearSelection();
                            else Snip.cancel();
                            return;
                        }

                        Snip.activeScreen = win.screenName;
                        pressMouseX = mouse.x;
                        pressMouseY = mouse.y;
                        dragging = false;

                        const hit = hitTest(mouse.x, mouse.y);
                        const isFull = Snip.hasSelection
                            && Snip.selW >= width - 2
                            && Snip.selH >= height - 2;

                        if (hit !== "none" && hit !== "move") {
                            dragKind = "resize";
                            dragHandle = hit;
                            startX = Snip.selX;
                            startY = Snip.selY;
                            startW = Snip.selW;
                            startH = Snip.selH;
                            dragging = true;
                            return;
                        }

                        if (hit === "move" && !isFull) {
                            dragKind = "move";
                            startX = Snip.selX;
                            startY = Snip.selY;
                            startW = Snip.selW;
                            startH = Snip.selH;
                            dragging = true;
                            return;
                        }

                        if (Snip.mode === "window") {
                            dragKind = "win";
                            candidateWin = Snip.windowAt(win.screenName, mouse.x, mouse.y);
                            return;
                        }

                        if (Snip.mode === "output") {
                            dragKind = "out";
                            return;
                        }

                        dragKind = "new";
                        Snip.clearSelection();
                    }

                    onPositionChanged: mouse => {
                        const mx = Math.max(0, Math.min(width, mouse.x));
                        const my = Math.max(0, Math.min(height, mouse.y));

                        if (!pressed) {
                            if (Snip.mode === "window" && !Snip.hasSelection) {
                                if (Snip.activeScreen !== win.screenName)
                                    Snip.activeScreen = win.screenName;
                                win.hoveredWindow = Snip.windowAt(win.screenName, mx, my);
                            }
                            return;
                        }

                        if (dragKind === "win" || dragKind === "out") {
                            if (Math.hypot(mx - pressMouseX, my - pressMouseY) >= 6) {
                                dragKind = "new";
                                Snip.mode = "region";
                                Snip.clearSelection();
                            } else {
                                return;
                            }
                        }

                        if (dragKind === "new") {
                            dragging = true;
                            const x0 = Math.min(pressMouseX, mx);
                            const y0 = Math.min(pressMouseY, my);
                            const w = Math.abs(mx - pressMouseX);
                            const h = Math.abs(my - pressMouseY);
                            Snip.setSelection(win.screenName, x0, y0, w, h, "");
                        } else if (dragKind === "move") {
                            const nx = Math.max(0, Math.min(width - startW, startX + (mx - pressMouseX)));
                            const ny = Math.max(0, Math.min(height - startH, startY + (my - pressMouseY)));
                            Snip.setSelection(win.screenName, nx, ny, startW, startH, Snip.selectedTitle);
                        } else if (dragKind === "resize") {
                            let l = startX;
                            let t = startY;
                            let r = startX + startW;
                            let b = startY + startH;
                            const minSz = 8;

                            if (dragHandle.indexOf("l") !== -1) l = Math.max(0, Math.min(r - minSz, mx));
                            if (dragHandle.indexOf("r") !== -1) r = Math.min(width, Math.max(l + minSz, mx));
                            if (dragHandle.indexOf("t") !== -1) t = Math.max(0, Math.min(b - minSz, my));
                            if (dragHandle.indexOf("b") !== -1) b = Math.min(height, Math.max(t + minSz, my));

                            if (Snip.mode === "output") Snip.mode = "region";
                            Snip.setSelection(win.screenName, l, t, r - l, b - t, "");
                        }
                    }

                    onReleased: mouse => {
                        if (mouse.button === Qt.RightButton) return;
                        if (dragKind === "win") {
                            const w = candidateWin || Snip.windowAt(win.screenName, mouse.x, mouse.y);
                            if (w) {
                                win.hoveredWindow = null;
                                Snip.setSelection(win.screenName, w.x, w.y, w.w, w.h, w.title || w.className);
                            } else if (Snip.hasSelection) {
                                Snip.clearSelection();
                            }
                        } else if (dragKind === "out") {
                            Snip.selectScreenFull(win.screenName);
                        }
                        dragKind = "none";
                        dragHandle = "";
                        dragging = false;
                        candidateWin = null;
                    }

                    onDoubleClicked: mouse => {
                        if (mouse.button !== Qt.LeftButton) return;
                        if (win.isActiveScreen && Snip.hasSelection) {
                            const sx = Snip.selX, sy = Snip.selY, sw = Snip.selW, sh = Snip.selH;
                            if (mouse.x >= sx && mouse.x <= sx + sw && mouse.y >= sy && mouse.y <= sy + sh)
                                Snip.commit(Snip.defaultAction);
                        }
                    }
                }

                // Floating COSMIC-styled control pill on the active monitor.
                Rectangle {
                    id: toolbar
                    visible: win.isActiveScreen
                    radius: height / 2
                    color: Theme.popupBg
                    border.color: Theme.popupBorder
                    border.width: Theme.popupBorderWidth
                    implicitWidth: barRow.implicitWidth + 2 * Theme.spaceXs
                    implicitHeight: 50

                    readonly property bool bottomBlocked: Snip.hasSelection
                        && !canvasMouse.dragging
                        && (Snip.selY + Snip.selH > parent.height - height - Theme.spaceM - 12)
                        && (Snip.selY > height + Theme.spaceM + 12)

                    x: Math.round((parent.width - width) / 2)
                    y: bottomBlocked ? Theme.spaceM : (parent.height - height - Theme.spaceM)
                    Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    // Swallow clicks/hovers over the toolbar so the canvas behind doesn't react.
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    RowLayout {
                        id: barRow
                        anchors.centerIn: parent
                        spacing: Theme.spaceXxs

                        // Mode selector: Rectangle | Window | Screen
                        Rectangle {
                            implicitWidth: modeRow.implicitWidth + 6
                            implicitHeight: 36
                            radius: 18
                            color: Theme.surface1

                            RowLayout {
                                id: modeRow
                                anchors.centerIn: parent
                                spacing: 2

                                Repeater {
                                    model: [
                                        { id: "region", icon: "screenshot_region", label: "Rectangle" },
                                        { id: "window", icon: "select_window", label: "Window" },
                                        { id: "output", icon: "fullscreen", label: "Screen" }
                                    ]
                                    delegate: Rectangle {
                                        id: mPill
                                        required property var modelData
                                        readonly property bool selected: Snip.mode === modelData.id
                                        implicitWidth: mContent.implicitWidth + 18
                                        implicitHeight: 30
                                        radius: 15
                                        color: selected ? Theme.accent : (mMouse.containsMouse ? Theme.componentHover : "transparent")

                                        RowLayout {
                                            id: mContent
                                            anchors.centerIn: parent
                                            spacing: 5
                                            Icon {
                                                icon: mPill.modelData.icon
                                                size: 16
                                                color: mPill.selected ? Theme.fgOnAccent : Theme.text
                                            }
                                            StyledText {
                                                text: mPill.modelData.label
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: mPill.selected ? Font.DemiBold : Font.Normal
                                                color: mPill.selected ? Theme.fgOnAccent : Theme.text
                                            }
                                        }

                                        MouseArea {
                                            id: mMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Snip.setMode(mPill.modelData.id)
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 1
                            height: 22
                            color: Theme.popupBorder
                        }

                        // Action buttons: Copy | Save | Annotate
                        Repeater {
                            model: [
                                { id: "copy", icon: "content_copy", label: "Copy", primary: true },
                                { id: "save", icon: "save", label: "Save", primary: false },
                                { id: "annotate", icon: "edit", label: "Annotate", primary: false }
                            ]
                            delegate: Rectangle {
                                id: actBtn
                                required property var modelData
                                readonly property bool enabledAct: Snip.hasSelection || Snip.mode === "output"
                                implicitWidth: actRow.implicitWidth + 20
                                implicitHeight: 34
                                radius: 17
                                opacity: enabledAct ? 1.0 : 0.45
                                color: modelData.primary
                                    ? (actMouse.containsMouse && enabledAct ? Theme.accentHover : Theme.accent)
                                    : (actMouse.containsMouse && enabledAct ? Theme.componentHover : Theme.button)

                                RowLayout {
                                    id: actRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Icon {
                                        icon: actBtn.modelData.icon
                                        size: 16
                                        color: actBtn.modelData.primary ? Theme.fgOnAccent : Theme.text
                                    }
                                    StyledText {
                                        text: actBtn.modelData.label
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: actBtn.modelData.primary ? Font.DemiBold : Font.Medium
                                        color: actBtn.modelData.primary ? Theme.fgOnAccent : Theme.text
                                    }
                                }

                                MouseArea {
                                    id: actMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: actBtn.enabledAct
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Snip.commit(actBtn.modelData.id)
                                }
                            }
                        }

                        IconButton {
                            icon: "close"
                            onClicked: Snip.cancel()
                        }
                    }
                }
            }
        }
    }
}
