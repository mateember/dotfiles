import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Corner rounding presets & sliders plus top bar and popup geometry controls.
ColumnLayout {
    id: root

    readonly property var shapePresets: [
        { kind: "sharp",   label: "Sharp",   desc: "0px square",  xs: 0, s: 0,  m: 0,  l: 0,  bar: 0   },
        { kind: "crisp",   label: "Crisp",   desc: "Subtle 8px",  xs: 2, s: 4,  m: 8,  l: 16, bar: 10  },
        { kind: "default", label: "COSMIC",  desc: "Default",     xs: 4, s: 8,  m: 16, l: 32, bar: 160 },
        { kind: "plush",   label: "Plush",   desc: "Soft 22px",   xs: 6, s: 12, m: 22, l: 36, bar: 160 }
    ]

    function matchesShape(p) {
        const c = ThemeConfig.current;
        return c.radiusXs === p.xs && c.radiusS === p.s && c.radiusM === p.m
            && c.radiusL === p.l && c.barRadius === p.bar;
    }

    Layout.fillWidth: true
    spacing: Theme.spaceM

    // ---- Corner Shape Presets ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: shapeCol.implicitHeight + 2 * Theme.spaceS
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.divider

        ColumnLayout {
            id: shapeCol
            anchors.fill: parent
            anchors.margins: Theme.spaceS
            spacing: Theme.spaceXs

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                Icon { icon: "rounded_corner"; size: 17; color: Theme.accent }
                StyledText {
                    Layout.fillWidth: true
                    text: "Corner Rounding"
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                Repeater {
                    model: root.shapePresets
                    delegate: Rectangle {
                        id: shapeCard
                        required property var modelData
                        readonly property bool active: root.matchesShape(modelData)

                        Layout.fillWidth: true
                        implicitHeight: shCol.implicitHeight + 14
                        radius: Theme.radiusS
                        color: active ? Theme.accent
                             : shMouse.containsMouse ? Theme.componentHover
                             : Theme.component
                        border.width: 1
                        border.color: active ? Theme.accent : Theme.divider

                        ColumnLayout {
                            id: shCol
                            anchors.centerIn: parent
                            spacing: 1

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: shapeCard.modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: shapeCard.active ? Font.DemiBold : Font.Medium
                                color: shapeCard.active ? Theme.fgOnAccent : Theme.textStrong
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: shapeCard.modelData.desc
                                font.pixelSize: 10
                                color: shapeCard.active ? Theme.fgOnAccent : Theme.textDim
                            }
                        }

                        MouseArea {
                            id: shMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ThemeConfig.applyRadiusPreset(shapeCard.modelData.kind)
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

            ThemeSliderRow {
                label: "Bar Corner Radius"
                subtitle: "Use max for full capsule pill"
                value: Number(ThemeConfig.current.barRadius ?? 160)
                from: 0
                to: 160
                wheelStep: 2
                defaultValue: 160
                valueText: (ThemeConfig.current.barRadius ?? 160) >= 160 ? "Pill" : ((ThemeConfig.current.barRadius ?? 160) + "px")
                onMoved: v => ThemeConfig.setSetting("barRadius", Math.round(v))
                onResetClicked: ThemeConfig.setSetting("barRadius", 160)
            }

            ThemeSliderRow {
                label: "Card & Popup Radius"
                subtitle: "Windows, popups & large cards"
                value: Number(ThemeConfig.current.radiusM ?? 16)
                from: 0
                to: 36
                wheelStep: 1
                defaultValue: 16
                valueText: (ThemeConfig.current.radiusM ?? 16) + "px"
                onMoved: v => ThemeConfig.setSetting("radiusM", Math.round(v))
                onResetClicked: ThemeConfig.setSetting("radiusM", 16)
            }

            ThemeSliderRow {
                label: "Control Radius"
                subtitle: "Tiles, inputs & list items"
                value: Number(ThemeConfig.current.radiusS ?? 8)
                from: 0
                to: 24
                wheelStep: 1
                defaultValue: 8
                valueText: (ThemeConfig.current.radiusS ?? 8) + "px"
                onMoved: v => ThemeConfig.setSetting("radiusS", Math.round(v))
                onResetClicked: ThemeConfig.setSetting("radiusS", 8)
            }

            ThemeSliderRow {
                label: "Badge & Tight Radius"
                subtitle: "Small meters & indicator pills"
                value: Number(ThemeConfig.current.radiusXs ?? 4)
                from: 0
                to: 14
                wheelStep: 1
                defaultValue: 4
                valueText: (ThemeConfig.current.radiusXs ?? 4) + "px"
                onMoved: v => ThemeConfig.setSetting("radiusXs", Math.round(v))
                onResetClicked: ThemeConfig.setSetting("radiusXs", 4)
            }

            ThemeSliderRow {
                label: "Large / Pill Radius"
                subtitle: "Lock card & circular caps"
                value: Number(ThemeConfig.current.radiusL ?? 32)
                from: 0
                to: 48
                wheelStep: 1
                defaultValue: 32
                valueText: (ThemeConfig.current.radiusL ?? 32) + "px"
                onMoved: v => ThemeConfig.setSetting("radiusL", Math.round(v))
                onResetClicked: ThemeConfig.setSetting("radiusL", 32)
            }
        }
    }

    // ---- Bar & Popup Geometry ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: geomCol.implicitHeight + 2 * Theme.spaceS
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.divider

        ColumnLayout {
            id: geomCol
            anchors.fill: parent
            anchors.margins: Theme.spaceS
            spacing: Theme.spaceS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                Icon { icon: "straighten"; size: 17; color: Theme.accent }
                StyledText {
                    Layout.fillWidth: true
                    text: "Bar & Popup Geometry"
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }
            }

            ThemeSliderRow {
                label: "Bar Height"
                subtitle: "Vertical thickness of the top bar"
                value: Number(ThemeConfig.current.barHeight ?? 35)
                from: 24
                to: 54
                wheelStep: 1
                defaultValue: 35
                valueText: (ThemeConfig.current.barHeight ?? 35) + "px"
                onMoved: v => ThemeConfig.setSetting("barHeight", Math.round(v))
                onResetClicked: ThemeConfig.setSetting("barHeight", 35)
            }

            ThemeSliderRow {
                label: "Bar Outer Margin"
                subtitle: "Gap from screen edges around bar (0 = edge-to-edge)"
                value: Number(ThemeConfig.current.panelMargin ?? 4)
                from: 0
                to: 24
                wheelStep: 1
                defaultValue: 4
                valueText: (ThemeConfig.current.panelMargin ?? 4) + "px"
                onMoved: v => ThemeConfig.setSetting("panelMargin", Math.round(v))
                onResetClicked: ThemeConfig.setSetting("panelMargin", 4)
            }

            ThemeSliderRow {
                label: "Workspace Dot Size"
                subtitle: "Circle diameter inside Workspaces"
                value: Number(ThemeConfig.current.workspaceCircle ?? 26)
                from: 18
                to: 40
                wheelStep: 1
                defaultValue: 26
                valueText: (ThemeConfig.current.workspaceCircle ?? 26) + "px"
                onMoved: v => ThemeConfig.setSetting("workspaceCircle", Math.round(v))
                onResetClicked: ThemeConfig.setSetting("workspaceCircle", 26)
            }

            ThemeSliderRow {
                label: "Popup Gap"
                subtitle: "Distance between top bar & open popups"
                value: Number(ThemeConfig.current.popupGap ?? 6)
                from: 0
                to: 24
                wheelStep: 1
                defaultValue: 6
                valueText: (ThemeConfig.current.popupGap ?? 6) + "px"
                onMoved: v => ThemeConfig.setSetting("popupGap", Math.round(v))
                onResetClicked: ThemeConfig.setSetting("popupGap", 6)
            }

            ThemeSliderRow {
                label: "Popup Width"
                subtitle: "Base width of bar dropdown menus"
                value: Number(ThemeConfig.current.popupWidth ?? 320)
                from: 260
                to: 460
                wheelStep: 10
                defaultValue: 320
                valueText: (ThemeConfig.current.popupWidth ?? 320) + "px"
                onMoved: v => ThemeConfig.setSetting("popupWidth", Math.round(v))
                onResetClicked: ThemeConfig.setSetting("popupWidth", 320)
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                StyledText {
                    Layout.fillWidth: true
                    text: "Spacing Density Presets"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                }

                RowLayout {
                    spacing: 4
                    Repeater {
                        model: [
                            { label: "Compact",  val: 0.80 },
                            { label: "Default",  val: 1.00 },
                            { label: "Spacious", val: 1.25 }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool selected: Math.abs((ThemeConfig.current.spacingScale ?? 1.0) - modelData.val) < 0.02
                            implicitWidth: densLbl.implicitWidth + 16
                            implicitHeight: 26
                            radius: 13
                            color: selected ? Theme.accent
                                 : densMouse.containsMouse ? Theme.componentHover
                                 : Theme.component

                            StyledText {
                                id: densLbl
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: parent.selected ? Font.DemiBold : Font.Normal
                                color: parent.selected ? Theme.fgOnAccent : Theme.text
                            }
                            MouseArea {
                                id: densMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ThemeConfig.setSetting("spacingScale", modelData.val)
                            }
                        }
                    }
                }
            }

            ThemeSliderRow {
                label: "Padding & Gap Scale"
                subtitle: "Scales internal padding across cards & menus"
                value: Number(ThemeConfig.current.spacingScale ?? 1.0)
                from: 0.65
                to: 1.50
                wheelStep: 0.05
                defaultValue: 1.0
                valueText: Math.round((ThemeConfig.current.spacingScale ?? 1.0) * 100) + "%"
                onMoved: v => ThemeConfig.setSetting("spacingScale", Math.round(v * 20) / 20)
                onResetClicked: ThemeConfig.setSetting("spacingScale", 1.0)
            }
        }
    }
}
