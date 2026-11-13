import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// Surface opacity presets, synchronized transparency sliders with live test
// triggers, and panel border weight / alpha controls.
ColumnLayout {
    id: root

    readonly property var opacityPresets: [
        { name: "Default",       desc: "Balanced",   w: 0.96, b: 0.66, n: 0.96, o: 0.96 },
        { name: "Frosted Glass", desc: "Airy blur",  w: 0.78, b: 0.45, n: 0.85, o: 0.88 },
        { name: "Clear",         desc: "See-through", w: 0.58, b: 0.30, n: 0.70, o: 0.75 },
        { name: "Solid",         desc: "Opaque",     w: 1.00, b: 1.00, n: 1.00, o: 1.00 }
    ]

    function matchesPreset(p) {
        const cur = ThemeConfig.current;
        return Math.abs((cur.widgetsOpacity ?? 0.96) - p.w) < 0.015
            && Math.abs((cur.barOpacity ?? 0.66) - p.b) < 0.015
            && Math.abs((cur.notificationsOpacity ?? 0.96) - p.n) < 0.015
            && Math.abs((cur.osdOpacity ?? 0.96) - p.o) < 0.015;
    }

    function pct(v) {
        return Math.round(Number(v) * 100) + "%";
    }

    Layout.fillWidth: true
    spacing: Theme.spaceM

    // ---- Opacity Presets Card ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: presetCol.implicitHeight + 2 * Theme.spaceS
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.divider

        ColumnLayout {
            id: presetCol
            anchors.fill: parent
            anchors.margins: Theme.spaceS
            spacing: Theme.spaceXs

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                Icon { icon: "opacity"; size: 17; color: Theme.accent }
                StyledText {
                    Layout.fillWidth: true
                    text: "Transparency Presets"
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }
                StyledText {
                    text: "Synced with !opacity"
                    font.pixelSize: Math.max(10, Theme.fontSizeSmall - 1)
                    color: Theme.textDim
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                Repeater {
                    model: root.opacityPresets
                    delegate: Rectangle {
                        id: opCard
                        required property var modelData
                        readonly property bool active: root.matchesPreset(modelData)

                        Layout.fillWidth: true
                        implicitHeight: opCol.implicitHeight + 14
                        radius: Theme.radiusS
                        color: active ? Theme.accent
                             : opMouse.containsMouse ? Theme.componentHover
                             : Theme.component
                        border.width: 1
                        border.color: active ? Theme.accent : Theme.divider

                        ColumnLayout {
                            id: opCol
                            anchors.centerIn: parent
                            spacing: 1

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: opCard.modelData.name
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: opCard.active ? Font.DemiBold : Font.Medium
                                color: opCard.active ? Theme.fgOnAccent : Theme.textStrong
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: opCard.modelData.desc
                                font.pixelSize: 10
                                color: opCard.active ? Theme.fgOnAccent : Theme.textDim
                            }
                        }

                        MouseArea {
                            id: opMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ThemeConfig.setSettings({
                                widgetsOpacity: opCard.modelData.w,
                                barOpacity: opCard.modelData.b,
                                notificationsOpacity: opCard.modelData.n,
                                osdOpacity: opCard.modelData.o
                            }, true)
                        }
                    }
                }
            }
        }
    }

    // ---- Opacity Sliders Card ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: opSlidersCol.implicitHeight + 2 * Theme.spaceS
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.divider

        ColumnLayout {
            id: opSlidersCol
            anchors.fill: parent
            anchors.margins: Theme.spaceS
            spacing: Theme.spaceS

            StyledText {
                text: "Surface Opacity"
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                color: Theme.textStrong
            }

            ThemeSliderRow {
                label: "Widgets & Popups"
                subtitle: "Quick Settings, Launcher & menus"
                value: Number(ThemeConfig.current.widgetsOpacity ?? 0.96)
                from: 0.20
                to: 1.0
                wheelStep: 0.02
                defaultValue: 0.96
                valueText: root.pct(ThemeConfig.current.widgetsOpacity ?? 0.96)
                onMoved: v => ThemeConfig.setSetting("widgetsOpacity", Math.round(v * 50) / 50)
                onResetClicked: ThemeConfig.setSetting("widgetsOpacity", 0.96)
            }

            ThemeSliderRow {
                label: "Top Bar"
                subtitle: "Floating bar background fill"
                value: Number(ThemeConfig.current.barOpacity ?? 0.66)
                from: 0.0
                to: 1.0
                wheelStep: 0.02
                defaultValue: 0.66
                valueText: root.pct(ThemeConfig.current.barOpacity ?? 0.66)
                onMoved: v => ThemeConfig.setSetting("barOpacity", Math.round(v * 50) / 50)
                onResetClicked: ThemeConfig.setSetting("barOpacity", 0.66)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                ThemeSliderRow {
                    Layout.fillWidth: true
                    label: "Notifications"
                    subtitle: "Toast cards"
                    value: Number(ThemeConfig.current.notificationsOpacity ?? 0.96)
                    from: 0.25
                    to: 1.0
                    wheelStep: 0.02
                    defaultValue: 0.96
                    valueText: root.pct(ThemeConfig.current.notificationsOpacity ?? 0.96)
                    onMoved: v => ThemeConfig.setSetting("notificationsOpacity", Math.round(v * 50) / 50)
                    onResetClicked: ThemeConfig.setSetting("notificationsOpacity", 0.96)
                }

                Rectangle {
                    implicitWidth: notifTestLbl.implicitWidth + 16
                    implicitHeight: 26
                    radius: 13
                    color: notifTestMouse.pressed ? Theme.componentPressed
                         : notifTestMouse.containsMouse ? Theme.componentHover
                         : Theme.component
                    border.width: 1
                    border.color: Theme.divider

                    StyledText {
                        id: notifTestLbl
                        anchors.centerIn: parent
                        text: "Test"
                        font.pixelSize: 11
                        color: Theme.text
                    }
                    MouseArea {
                        id: notifTestMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached([
                            "notify-send", "-a", "Theme Settings",
                            "Notification Opacity",
                            "Previewing notifications at " + root.pct(ThemeConfig.current.notificationsOpacity ?? 0.96)
                        ])
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                ThemeSliderRow {
                    Layout.fillWidth: true
                    label: "OSD Toast"
                    subtitle: "Volume & brightness"
                    value: Number(ThemeConfig.current.osdOpacity ?? 0.96)
                    from: 0.25
                    to: 1.0
                    wheelStep: 0.02
                    defaultValue: 0.96
                    valueText: root.pct(ThemeConfig.current.osdOpacity ?? 0.96)
                    onMoved: v => ThemeConfig.setSetting("osdOpacity", Math.round(v * 50) / 50)
                    onResetClicked: ThemeConfig.setSetting("osdOpacity", 0.96)
                }

                Rectangle {
                    implicitWidth: osdTestLbl.implicitWidth + 16
                    implicitHeight: 26
                    radius: 13
                    color: osdTestMouse.pressed ? Theme.componentPressed
                         : osdTestMouse.containsMouse ? Theme.componentHover
                         : Theme.component
                    border.width: 1
                    border.color: Theme.divider

                    StyledText {
                        id: osdTestLbl
                        anchors.centerIn: parent
                        text: "Test"
                        font.pixelSize: 11
                        color: Theme.text
                    }
                    MouseArea {
                        id: osdTestMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Osd.show("opacity", "Toast opacity", ThemeConfig.current.osdOpacity ?? 0.96, 1)
                    }
                }
            }
        }
    }

    // ---- Panel Borders & Edges Card ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: bordersCol.implicitHeight + 2 * Theme.spaceS
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.divider

        ColumnLayout {
            id: bordersCol
            anchors.fill: parent
            anchors.margins: Theme.spaceS
            spacing: Theme.spaceS

            StyledText {
                text: "Panel Borders & Strokes"
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                color: Theme.textStrong
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        text: "Popup & Window Border"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }
                    StyledText {
                        text: "Stroke width around Quick Settings, Launcher & notifications"
                        font.pixelSize: Math.max(10, Theme.fontSizeSmall - 1)
                        color: Theme.textDim
                    }
                }

                RowLayout {
                    spacing: 4
                    Repeater {
                        model: [0, 1, 2]
                        delegate: Rectangle {
                            required property int modelData
                            readonly property bool selected: (ThemeConfig.current.popupBorderWidth ?? 1) === modelData
                            implicitWidth: 42
                            implicitHeight: 28
                            radius: 14
                            color: selected ? Theme.accent
                                 : pwMouse.containsMouse ? Theme.componentHover
                                 : Theme.component

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData + "px"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: parent.selected ? Font.DemiBold : Font.Normal
                                color: parent.selected ? Theme.fgOnAccent : Theme.text
                            }
                            MouseArea {
                                id: pwMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ThemeConfig.setSetting("popupBorderWidth", modelData)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        text: "Top Bar Border"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }
                    StyledText {
                        text: "Optional crisp outline around the top panel"
                        font.pixelSize: Math.max(10, Theme.fontSizeSmall - 1)
                        color: Theme.textDim
                    }
                }

                RowLayout {
                    spacing: 4
                    Repeater {
                        model: [0, 1, 2]
                        delegate: Rectangle {
                            required property int modelData
                            readonly property bool selected: (ThemeConfig.current.barBorderWidth ?? 0) === modelData
                            implicitWidth: 42
                            implicitHeight: 28
                            radius: 14
                            color: selected ? Theme.accent
                                 : bwMouse.containsMouse ? Theme.componentHover
                                 : Theme.component

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData + "px"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: parent.selected ? Font.DemiBold : Font.Normal
                                color: parent.selected ? Theme.fgOnAccent : Theme.text
                            }
                            MouseArea {
                                id: bwMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ThemeConfig.setSetting("barBorderWidth", modelData)
                            }
                        }
                    }
                }
            }

            ThemeSliderRow {
                label: "Border Opacity"
                subtitle: "Alpha of Panel Border Tint on outer strokes"
                value: Number(ThemeConfig.current.borderAlpha ?? 0.20)
                from: 0.0
                to: 1.0
                wheelStep: 0.02
                defaultValue: 0.20
                valueText: root.pct(ThemeConfig.current.borderAlpha ?? 0.20)
                onMoved: v => ThemeConfig.setSetting("borderAlpha", Math.round(v * 50) / 50)
                onResetClicked: ThemeConfig.setSetting("borderAlpha", 0.20)
            }
        }
    }
}
