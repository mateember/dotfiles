import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Interactive Screenshot & Screen Recording overlay.
// Triggered via `qs ipc call capture toggle` (SUPER + Print), Quick Settings, Display menu, or `!capture`.
Scope {
    id: root

    LazyLoader {
        active: Recorder.overlayOpen

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            color: "transparent"

            WlrLayershell.namespace: "hcs-launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Shortcut {
                sequences: ["Escape"]
                onActivated: Recorder.closeOverlay()
            }

            HyprlandFocusGrab {
                active: true
                windows: [win]
                onCleared: Recorder.closeOverlay()
            }

            // Subtle backdrop; clicking outside closes the overlay
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.35)
                MouseArea {
                    anchors.fill: parent
                    onClicked: Recorder.closeOverlay()
                }
            }

            Rectangle {
                id: card
                width: Math.min(540, win.width - 2 * Theme.spaceL)
                height: col.implicitHeight + 2 * Theme.spaceM
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(win.height * 0.12)
                radius: Theme.radiusL
                color: Theme.popupBg
                border.color: Theme.popupBorder
                border.width: 1

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: col
                    anchors.fill: parent
                    anchors.margins: Theme.spaceM
                    spacing: Theme.spaceS

                    // ---- Header: Mode Tabs + Close button ----
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceXs

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: 19
                            color: Theme.surface1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 3
                                spacing: 4

                                Repeater {
                                    model: [
                                        { id: "shot", icon: "photo_camera", label: "Screenshot" },
                                        { id: "record", icon: "videocam", label: Recorder.recording ? "Recording (" + Recorder.formattedTime + ")" : "Screen Record" }
                                    ]
                                    delegate: Rectangle {
                                        id: tabBtn
                                        required property var modelData
                                        readonly property bool selected: Recorder.tab === modelData.id
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 16
                                        color: selected ? Theme.accent : (tabMouse.containsMouse ? Theme.componentHover : "transparent")

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Icon {
                                                icon: tabBtn.modelData.icon
                                                size: 18
                                                color: tabBtn.selected ? Theme.fgOnAccent : Theme.text
                                            }
                                            StyledText {
                                                text: tabBtn.modelData.label
                                                font.weight: Font.DemiBold
                                                color: tabBtn.selected ? Theme.fgOnAccent : Theme.text
                                            }
                                        }

                                        MouseArea {
                                            id: tabMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Recorder.tab = tabBtn.modelData.id
                                        }
                                    }
                                }
                            }
                        }

                        IconButton {
                            icon: "close"
                            onClicked: Recorder.closeOverlay()
                        }
                    }

                    // ---- Active Recording Banner (if currently recording) ----
                    Rectangle {
                        visible: Recorder.recording
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: Theme.radiusM
                        color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.18)
                        border.color: Theme.danger
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spaceS
                            anchors.rightMargin: Theme.spaceS
                            spacing: Theme.spaceXs

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: Theme.danger
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: "Recording in progress · " + Recorder.formattedTime
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                            Rectangle {
                                implicitWidth: stopRow.implicitWidth + 2 * Theme.spaceS
                                implicitHeight: 32
                                radius: 16
                                color: stopMouse.containsMouse ? Qt.lighter(Theme.danger, 1.1) : Theme.danger

                                RowLayout {
                                    id: stopRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Icon { icon: "stop_circle"; size: 16; color: "#000000" }
                                    StyledText {
                                        text: "Stop & Save"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: "#000000"
                                    }
                                }
                                MouseArea {
                                    id: stopMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Recorder.stopRecording();
                                        Recorder.closeOverlay();
                                    }
                                }
                            }
                        }
                    }

                    // ---- Target Grid: Screenshot Mode ----
                    RowLayout {
                        visible: Recorder.tab === "shot"
                        Layout.fillWidth: true
                        spacing: Theme.spaceXs

                        Repeater {
                            model: [
                                { mode: "region", icon: "screenshot_region", label: "Region", sub: "Drag area" },
                                { mode: "window", icon: "select_window", label: "Window", sub: "Pick window" },
                                { mode: "output", icon: "fullscreen", label: "Screen", sub: "Focused display" },
                                { mode: "color", icon: "colorize", label: "Color", sub: "Copy #HEX" }
                            ]
                            delegate: Rectangle {
                                id: shotTile
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 88
                                radius: Theme.radiusM
                                color: shotTileMouse.containsMouse ? Theme.componentHover : Theme.component
                                border.color: shotTileMouse.containsMouse ? Theme.accent : "transparent"
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Icon {
                                        Layout.alignment: Qt.AlignHCenter
                                        icon: shotTile.modelData.icon
                                        size: 26
                                        color: shotTileMouse.containsMouse ? Theme.accent : Theme.text
                                    }
                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: shotTile.modelData.label
                                        font.weight: Font.DemiBold
                                    }
                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: shotTile.modelData.sub
                                        font.pixelSize: 11
                                        color: Theme.textDim
                                    }
                                }

                                MouseArea {
                                    id: shotTileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (shotTile.modelData.mode === "color") {
                                            Recorder.closeOverlay();
                                            ColorPicker.pick();
                                        } else {
                                            Recorder.takeScreenshot(shotTile.modelData.mode);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ---- Screenshot Options Row (Action + Delay) ----
                    RowLayout {
                        visible: Recorder.tab === "shot"
                        Layout.fillWidth: true
                        spacing: Theme.spaceXs

                        // Action selector (Copy / Save & Copy / Annotate)
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 17
                            color: Theme.surface1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 3
                                spacing: 2

                                Repeater {
                                    model: [
                                        { id: "copy", icon: "content_copy", label: "Copy" },
                                        { id: "save", icon: "save", label: "Save & Copy" },
                                        { id: "annotate", icon: "Draw", label: "Annotate" }
                                    ]
                                    delegate: Rectangle {
                                        id: actPill
                                        required property var modelData
                                        readonly property bool active: Recorder.shotAction === modelData.id
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 14
                                        color: active ? Theme.accent : (actMouse.containsMouse ? Theme.componentHover : "transparent")

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Icon {
                                                icon: actPill.modelData.id === "annotate" ? "edit" : actPill.modelData.icon
                                                size: 14
                                                color: actPill.active ? Theme.fgOnAccent : Theme.text
                                            }
                                            StyledText {
                                                text: actPill.modelData.label
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: actPill.active ? Font.DemiBold : Font.Normal
                                                color: actPill.active ? Theme.fgOnAccent : Theme.text
                                            }
                                        }

                                        MouseArea {
                                            id: actMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Recorder.shotAction = actPill.modelData.id
                                        }
                                    }
                                }
                            }
                        }

                        // Timer delay selector (0s / 3s / 5s)
                        Rectangle {
                            implicitWidth: 138
                            implicitHeight: 34
                            radius: 17
                            color: Theme.surface1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 3
                                spacing: 2

                                Repeater {
                                    model: [
                                        { sec: 0, label: "Now" },
                                        { sec: 3, label: "3s" },
                                        { sec: 5, label: "5s" }
                                    ]
                                    delegate: Rectangle {
                                        id: dlyPill
                                        required property var modelData
                                        readonly property bool active: Recorder.shotDelay === modelData.sec
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 14
                                        color: active ? Theme.accent : (dlyMouse.containsMouse ? Theme.componentHover : "transparent")

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: dlyPill.modelData.label
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: dlyPill.active ? Font.DemiBold : Font.Normal
                                            color: dlyPill.active ? Theme.fgOnAccent : Theme.text
                                        }

                                        MouseArea {
                                            id: dlyMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Recorder.shotDelay = dlyPill.modelData.sec
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ---- Target Grid: Screen Record Mode ----
                    RowLayout {
                        visible: Recorder.tab === "record"
                        Layout.fillWidth: true
                        spacing: Theme.spaceXs

                        Repeater {
                            model: [
                                { mode: "screen", icon: "fullscreen", label: "Record Screen", sub: "Focused monitor" },
                                { mode: "region", icon: "screenshot_region", label: "Record Region", sub: "Select area" },
                                { mode: "window", icon: "select_window", label: "Record Window", sub: "Pick window" }
                            ]
                            delegate: Rectangle {
                                id: recTile
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 88
                                radius: Theme.radiusM
                                opacity: Recorder.recording ? 0.5 : 1.0
                                color: recTileMouse.containsMouse && !Recorder.recording ? Theme.componentHover : Theme.component
                                border.color: recTileMouse.containsMouse && !Recorder.recording ? Theme.danger : "transparent"
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Icon {
                                        Layout.alignment: Qt.AlignHCenter
                                        icon: recTile.modelData.icon
                                        size: 26
                                        color: recTileMouse.containsMouse && !Recorder.recording ? Theme.danger : Theme.text
                                    }
                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: recTile.modelData.label
                                        font.weight: Font.DemiBold
                                    }
                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: recTile.modelData.sub
                                        font.pixelSize: 11
                                        color: Theme.textDim
                                    }
                                }

                                MouseArea {
                                    id: recTileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !Recorder.recording
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Recorder.startRecording(recTile.modelData.mode, Recorder.recordAudio)
                                }
                            }
                        }
                    }

                    // ---- Screen Record Audio Options Row ----
                    Rectangle {
                        visible: Recorder.tab === "record"
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 17
                        color: Theme.surface1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 3
                            spacing: 2

                            Repeater {
                                model: [
                                    { id: "none", icon: "mic_off", label: "No Audio" },
                                    { id: "system", icon: "volume_up", label: "System Audio" },
                                    { id: "mic", icon: "mic", label: "Microphone" }
                                ]
                                delegate: Rectangle {
                                    id: audPill
                                    required property var modelData
                                    readonly property bool active: Recorder.recordAudio === modelData.id
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 14
                                    color: active ? Theme.accent : (audMouse.containsMouse ? Theme.componentHover : "transparent")

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Icon {
                                            icon: audPill.modelData.icon
                                            size: 15
                                            color: audPill.active ? Theme.fgOnAccent : Theme.text
                                        }
                                        StyledText {
                                            text: audPill.modelData.label
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: audPill.active ? Font.DemiBold : Font.Normal
                                            color: audPill.active ? Theme.fgOnAccent : Theme.text
                                        }
                                    }

                                    MouseArea {
                                        id: audMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Recorder.recordAudio = audPill.modelData.id
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
