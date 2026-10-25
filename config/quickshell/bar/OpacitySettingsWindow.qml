import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// Per-component opacity customization app (launched from the Launcher's `!` shell apps list,
// Bar Settings header, or `qs ipc call opacity toggle`).
// Real Wayland FloatingWindow, floated and centered by Hyprland window rules.
Scope {
    id: root

    LazyLoader {
        active: OpacityConfig.settingsOpen

        FloatingWindow {
            id: win

            title: "HCS — Opacity & Transparency"
            implicitWidth: 520
            implicitHeight: 500
            minimumSize: Qt.size(520, 500)
            maximumSize: Qt.size(520, 500)
            color: "transparent"

            onClosed: OpacityConfig.settingsOpen = false

            function previewNotification() {
                Quickshell.execDetached([
                    "notify-send",
                    "-e",
                    "-h", "string:x-canonical-private-synchronous:hcs-opacity-preview",
                    "-a", "Opacity & Transparency",
                    "-i", "preferences-desktop-theme",
                    "Notification opacity: " + Math.round(OpacityConfig.notificationsOpacity * 100) + "%",
                    "Drag the Notifications slider to preview live."
                ]);
            }

            function previewOsd() {
                Osd.show("opacity", "Toast opacity", OpacityConfig.osdOpacity, 1);
            }

            Rectangle {
                id: card
                anchors.fill: parent
                color: Theme.popupBg
                focus: true
                Component.onCompleted: card.forceActiveFocus()
                Keys.onEscapePressed: OpacityConfig.settingsOpen = false

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spaceS
                    spacing: Theme.spaceXs

                    // ---- Header ----
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceXs

                        Icon {
                            icon: "opacity"
                            size: 24
                            color: Theme.accent
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                text: "Opacity & Transparency"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                            }
                            StyledText {
                                text: "Set separate background opacity for each desktop component"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.textDim
                            }
                        }
                        Rectangle {
                            implicitWidth: resetLabel.implicitWidth + 2 * Theme.spaceXs
                            implicitHeight: 30
                            radius: 15
                            color: resetMouse.pressed ? Theme.componentPressed
                                 : resetMouse.containsMouse ? Theme.componentHover
                                 : Theme.component
                            StyledText {
                                id: resetLabel
                                anchors.centerIn: parent
                                text: "Reset"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.text
                            }
                            MouseArea {
                                id: resetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: OpacityConfig.reset()
                            }
                        }
                        IconButton {
                            icon: "close"
                            onClicked: OpacityConfig.settingsOpen = false
                        }
                    }

                    // ---- Quick Presets ----
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceXxs

                        Repeater {
                            model: [
                                { label: "Default",       w: 0.96, b: 0.66, n: 0.96, o: 0.96 },
                                { label: "Frosted Glass", w: 0.72, b: 0.50, n: 0.75, o: 0.75 },
                                { label: "Clear",         w: 0.45, b: 0.00, n: 0.55, o: 0.50 },
                                { label: "Solid",         w: 1.00, b: 1.00, n: 1.00, o: 1.00 }
                            ]
                            delegate: Rectangle {
                                id: presetBtn
                                required property var modelData
                                readonly property bool active:
                                    Math.abs(OpacityConfig.widgetsOpacity - modelData.w) < 0.01 &&
                                    Math.abs(OpacityConfig.barOpacity - modelData.b) < 0.01 &&
                                    Math.abs(OpacityConfig.notificationsOpacity - modelData.n) < 0.01 &&
                                    Math.abs(OpacityConfig.osdOpacity - modelData.o) < 0.01
                                Layout.fillWidth: true
                                implicitHeight: 32
                                radius: Theme.radiusS
                                color: active ? Theme.accent
                                     : presetMouse.containsMouse ? Theme.componentHover
                                     : Theme.component
                                StyledText {
                                    anchors.centerIn: parent
                                    text: presetBtn.modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: presetBtn.active ? Font.DemiBold : Font.Normal
                                    color: presetBtn.active ? Theme.fgOnAccent : Theme.text
                                }
                                MouseArea {
                                    id: presetMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: OpacityConfig.applyPreset(
                                        presetBtn.modelData.w,
                                        presetBtn.modelData.b,
                                        presetBtn.modelData.n,
                                        presetBtn.modelData.o
                                    )
                                }
                            }
                        }
                    }

                    Separator {}

                    // ---- 4 Separate Component Sliders ----
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Theme.spaceXxs

                        Repeater {
                            model: [
                                {
                                    key: "widgets",
                                    icon: "widgets",
                                    title: "Widgets",
                                    subtitle: "Menus, Quick Settings, Launcher & widget windows",
                                    previewLabel: ""
                                },
                                {
                                    key: "bar",
                                    icon: "view_agenda",
                                    title: "Bar",
                                    subtitle: "Top panel pill background (0% = floating icons)",
                                    previewLabel: ""
                                },
                                {
                                    key: "notifications",
                                    icon: "notifications",
                                    title: "Notifications",
                                    subtitle: "Incoming notification pop-ups & notification center",
                                    previewLabel: "Test"
                                },
                                {
                                    key: "osd",
                                    icon: "volume_up",
                                    title: "Volume & Brightness Toast",
                                    subtitle: "On-screen indicator pill for volume & brightness",
                                    previewLabel: "Test"
                                }
                            ]

                            delegate: Rectangle {
                                id: itemCard
                                required property var modelData

                                readonly property real currentValue:
                                    modelData.key === "widgets" ? OpacityConfig.widgetsOpacity
                                  : modelData.key === "bar" ? OpacityConfig.barOpacity
                                  : modelData.key === "notifications" ? OpacityConfig.notificationsOpacity
                                  : OpacityConfig.osdOpacity

                                function setVal(v: real) {
                                    if (modelData.key === "widgets") {
                                        OpacityConfig.setWidgets(v);
                                    } else if (modelData.key === "bar") {
                                        OpacityConfig.setBar(v);
                                    } else if (modelData.key === "notifications") {
                                        OpacityConfig.setNotifications(v);
                                    } else {
                                        OpacityConfig.setOsd(v);
                                        win.previewOsd();
                                    }
                                }

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                implicitHeight: 82
                                radius: Theme.radiusM
                                color: Theme.component

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spaceS
                                    anchors.rightMargin: Theme.spaceS
                                    anchors.topMargin: Theme.spaceXs
                                    anchors.bottomMargin: Theme.spaceXs
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spaceXs

                                        Icon {
                                            icon: itemCard.modelData.icon
                                            size: 20
                                            color: Theme.accent
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: itemCard.modelData.title
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                            }
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: itemCard.modelData.subtitle
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.textDim
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Rectangle {
                                            visible: itemCard.modelData.previewLabel !== ""
                                            implicitWidth: testTxt.implicitWidth + 2 * Theme.spaceXs
                                            implicitHeight: 24
                                            radius: 12
                                            color: testMouse.pressed ? Theme.primaryPressed
                                                 : testMouse.containsMouse ? Theme.primaryHover
                                                 : Theme.primaryComponent
                                            StyledText {
                                                id: testTxt
                                                anchors.centerIn: parent
                                                text: itemCard.modelData.previewLabel
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.text
                                            }
                                            MouseArea {
                                                id: testMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (itemCard.modelData.key === "notifications")
                                                        win.previewNotification();
                                                    else if (itemCard.modelData.key === "osd")
                                                        win.previewOsd();
                                                }
                                            }
                                        }

                                        StyledText {
                                            Layout.preferredWidth: 44
                                            horizontalAlignment: Text.AlignRight
                                            text: Math.round(itemCard.currentValue * 100) + "%"
                                            font.weight: Font.DemiBold
                                            font.features: { "tnum": 1 }
                                            color: Theme.accent
                                        }
                                    }

                                    StyledSlider {
                                        Layout.fillWidth: true
                                        from: 0
                                        to: 1
                                        wheelStep: 0.02
                                        value: itemCard.currentValue
                                        onMoved: v => itemCard.setVal(v)
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
