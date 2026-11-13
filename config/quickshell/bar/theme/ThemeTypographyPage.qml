import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// UI & monospace font selection, font/icon sizing, and animation speed scale.
ColumnLayout {
    id: root

    property bool browseFonts: false
    property string searchQuery: ""

    readonly property var uiPresets: ["Fira Sans", "Cantarell", "Noto Sans", "Roboto", "DejaVu Sans"]
    readonly property var monoPresets: [
        "JetBrainsMono Nerd Font",
        "FiraCode Nerd Font",
        "Fira Mono",
        "Noto Sans Mono",
        "DejaVu Sans Mono"
    ]

    readonly property var installedFamilies: {
        const raw = Qt.fontFamilies();
        const out = [];
        for (let i = 0; i < raw.length; i++) {
            const f = String(raw[i] || "").trim();
            if (!f) continue;
            if (f.indexOf("Material Symbols") >= 0) continue;
            out.push(f);
        }
        return out;
    }

    readonly property var filteredFonts: {
        const q = root.searchQuery.trim().toLowerCase();
        if (!q) return root.installedFamilies;
        return root.installedFamilies.filter(f => f.toLowerCase().indexOf(q) >= 0);
    }

    readonly property var visibleUiPresets: {
        const present = root.uiPresets.filter(f => root.installedFamilies.indexOf(f) >= 0);
        return present.length > 0 ? present : root.uiPresets;
    }

    readonly property var visibleMonoPresets: {
        const present = root.monoPresets.filter(f => root.installedFamilies.indexOf(f) >= 0);
        return present.length > 0 ? present : root.monoPresets;
    }

    Connections {
        target: ThemeConfig
        function onCurrentChanged() {
            monoField.text = String(ThemeConfig.current.monoFamily || "JetBrainsMono Nerd Font");
        }
    }

    Layout.fillWidth: true
    spacing: Theme.spaceM

    // ---- UI Font Card ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: uiFontCol.implicitHeight + 2 * Theme.spaceS
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.divider

        ColumnLayout {
            id: uiFontCol
            anchors.fill: parent
            anchors.margins: Theme.spaceS
            spacing: Theme.spaceXs

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                Icon { icon: "font_download"; size: 17; color: Theme.accent }
                StyledText {
                    Layout.fillWidth: true
                    text: "UI Font Family"
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }
                StyledText {
                    text: ThemeConfig.current.fontFamily || "Fira Sans"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.accent
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.visibleUiPresets
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool selected: ThemeConfig.current.fontFamily === modelData
                        implicitWidth: uiLbl.implicitWidth + 18
                        implicitHeight: 28
                        radius: 14
                        color: selected ? Theme.accent
                             : uiPillMouse.containsMouse ? Theme.componentHover
                             : Theme.component
                        border.width: 1
                        border.color: selected ? Theme.accent : Theme.divider

                        StyledText {
                            id: uiLbl
                            anchors.centerIn: parent
                            text: parent.modelData
                            font.family: parent.modelData
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: parent.selected ? Font.DemiBold : Font.Normal
                            color: parent.selected ? Theme.fgOnAccent : Theme.text
                        }

                        MouseArea {
                            id: uiPillMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ThemeConfig.setSetting("fontFamily", parent.modelData)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                TextField {
                    id: fontSearchField
                    Layout.fillWidth: true
                    placeholder: "Search installed fonts…"
                    onTextChanged: root.searchQuery = text
                }

                Rectangle {
                    implicitWidth: browseLbl.implicitWidth + 18
                    implicitHeight: 34
                    radius: 17
                    color: (root.browseFonts || root.searchQuery.trim() !== "") ? Theme.componentHover : Theme.component
                    border.width: 1
                    border.color: Theme.divider

                    StyledText {
                        id: browseLbl
                        anchors.centerIn: parent
                        text: (root.browseFonts || root.searchQuery.trim() !== "")
                            ? ("Hide (" + root.filteredFonts.length + ")")
                            : ("Browse (" + root.installedFamilies.length + ")")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.searchQuery.trim() !== "") {
                                fontSearchField.text = "";
                                root.searchQuery = "";
                                root.browseFonts = false;
                            } else {
                                root.browseFonts = !root.browseFonts;
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.browseFonts || root.searchQuery.trim() !== ""
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(184, Math.max(44, root.filteredFonts.length * 32 + 8))
                radius: Theme.radiusS
                color: Theme.secondary
                border.width: 1
                border.color: Theme.divider
                clip: true

                StyledText {
                    visible: root.filteredFonts.length === 0
                    anchors.centerIn: parent
                    text: "No matching installed fonts"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                }

                ListView {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 2
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.filteredFonts

                    delegate: Rectangle {
                        id: fontItem
                        required property string modelData
                        readonly property bool selected: ThemeConfig.current.fontFamily === modelData
                        width: ListView.view.width
                        height: 30
                        radius: Theme.radiusXs
                        color: selected ? Theme.alpha(Theme.accent, 0.16)
                             : fItemMouse.containsMouse ? Theme.alpha(Theme.surfaceTint, 0.08 * Theme.surfaceStrength)
                             : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            StyledText {
                                Layout.fillWidth: true
                                text: fontItem.modelData
                                font.family: fontItem.modelData
                                font.pixelSize: 13
                                color: fontItem.selected ? Theme.accent : Theme.text
                                elide: Text.ElideRight
                            }

                            Icon {
                                visible: fontItem.selected
                                icon: "check"
                                size: 15
                                color: Theme.accent
                            }
                        }

                        MouseArea {
                            id: fItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ThemeConfig.setSetting("fontFamily", fontItem.modelData)
                        }
                    }
                }
            }
        }
    }

    // ---- Monospace Font Card ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: monoCol.implicitHeight + 2 * Theme.spaceS
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.divider

        ColumnLayout {
            id: monoCol
            anchors.fill: parent
            anchors.margins: Theme.spaceS
            spacing: Theme.spaceXs

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                Icon { icon: "code"; size: 17; color: Theme.accent }
                StyledText {
                    Layout.fillWidth: true
                    text: "Monospace & Tabular Font"
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.visibleMonoPresets
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool selected: ThemeConfig.current.monoFamily === modelData
                        implicitWidth: monoLbl.implicitWidth + 16
                        implicitHeight: 28
                        radius: 14
                        color: selected ? Theme.accent
                             : monoPillMouse.containsMouse ? Theme.componentHover
                             : Theme.component
                        border.width: 1
                        border.color: selected ? Theme.accent : Theme.divider

                        StyledText {
                            id: monoLbl
                            anchors.centerIn: parent
                            text: parent.modelData
                            font.family: parent.modelData
                            font.pixelSize: 11
                            color: parent.selected ? Theme.fgOnAccent : Theme.text
                        }

                        MouseArea {
                            id: monoPillMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ThemeConfig.setSetting("monoFamily", parent.modelData)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                TextField {
                    id: monoField
                    Layout.fillWidth: true
                    text: ThemeConfig.current.monoFamily || "JetBrainsMono Nerd Font"
                    placeholder: "Custom monospace font name"
                    onAccepted: {
                        const t = text.trim();
                        if (t) ThemeConfig.setSetting("monoFamily", t);
                    }
                }

                Rectangle {
                    implicitWidth: applyMonoLbl.implicitWidth + 18
                    implicitHeight: 32
                    radius: 16
                    color: applyMonoMouse.pressed ? Theme.componentPressed
                         : applyMonoMouse.containsMouse ? Theme.componentHover
                         : Theme.component

                    StyledText {
                        id: applyMonoLbl
                        anchors.centerIn: parent
                        text: "Apply"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }
                    MouseArea {
                        id: applyMonoMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const t = monoField.text.trim();
                            if (t) ThemeConfig.setSetting("monoFamily", t);
                        }
                    }
                }
            }
        }
    }

    // ---- Typography & Icon Sizes Card ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: sizesCol.implicitHeight + 2 * Theme.spaceS
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.divider

        ColumnLayout {
            id: sizesCol
            anchors.fill: parent
            anchors.margins: Theme.spaceS
            spacing: Theme.spaceS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                Icon { icon: "format_size"; size: 17; color: Theme.accent }
                StyledText {
                    Layout.fillWidth: true
                    text: "Text & Icon Sizing"
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }
            }

            ThemeSliderRow {
                label: "Body Font Size"
                subtitle: "Menus, cards & controls (scales small & title text)"
                value: Number(ThemeConfig.current.fontSize ?? 14)
                from: 10
                to: 22
                wheelStep: 1
                defaultValue: 14
                valueText: (ThemeConfig.current.fontSize ?? 14) + "px"
                onMoved: v => ThemeConfig.setSetting("fontSize", Math.round(v))
                onResetClicked: ThemeConfig.setSetting("fontSize", 14)
            }

            ThemeSliderRow {
                label: "Bar Font Size"
                subtitle: "Workspaces, clock, weather & labels in top bar"
                value: Number(ThemeConfig.current.barFontSize ?? 16)
                from: 10
                to: 24
                wheelStep: 1
                defaultValue: 16
                valueText: (ThemeConfig.current.barFontSize ?? 16) + "px"
                onMoved: v => ThemeConfig.setSetting("barFontSize", Math.round(v))
                onResetClicked: ThemeConfig.setSetting("barFontSize", 16)
            }

            ThemeSliderRow {
                label: "UI Icon Size"
                subtitle: "Popup & Quick Settings symbols"
                value: Number(ThemeConfig.current.iconSize ?? 18)
                from: 12
                to: 28
                wheelStep: 1
                defaultValue: 18
                valueText: (ThemeConfig.current.iconSize ?? 18) + "px"
                onMoved: v => ThemeConfig.setSetting("iconSize", Math.round(v))
                onResetClicked: ThemeConfig.setSetting("iconSize", 18)
            }

            ThemeSliderRow {
                label: "Bar Icon Size"
                subtitle: "Material icons inside top bar buttons"
                value: Number(ThemeConfig.current.barIconSize ?? 19)
                from: 12
                to: 28
                wheelStep: 1
                defaultValue: 19
                valueText: (ThemeConfig.current.barIconSize ?? 19) + "px"
                onMoved: v => ThemeConfig.setSetting("barIconSize", Math.round(v))
                onResetClicked: ThemeConfig.setSetting("barIconSize", 19)
            }
        }
    }

    // ---- Motion Speed Card ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: motionCol.implicitHeight + 2 * Theme.spaceS
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.divider

        ColumnLayout {
            id: motionCol
            anchors.fill: parent
            anchors.margins: Theme.spaceS
            spacing: Theme.spaceS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                Icon { icon: "animation"; size: 17; color: Theme.accent }
                StyledText {
                    Layout.fillWidth: true
                    text: "Animation Speed"
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }

                RowLayout {
                    spacing: 4
                    Repeater {
                        model: [
                            { label: "Instant", val: 0.00 },
                            { label: "Snappy",  val: 0.65 },
                            { label: "Default", val: 1.00 },
                            { label: "Relaxed", val: 1.50 }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool selected: Math.abs((ThemeConfig.current.animScale ?? 1.0) - modelData.val) < 0.02
                            implicitWidth: spdLbl.implicitWidth + 14
                            implicitHeight: 26
                            radius: 13
                            color: selected ? Theme.accent
                                 : spdMouse.containsMouse ? Theme.componentHover
                                 : Theme.component

                            StyledText {
                                id: spdLbl
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: parent.selected ? Font.DemiBold : Font.Normal
                                color: parent.selected ? Theme.fgOnAccent : Theme.text
                            }
                            MouseArea {
                                id: spdMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ThemeConfig.setSetting("animScale", modelData.val)
                            }
                        }
                    }
                }
            }

            ThemeSliderRow {
                label: "Transition Duration Scale"
                subtitle: "Multiplier for hover fades, toggles & slider springs (0 = instant)"
                value: Number(ThemeConfig.current.animScale ?? 1.0)
                from: 0.0
                to: 2.0
                wheelStep: 0.05
                defaultValue: 1.0
                valueText: (ThemeConfig.current.animScale ?? 1.0) <= 0.01
                    ? "Off"
                    : Number(ThemeConfig.current.animScale ?? 1.0).toFixed(2) + "x"
                onMoved: v => ThemeConfig.setSetting("animScale", Math.round(v * 20) / 20)
                onResetClicked: ThemeConfig.setSetting("animScale", 1.0)
            }
        }
    }
}
