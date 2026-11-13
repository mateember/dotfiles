import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Color palette editor: tone & accent quick controls, latched HSL+A inspector,
// hyprpicker eyedropper, and categorized color slot cards.
ColumnLayout {
    id: root

    property string selectedKey: "accent"
    property real editorH: 40
    property real editorS: 1.0
    property real editorL: 0.5
    property real editorA: 1.0
    property string lastCommittedHex: ""
    property bool syncLock: false

    readonly property var colorGroups: [
        {
            title: "Accent & Interactive",
            slots: [
                { key: "accent", label: "Accent", desc: "Active widgets, highlights & sliders", alpha: false },
                { key: "accentHover", label: "Accent Hover", desc: "Hovered primary accent controls", alpha: false, derived: true },
                { key: "accentPressed", label: "Accent Pressed", desc: "Pressed primary accent controls", alpha: false, derived: true },
                { key: "fgOnAccent", label: "On Accent", desc: "Text & icons placed inside Accent fills", alpha: false, derived: true },
                { key: "button", label: "Button Fill", desc: "Neutral button background (supports alpha)", alpha: true },
                { key: "buttonHover", label: "Button Hover", desc: "Hovered neutral button fill", alpha: true },
                { key: "buttonPressed", label: "Button Pressed", desc: "Pressed neutral button fill", alpha: true },
                { key: "iconButtonOn", label: "Icon Tint", desc: "Default subtle icon button glyph color", alpha: true }
            ]
        },
        {
            title: "Surfaces & Typography",
            slots: [
                { key: "bg", label: "Background", desc: "Outer popup, window & bar base surface", alpha: false },
                { key: "primary", label: "Primary Surface", desc: "Grouped option cards & popovers", alpha: false },
                { key: "secondary", label: "Secondary Surface", desc: "Elevated subcards, pills & track fills", alpha: false },
                { key: "text", label: "Body Text", desc: "Standard labels & body typography", alpha: false },
                { key: "textStrong", label: "Heading Text", desc: "Titles & emphasized labels", alpha: false },
                { key: "textDim", label: "Muted Text", desc: "Subtitles, captions & secondary info", alpha: true },
                { key: "surfaceTint", label: "Overlay Tint", desc: "Hover & glass sheen tint color", alpha: false }
            ]
        },
        {
            title: "Borders & Semantic Status",
            slots: [
                { key: "borderColor", label: "Panel Border Tint", desc: "Outer popup & bar stroke hue", alpha: false },
                { key: "componentBorder", label: "Control Border", desc: "Input fields & bordered controls", alpha: false },
                { key: "bgDivider", label: "Card Divider", desc: "Borders separating surface cards", alpha: false },
                { key: "primaryDivider", label: "Inner Divider", desc: "Separators inside popups & cards", alpha: false },
                { key: "destructive", label: "Destructive", desc: "Errors, critical alerts & delete buttons", alpha: false },
                { key: "success", label: "Success", desc: "Connected & healthy state badges", alpha: false },
                { key: "warning", label: "Warning", desc: "Caution, medium load & attention cues", alpha: false }
            ]
        }
    ]

    function slotMeta(key) {
        for (let g = 0; g < colorGroups.length; g++) {
            const slots = colorGroups[g].slots;
            for (let s = 0; s < slots.length; s++) {
                if (slots[s].key === key) return slots[s];
            }
        }
        return colorGroups[0].slots[0];
    }

    readonly property var activeSlot: slotMeta(selectedKey)
    readonly property string activeHex: String(ThemeConfig.current[selectedKey] || "#FFAD00")
    readonly property string defaultSlotHex: String(ThemeConfig.defaultSettings()[selectedKey] || "#FFAD00")
    readonly property bool currentIsLight: ThemeConfig.isLightHex(ThemeConfig.current.bg || "#1B1B1B")

    function syncInspectorFromCurrent(forceHue) {
        const hex = String(ThemeConfig.current[root.selectedKey] || "#FFAD00");
        if (!forceHue && hex === root.lastCommittedHex) return;
        const c = ThemeConfig.hexRgbComponents(hex);
        const hsl = ThemeConfig.rgbToHsl(c.r, c.g, c.b);
        root.syncLock = true;
        if (forceHue || hsl.s > 0.005) root.editorH = hsl.h;
        root.editorS = hsl.s;
        root.editorL = hsl.l;
        root.editorA = c.a;
        hexField.text = hex;
        root.lastCommittedHex = hex;
        root.syncLock = false;
    }

    function selectSlot(key) {
        root.selectedKey = key;
        root.lastCommittedHex = "";
        syncInspectorFromCurrent(true);
    }

    function commitHex(rawHex) {
        const meta = root.activeSlot;
        const clean = ThemeConfig.normalizeHex(rawHex, root.activeHex, meta.alpha);
        root.lastCommittedHex = clean;
        const c = ThemeConfig.hexRgbComponents(clean);
        const hsl = ThemeConfig.rgbToHsl(c.r, c.g, c.b);
        if (hsl.s > 0.005) root.editorH = hsl.h;
        root.editorS = hsl.s;
        root.editorL = hsl.l;
        root.editorA = c.a;
        hexField.text = clean;
        if (meta.derived && ThemeConfig.current.autoAccentDerived) {
            const patch = { autoAccentDerived: false };
            patch[meta.key] = clean;
            ThemeConfig.setSettings(patch, false);
        } else {
            ThemeConfig.setSetting(meta.key, clean);
        }
    }

    function commitInspectorHsl() {
        if (root.syncLock) return;
        const meta = root.activeSlot;
        const includeAlpha = meta.alpha && root.editorA < 0.999;
        const hex = ThemeConfig.hslToHex(root.editorH, root.editorS, root.editorL, root.editorA, includeAlpha);
        root.lastCommittedHex = hex;
        hexField.text = hex;
        if (meta.derived && ThemeConfig.current.autoAccentDerived) {
            const patch = { autoAccentDerived: false };
            patch[meta.key] = hex;
            ThemeConfig.setSettings(patch, false);
        } else {
            ThemeConfig.setSetting(meta.key, hex);
        }
    }

    Component.onCompleted: syncInspectorFromCurrent(true)

    Connections {
        target: ThemeConfig
        function onCurrentChanged() {
            root.syncInspectorFromCurrent(false);
        }
    }

    Layout.fillWidth: true
    spacing: Theme.spaceM

    // Inline gradient channel slider component for Hue / Saturation / Lightness / Alpha
    component ChannelSlider: Item {
        id: ch

        property string label: ""
        property real value: 0
        property real to: 1
        property string valueText: ""
        property bool showChecker: false
        property color startColor: "#000000"
        property color midColor: "#808080"
        property color endColor: "#FFFFFF"
        property bool rainbow: false
        property bool threeStop: false

        signal moved(real newValue)

        readonly property real fraction: Math.max(0, Math.min(1, to > 0 ? value / to : 0))

        Layout.fillWidth: true
        implicitHeight: 28

        RowLayout {
            anchors.fill: parent
            spacing: Theme.spaceXs

            StyledText {
                Layout.preferredWidth: 74
                text: ch.label
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textDim
            }

            Item {
                id: trackBox
                Layout.fillWidth: true
                Layout.preferredHeight: 18

                // Checker-like dark/light split for alpha channel clarity
                Row {
                    visible: ch.showChecker
                    anchors.fill: parent
                    anchors.margins: 2
                    clip: true
                    Rectangle { width: parent.width / 2; height: parent.height; color: "#2A2A2A" }
                    Rectangle { width: parent.width / 2; height: parent.height; color: "#D4D4D4" }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 12
                    radius: 6
                    border.width: 1
                    border.color: Theme.divider
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: ch.rainbow ? "#FF0000" : ch.startColor }
                        GradientStop {
                            position: ch.rainbow ? 0.167 : 0.5
                            color: ch.rainbow ? "#FFFF00"
                                 : ch.threeStop ? ch.midColor
                                 : Qt.rgba((ch.startColor.r + ch.endColor.r) * 0.5,
                                           (ch.startColor.g + ch.endColor.g) * 0.5,
                                           (ch.startColor.b + ch.endColor.b) * 0.5,
                                           (ch.startColor.a + ch.endColor.a) * 0.5)
                        }
                        GradientStop { position: ch.rainbow ? 0.333 : 1.0; color: ch.rainbow ? "#00FF00" : ch.endColor }
                        GradientStop { position: ch.rainbow ? 0.500 : 1.0; color: ch.rainbow ? "#00FFFF" : ch.endColor }
                        GradientStop { position: ch.rainbow ? 0.667 : 1.0; color: ch.rainbow ? "#0000FF" : ch.endColor }
                        GradientStop { position: ch.rainbow ? 0.833 : 1.0; color: ch.rainbow ? "#FF00FF" : ch.endColor }
                        GradientStop { position: 1.0; color: ch.rainbow ? "#FF0000" : ch.endColor }
                    }
                }

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    y: (parent.height - height) / 2
                    x: Math.max(0, Math.min(parent.width - width, ch.fraction * (parent.width - width)))
                    color: "#FFFFFF"
                    border.width: 2
                    border.color: "#1B1B1B"
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    function pushX(mx) {
                        const t = Math.max(0, Math.min(1, mx / Math.max(1, width)));
                        ch.moved(t * ch.to);
                    }
                    onPressed: mouse => pushX(mouse.x)
                    onPositionChanged: mouse => { if (pressed) pushX(mouse.x); }
                    onWheel: wheel => {
                        const step = (wheel.angleDelta.y > 0 ? 1 : -1) * (ch.to * 0.02);
                        ch.moved(Math.max(0, Math.min(ch.to, ch.value + step)));
                    }
                }
            }

            StyledText {
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
                text: ch.valueText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
                color: Theme.text
            }
        }
    }

    // ---- Quick Tone & Accent Card ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: quickCol.implicitHeight + 2 * Theme.spaceS
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.divider

        ColumnLayout {
            id: quickCol
            anchors.fill: parent
            anchors.margins: Theme.spaceS
            spacing: Theme.spaceXs

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                Icon { icon: "contrast"; size: 17; color: Theme.accent }
                StyledText {
                    Layout.fillWidth: true
                    text: "Tone & Accent"
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }

                // Base Dark / Light switcher preserving accent & geometry
                RowLayout {
                    spacing: 4

                    Repeater {
                        model: [
                            { label: "Dark Surfaces", light: false },
                            { label: "Light Surfaces", light: true }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool selected: root.currentIsLight === modelData.light
                            implicitWidth: toneLbl.implicitWidth + 18
                            implicitHeight: 26
                            radius: 13
                            color: selected ? Theme.accent
                                 : toneMouse.containsMouse ? Theme.componentHover
                                 : Theme.component

                            StyledText {
                                id: toneLbl
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: selected ? Font.DemiBold : Font.Normal
                                color: selected ? Theme.fgOnAccent : Theme.text
                            }
                            MouseArea {
                                id: toneMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ThemeConfig.applyBaseTone(modelData.light);
                                    root.syncInspectorFromCurrent(true);
                                }
                            }
                        }
                    }
                }
            }

            // Curated accent swatches
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                StyledText {
                    Layout.preferredWidth: 100
                    text: "Quick Accent"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: ThemeConfig.curatedAccents
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool selected: String(ThemeConfig.current.accent || "").toUpperCase() === modelData.hex
                            width: 26
                            height: 26
                            radius: 13
                            color: modelData.hex
                            border.width: selected ? 2.5 : 1
                            border.color: selected ? Theme.textStrong : Theme.alpha(Theme.borderColor, 0.32)

                            Icon {
                                visible: parent.selected
                                anchors.centerIn: parent
                                icon: "check"
                                size: 14
                                color: ThemeConfig.isLightHex(parent.modelData.hex) ? "#000000" : "#FFFFFF"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ThemeConfig.setSetting("accent", modelData.hex);
                                    root.selectSlot("accent");
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        text: "Auto-derive hover, pressed & foreground"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }
                    StyledText {
                        text: "Updates Accent Hover, Accent Pressed & On Accent whenever Accent changes."
                        font.pixelSize: Math.max(10, Theme.fontSizeSmall - 1)
                        color: Theme.textDim
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                Toggle {
                    checked: Boolean(ThemeConfig.current.autoAccentDerived)
                    onToggled: ThemeConfig.setAutoAccentDerived(!ThemeConfig.current.autoAccentDerived)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                StyledText {
                    Layout.fillWidth: true
                    text: "Picked a custom Background? Match surfaces, dividers & text readability automatically:"
                    font.pixelSize: Math.max(10, Theme.fontSizeSmall - 1)
                    color: Theme.textDim
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    implicitWidth: adaptLbl.implicitWidth + 18
                    implicitHeight: 28
                    radius: 14
                    color: adaptMouse.pressed ? Theme.componentPressed
                         : adaptMouse.containsMouse ? Theme.componentHover
                         : Theme.component
                    border.width: 1
                    border.color: Theme.divider

                    StyledText {
                        id: adaptLbl
                        anchors.centerIn: parent
                        text: "Adapt to Background"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }

                    MouseArea {
                        id: adaptMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ThemeConfig.adaptToneForBackground(ThemeConfig.current.bg, true);
                            root.syncInspectorFromCurrent(true);
                        }
                    }
                }
            }
        }
    }

    // ---- Inline Color Inspector ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: inspCol.implicitHeight + 2 * Theme.spaceS
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.45)

        ColumnLayout {
            id: inspCol
            anchors.fill: parent
            anchors.margins: Theme.spaceS
            spacing: Theme.spaceXs

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceS

                // Large color swatch with dark/light backing for alpha visibility
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: Theme.radiusS
                    border.width: 1
                    border.color: Theme.divider
                    clip: true

                    Row {
                        anchors.fill: parent
                        Rectangle { width: parent.width / 2; height: parent.height; color: "#202020" }
                        Rectangle { width: parent.width / 2; height: parent.height; color: "#DCDCDC" }
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: root.activeHex
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            text: root.activeSlot.label
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.DemiBold
                            color: Theme.textStrong
                        }
                        Rectangle {
                            visible: Boolean(root.activeSlot.derived) && Boolean(ThemeConfig.current.autoAccentDerived)
                            implicitWidth: autoTag.implicitWidth + 10
                            implicitHeight: 17
                            radius: 8.5
                            color: Theme.component
                            StyledText {
                                id: autoTag
                                anchors.centerIn: parent
                                text: "Auto"
                                font.pixelSize: 10
                                color: Theme.textDim
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.activeSlot.desc
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textDim
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    visible: root.activeHex.toUpperCase() !== root.defaultSlotHex.toUpperCase()
                    icon: "restart_alt"
                    onClicked: {
                        if (root.selectedKey === "accent" && !ThemeConfig.current.autoAccentDerived) {
                            ThemeConfig.setSetting("accent", root.defaultSlotHex);
                        } else {
                            ThemeConfig.setSetting(root.selectedKey, root.defaultSlotHex);
                        }
                        root.syncInspectorFromCurrent(true);
                    }
                }
            }

            // Latched HSL + optional Alpha sliders
            ChannelSlider {
                label: "Hue"
                value: root.editorH
                to: 360
                rainbow: true
                valueText: Math.round(root.editorH) + "°"
                onMoved: v => {
                    root.editorH = v;
                    root.commitInspectorHsl();
                }
            }

            ChannelSlider {
                label: "Saturation"
                value: root.editorS
                to: 1.0
                startColor: ThemeConfig.hslToHex(root.editorH, 0, Math.max(0.18, Math.min(0.82, root.editorL)), 1, false)
                endColor: ThemeConfig.hslToHex(root.editorH, 1, Math.max(0.18, Math.min(0.82, root.editorL)), 1, false)
                valueText: Math.round(root.editorS * 100) + "%"
                onMoved: v => {
                    root.editorS = v;
                    root.commitInspectorHsl();
                }
            }

            ChannelSlider {
                label: "Lightness"
                value: root.editorL
                to: 1.0
                threeStop: true
                startColor: "#000000"
                midColor: ThemeConfig.hslToHex(root.editorH, Math.max(0.05, root.editorS), 0.5, 1, false)
                endColor: "#FFFFFF"
                valueText: Math.round(root.editorL * 100) + "%"
                onMoved: v => {
                    root.editorL = v;
                    root.commitInspectorHsl();
                }
            }

            ChannelSlider {
                visible: Boolean(root.activeSlot.alpha)
                label: "Opacity"
                value: root.editorA
                to: 1.0
                showChecker: true
                startColor: "transparent"
                endColor: ThemeConfig.hslToHex(root.editorH, root.editorS, root.editorL, 1.0, false)
                valueText: Math.round(root.editorA * 100) + "%"
                onMoved: v => {
                    root.editorA = v;
                    root.commitInspectorHsl();
                }
            }

            // Hex input + Eyedropper row
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                StyledText {
                    Layout.preferredWidth: 74
                    text: "Hex"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                }

                TextField {
                    id: hexField
                    Layout.fillWidth: true
                    placeholder: root.activeSlot.alpha ? "#RRGGBB or #AARRGGBB" : "#RRGGBB"
                    onAccepted: root.commitHex(text)
                }

                Rectangle {
                    implicitWidth: applyHexLbl.implicitWidth + 18
                    implicitHeight: 32
                    radius: 16
                    color: applyHexMouse.pressed ? Theme.componentPressed
                         : applyHexMouse.containsMouse ? Theme.componentHover
                         : Theme.component

                    StyledText {
                        id: applyHexLbl
                        anchors.centerIn: parent
                        text: "Apply"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }
                    MouseArea {
                        id: applyHexMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.commitHex(hexField.text)
                    }
                }

                Rectangle {
                    implicitWidth: pickRow.implicitWidth + 16
                    implicitHeight: 32
                    radius: 16
                    color: pickMouse.pressed ? Theme.componentPressed
                         : pickMouse.containsMouse ? Theme.componentHover
                         : Theme.component
                    border.width: 1
                    border.color: Theme.divider

                    RowLayout {
                        id: pickRow
                        anchors.centerIn: parent
                        spacing: 4
                        Icon { icon: "colorize"; size: 15; color: Theme.accent }
                        StyledText {
                            text: "Pick"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.text
                        }
                    }

                    MouseArea {
                        id: pickMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ThemeConfig.pickingColor = true;
                            ColorPicker.pickWith(hex => {
                                ThemeConfig.pickingColor = false;
                                if (hex) root.commitHex(hex);
                            });
                        }
                    }
                }
            }
        }
    }

    // ---- Surface Elevation Contrast ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: contrastCol.implicitHeight + 2 * Theme.spaceS
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.divider

        ColumnLayout {
            id: contrastCol
            anchors.fill: parent
            anchors.margins: Theme.spaceS
            spacing: Theme.spaceXs

            ThemeSliderRow {
                label: "Surface Contrast"
                subtitle: "Strength of subtle card & hover overlays"
                value: Number(ThemeConfig.current.surfaceStrength ?? 1.0)
                from: 0.3
                to: 2.5
                wheelStep: 0.05
                defaultValue: 1.0
                valueText: Math.round((ThemeConfig.current.surfaceStrength ?? 1.0) * 100) + "%"
                onMoved: v => ThemeConfig.setSetting("surfaceStrength", Math.round(v * 20) / 20)
                onResetClicked: ThemeConfig.setSetting("surfaceStrength", 1.0)
            }
        }
    }

    // ---- Grouped Color Slots ----
    Repeater {
        model: root.colorGroups

        delegate: Rectangle {
            id: groupCard
            required property var modelData

            Layout.fillWidth: true
            implicitHeight: groupCol.implicitHeight + 2 * Theme.spaceS
            radius: Theme.radiusM
            color: Theme.surface0
            border.width: 1
            border.color: Theme.divider

            ColumnLayout {
                id: groupCol
                anchors.fill: parent
                anchors.margins: Theme.spaceS
                spacing: Theme.spaceXs

                StyledText {
                    text: groupCard.modelData.title
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Theme.spaceXs
                    rowSpacing: Theme.spaceXs

                    Repeater {
                        model: groupCard.modelData.slots

                        delegate: Rectangle {
                            id: slotTile
                            required property var modelData
                            readonly property bool selected: root.selectedKey === modelData.key
                            readonly property string hex: String(ThemeConfig.current[modelData.key] || "#000000")

                            Layout.fillWidth: true
                            implicitHeight: 46
                            radius: Theme.radiusS
                            color: selected ? Theme.alpha(Theme.accent, 0.14)
                                 : tileMouse.containsMouse ? Theme.alpha(Theme.surfaceTint, 0.06 * Theme.surfaceStrength)
                                 : Theme.secondary
                            border.width: selected ? 1.5 : 1
                            border.color: selected ? Theme.accent : Theme.divider

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spaceXs
                                spacing: Theme.spaceXs

                                Rectangle {
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    radius: 6
                                    border.width: 1
                                    border.color: Theme.divider
                                    clip: true

                                    Row {
                                        visible: Boolean(slotTile.modelData.alpha)
                                        anchors.fill: parent
                                        Rectangle { width: parent.width / 2; height: parent.height; color: "#202020" }
                                        Rectangle { width: parent.width / 2; height: parent.height; color: "#DCDCDC" }
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: slotTile.hex
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: slotTile.modelData.label
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: slotTile.selected ? Font.DemiBold : Font.Normal
                                        color: Theme.textStrong
                                        elide: Text.ElideRight
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: slotTile.hex
                                        font.pixelSize: 10
                                        font.features: ({ "tnum": 1 })
                                        color: Theme.textDim
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: tileMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectSlot(slotTile.modelData.key)
                            }
                        }
                    }
                }
            }
        }
    }
}
