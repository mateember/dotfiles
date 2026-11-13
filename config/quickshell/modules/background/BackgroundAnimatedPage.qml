import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.components
import qs.services
import qs.wallpaper
import "../weather"

// Animated backgrounds tab:
//   1) Built-in Live GPU Shaders (5 scenes, curated/custom palettes, eyedropper, speed & intensity)
//   2) Animated GIF & short video loops (ffmpeg cached .gif, local ~/Videos & ~/Pictures scan)
//   + Shared Fullscreen & Power Saver pause controls.
ColumnLayout {
    id: root

    property bool popupOpen: false
    property bool isCurrentPage: false
    property bool returnAsWindow: false
    property string returnScreen: ""

    spacing: Theme.spaceXxs

    property var localAnimFiles: []

    readonly property var activePal: Wallpapers.activePalette()

    function scanLocalAnimated() {
        if (scanAnimProc.running) return;
        scanAnimProc.running = true;
    }

    onIsCurrentPageChanged: {
        if (isCurrentPage && Wallpapers.animatedKind === "file" && localAnimFiles.length === 0)
            scanLocalAnimated();
    }

    Connections {
        target: Wallpapers
        function onAnimatedKindChanged() {
            if (root.isCurrentPage && Wallpapers.animatedKind === "file" && root.localAnimFiles.length === 0)
                root.scanLocalAnimated();
        }
    }

    Process {
        id: scanAnimProc
        command: [
            "sh", "-c",
            'for d in "$HOME/Videos/Hidamari" "$HOME/Videos" "$HOME/Pictures" "$HOME/.local/share/backgrounds"; do ' +
            '  [ -d "$d" ] && find "$d" -maxdepth 3 -type f \\( -iname "*.gif" -o -iname "*.apng" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.m4v" \\) 2>/dev/null; ' +
            'done | awk \'!seen[$0]++\' | head -n 60'
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(l => l.trim()).filter(l => l !== "");
                root.localAnimFiles = lines.map(p => ({
                    path: p,
                    name: Wallpapers.baseName(p),
                    dir: Wallpapers.displayPath(p.slice(0, p.lastIndexOf("/"))),
                    isGif: Wallpapers.isGifPath(p),
                    isApng: Wallpapers.isApngPath(p),
                    isWebp: Wallpapers.isWebpPath(p)
                }));
            }
        }
    }

    function pickCustomSlot(slot: string) {
        const scr = root.returnScreen;
        const asWin = root.returnAsWindow;
        ColorPicker.pickWith(hex => {
            const bg = slot === "bg" ? hex : Wallpapers.customBg;
            const c1 = slot === "c1" ? hex : Wallpapers.customColor1;
            const c2 = slot === "c2" ? hex : Wallpapers.customColor2;
            Wallpapers.setCustomColors(bg, c1, c2);
            if (asWin) Popups.openWindow("background@" + scr);
            else Popups.open("background@" + scr);
        });
    }

    // ---- Sub-mode Switcher: Live Shaders vs GIF/Video Loop ----
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceXxs

        Repeater {
            model: [
                { id: "scene", label: "Live Shaders", icon: "auto_awesome" },
                { id: "file",  label: "Video / GIF / APNG", icon: "movie" }
            ]
            delegate: Rectangle {
                required property var modelData
                readonly property bool selected: Wallpapers.animatedKind === modelData.id

                Layout.fillWidth: true
                implicitHeight: 30
                radius: Theme.radiusXl
                color: selected ? Theme.accent
                     : subMouse.containsMouse ? Theme.componentHover
                     : Theme.component
                border.width: 1
                border.color: selected ? Theme.accent : Theme.componentDivider
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Icon { anchors.verticalCenter: parent.verticalCenter; icon: modelData.icon; size: 15; color: selected ? Theme.fgOnAccent : Theme.text }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: selected ? Font.DemiBold : Font.Normal
                        color: selected ? Theme.fgOnAccent : Theme.text
                    }
                }

                MouseArea {
                    id: subMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wallpapers.setAnimatedKind(modelData.id)
                }
            }
        }
    }

    // =========================================================================
    // LIVE GPU SHADERS VIEW
    // =========================================================================
    ColumnLayout {
        visible: Wallpapers.animatedKind === "scene"
        Layout.fillWidth: true
        spacing: Theme.spaceXxs

        // 5 Live Mini Shader Preview Cards (3 + 2 grid)
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 6
            rowSpacing: 6

            Repeater {
                model: Wallpapers.scenes
                delegate: ClippingRectangle {
                    required property var modelData
                    readonly property bool selected: Wallpapers.sceneId === modelData.id

                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: Theme.radiusXs
                    color: root.activePal.bg
                    border.width: selected ? 2 : 1
                    border.color: selected ? Theme.accent
                                : cardMouse.containsMouse ? Theme.componentBorder
                                : Theme.componentDivider

                    WallpaperScene {
                        anchors.fill: parent
                        mode: "animated"
                        animatedKind: "scene"
                        sceneId: modelData.id
                        paletteBg: root.activePal.bg
                        paletteC1: root.activePal.c1
                        paletteC2: root.activePal.c2
                        paletteC3: root.activePal.c3
                        animSpeed: Wallpapers.animSpeed
                        animIntensity: Wallpapers.animIntensity
                        blurAmount: 0
                        dimAmount: 0
                        paused: !root.popupOpen || !root.isCurrentPage || Wallpapers.animatedKind !== "scene"
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 22
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.78) }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 4

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.name
                                font.pixelSize: 11
                                font.weight: selected ? Font.DemiBold : Font.Normal
                                color: selected ? Theme.accent : Theme.textStrong
                                elide: Text.ElideRight
                            }

                            Icon {
                                visible: selected
                                icon: "check"
                                size: 13
                                color: Theme.accent
                            }
                        }
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpapers.setScene(modelData.id)
                    }
                }
            }
        }

        // Palette Swatch Strip
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            contentWidth: palRow.implicitWidth
            contentHeight: 28
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: palRow
                height: 28
                spacing: Theme.spaceXxxs

                Repeater {
                    model: Wallpapers.palettes
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool selected: Wallpapers.paletteId === modelData.id
                        readonly property color dotBg: modelData.id === "custom" ? Wallpapers.customBg : modelData.bg
                        readonly property color dotC1: modelData.id === "custom" ? Wallpapers.customColor1 : modelData.c1
                        readonly property color dotC2: modelData.id === "custom" ? Wallpapers.customColor2 : modelData.c2

                        height: 28
                        width: palContent.implicitWidth + 14
                        radius: Theme.radiusXl
                        color: selected ? Theme.surface2 : palMouse.containsMouse ? Theme.componentHover : Theme.component
                        border.width: selected ? 1.5 : 1
                        border.color: selected ? Theme.accent : Theme.componentDivider
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Row {
                            id: palContent
                            anchors.centerIn: parent
                            spacing: 4

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: -3
                                Rectangle { width: 10; height: 10; radius: 5; color: dotBg; border.width: 1; border.color: Theme.componentDivider }
                                Rectangle { width: 10; height: 10; radius: 5; color: dotC1; border.width: 1; border.color: Theme.bg }
                                Rectangle { width: 10; height: 10; radius: 5; color: dotC2; border.width: 1; border.color: Theme.bg }
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                font.pixelSize: 11
                                font.weight: selected ? Font.DemiBold : Font.Normal
                                color: selected ? Theme.accent : Theme.text
                            }
                        }

                        MouseArea {
                            id: palMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wallpapers.setPalette(modelData.id)
                        }
                    }
                }
            }
        }

        // Inline Custom Color Editor (hex + hyprpicker eyedropper)
        Rectangle {
            visible: Wallpapers.paletteId === "custom"
            Layout.fillWidth: true
            implicitHeight: customRow.implicitHeight + Theme.spaceXxs * 2
            radius: Theme.radiusS
            color: Theme.surface1
            border.width: 1
            border.color: Theme.componentDivider

            RowLayout {
                id: customRow
                anchors.fill: parent
                anchors.margins: Theme.spaceXxs
                spacing: Theme.spaceXxs

                Repeater {
                    model: [
                        { slot: "bg", label: "Base", hex: Wallpapers.customBg },
                        { slot: "c1", label: "Primary", hex: Wallpapers.customColor1 },
                        { slot: "c2", label: "Accent", hex: Wallpapers.customColor2 }
                    ]
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 3

                        StyledText {
                            text: modelData.label
                            font.pixelSize: 10
                            color: Theme.textDim
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                color: modelData.hex
                                border.width: 1
                                border.color: Theme.componentDivider
                            }

                            TextField {
                                id: hexField
                                Layout.fillWidth: true
                                text: modelData.hex
                                placeholder: "#RRGGBB"
                                onAccepted: {
                                    const bg = modelData.slot === "bg" ? text : Wallpapers.customBg;
                                    const c1 = modelData.slot === "c1" ? text : Wallpapers.customColor1;
                                    const c2 = modelData.slot === "c2" ? text : Wallpapers.customColor2;
                                    Wallpapers.setCustomColors(bg, c1, c2);
                                }
                            }

                            IconButton {
                                icon: "colorize"
                                implicitWidth: 26
                                implicitHeight: 26
                                iconSize: 15
                                onClicked: root.pickCustomSlot(modelData.slot)
                            }
                        }
                    }
                }
            }
        }

        // Speed & Intensity Sliders
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: shaderCtrlCol.implicitHeight + Theme.spaceXs * 2
            radius: Theme.radiusS
            color: Theme.surface1
            border.width: 1
            border.color: Theme.componentDivider

            ColumnLayout {
                id: shaderCtrlCol
                anchors.fill: parent
                anchors.margins: Theme.spaceXs
                spacing: Theme.spaceXxs

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spaceXs

                    StyledText { text: "Speed"; font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim; Layout.preferredWidth: 56 }
                    StyledSlider {
                        Layout.fillWidth: true
                        from: 0.25
                        to: 2.0
                        wheelStep: 0.1
                        value: Wallpapers.animSpeed
                        onMoved: v => Wallpapers.setAnimSpeed(v)
                    }
                    StyledText {
                        text: Wallpapers.animSpeed.toFixed(2) + "x"
                        font.pixelSize: 11
                        font.family: Theme.monoFamily
                        color: Theme.text
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spaceXs

                    StyledText { text: "Intensity"; font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim; Layout.preferredWidth: 56 }
                    StyledSlider {
                        Layout.fillWidth: true
                        from: 0.3
                        to: 1.5
                        wheelStep: 0.05
                        value: Wallpapers.animIntensity
                        onMoved: v => Wallpapers.setAnimIntensity(v)
                    }
                    StyledText {
                        text: Math.round(Wallpapers.animIntensity * 100) + "%"
                        font.pixelSize: 11
                        font.family: Theme.monoFamily
                        color: Theme.text
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }

    // =========================================================================
    // GIF / VIDEO LOOP VIEW
    // =========================================================================
    ColumnLayout {
        visible: Wallpapers.animatedKind === "file"
        Layout.fillWidth: true
        spacing: Theme.spaceXxs

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: fileCardCol.implicitHeight + Theme.spaceXs * 2
            radius: Theme.radiusS
            color: Theme.surface1
            border.width: 1
            border.color: Theme.componentDivider

            ColumnLayout {
                id: fileCardCol
                anchors.fill: parent
                anchors.margins: Theme.spaceXs
                spacing: Theme.spaceXxs

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spaceXs

                    ClippingRectangle {
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 34
                        radius: Theme.radiusXs
                        color: Theme.bg
                        border.width: 1
                        border.color: Theme.componentDivider

                        WallpaperScene {
                            anchors.fill: parent
                            visible: Wallpapers.resolvedAnimatedFileUrl !== ""
                            mode: "animated"
                            animatedKind: "file"
                            imageUrl: (root.popupOpen && root.isCurrentPage && Wallpapers.animatedKind === "file")
                                ? Wallpapers.resolvedAnimatedFileUrl : ""
                            blurAmount: 0
                            dimAmount: 0
                            decodeWidth: 160
                            decodeHeight: 90
                            paused: true
                        }

                        Icon {
                            visible: Wallpapers.resolvedAnimatedFileUrl === ""
                            anchors.centerIn: parent
                            icon: "gif_box"
                            size: 18
                            color: Theme.textDim
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        StyledText {
                            Layout.fillWidth: true
                            text: Wallpapers.animatedFilePath ? Wallpapers.baseName(Wallpapers.animatedFilePath) : "No animation file chosen"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.textStrong
                            elide: Text.ElideMiddle
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Wallpapers.animatedFilePath
                                ? Wallpapers.displayPath(Wallpapers.animatedFilePath)
                                : (Wallpapers.hasVideoBackend
                                    ? `Native up to ${Hypr.targetFps}fps MP4/WebM/MKV, APNG, WebP & GIF`
                                    : (Wallpapers.hasWebpPlugin
                                        ? `Supports APNG, WebP, GIF & video (${Hypr.targetFps}fps WebP fallback)`
                                        : `Supports APNG, WebP, GIF & video (${Math.min(50, Hypr.targetFps)}fps GIF fallback)`))
                            font.pixelSize: 11
                            color: Theme.textDim
                            elide: Text.ElideMiddle
                        }
                    }

                    Rectangle {
                        implicitHeight: 30
                        implicitWidth: animPickRow.implicitWidth + 16
                        radius: Theme.radiusXl
                        color: animPickMouse.containsMouse ? Theme.accentHover : Theme.accent
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Row {
                            id: animPickRow
                            anchors.centerIn: parent
                            spacing: 5
                            Icon { anchors.verticalCenter: parent.verticalCenter; icon: "folder_open"; size: 15; color: Theme.fgOnAccent }
                            StyledText { anchors.verticalCenter: parent.verticalCenter; text: "Browse…"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.DemiBold; color: Theme.fgOnAccent }
                        }

                        MouseArea {
                            id: animPickMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wallpapers.pickAnimatedFile()
                        }
                    }
                }

                StyledText {
                    visible: Wallpapers.convertingMedia || Wallpapers.convertError !== ""
                    Layout.fillWidth: true
                    text: Wallpapers.convertingMedia ? "Converting media into looping wallpaper cache via ffmpeg…" : Wallpapers.convertError
                    font.pixelSize: 11
                    color: Wallpapers.convertingMedia ? Theme.accent : Theme.destructive
                    wrapMode: Text.WordWrap
                }

                OptionPills {
                    Layout.fillWidth: true
                    label: "Playback Speed"
                    options: [
                        { value: 0.5, label: "0.5x" },
                        { value: 1.0, label: "1x" },
                        { value: 1.5, label: "1.5x" },
                        { value: 2.0, label: "2x" }
                    ]
                    currentValue: Math.round(Wallpapers.animSpeed * 2) / 2
                    onPicked: val => Wallpapers.setAnimSpeed(val)
                }
            }
        }

        // Runtime backend hint shown only when QtMultimedia or qtimageformats is missing
        Rectangle {
            visible: !Wallpapers.hasVideoBackend || !Wallpapers.hasWebpPlugin
            Layout.fillWidth: true
            implicitHeight: backendHintRow.implicitHeight + 10
            radius: Theme.radiusXs
            color: Theme.surface1
            border.width: 1
            border.color: Theme.componentDivider

            RowLayout {
                id: backendHintRow
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceXxs
                anchors.rightMargin: Theme.spaceXxs
                spacing: Theme.spaceXxs

                Icon {
                    icon: "info"
                    size: 14
                    color: Theme.accent
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        const missing = [];
                        if (!Wallpapers.hasVideoBackend) missing.push("qtmultimedia");
                        if (!Wallpapers.hasWebpPlugin) missing.push("qtimageformats");
                        return "Fallback mode active — wrap Quickshell with " + missing.join(" & ") + " (docs/NIXOS_NOTES.md) for native " + Hypr.targetFps + "fps video/APNG & animated WebP.";
                    }
                    font.pixelSize: 10
                    color: Theme.textDim
                    wrapMode: Text.WordWrap
                }
            }
        }

        // Local discovered videos / APNGs / WebPs / GIFs
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 132
            radius: Theme.radiusS
            color: Theme.surface1
            border.width: 1
            border.color: Theme.componentDivider
            clip: true

            ListView {
                id: animFileList
                anchors.fill: parent
                anchors.margins: 4
                spacing: 2
                clip: true
                model: root.localAnimFiles

                delegate: ListItem {
                    required property var modelData
                    width: animFileList.width
                    icon: (modelData.isGif || modelData.isWebp) ? "gif_box" : modelData.isApng ? "animation" : "movie"
                    text: modelData.name
                    subtext: modelData.dir
                    highlighted: Wallpapers.normalizePath(modelData.path) === Wallpapers.normalizePath(Wallpapers.animatedFilePath)
                    onClicked: Wallpapers.setAnimatedFile(modelData.path)
                }
            }

            ColumnLayout {
                visible: animFileList.count === 0
                anchors.centerIn: parent
                width: parent.width - Theme.spaceM
                spacing: 4

                Icon { Layout.alignment: Qt.AlignHCenter; icon: "movie"; size: 22; color: Theme.textDim }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "No animated files found in ~/Videos or ~/Pictures — click Browse… to pick a .mp4, .webm, .apng, .webp, or .gif"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                }
            }
        }
    }

    // ---- Shared Animation Power Rules ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: animRulesCol.implicitHeight + Theme.spaceXs * 2
        radius: Theme.radiusS
        color: Theme.surface1
        border.width: 1
        border.color: Theme.componentDivider

        ColumnLayout {
            id: animRulesCol
            anchors.fill: parent
            anchors.margins: Theme.spaceXs
            spacing: Theme.spaceXxs

            RowLayout {
                Layout.fillWidth: true
                StyledText { Layout.fillWidth: true; text: "Pause animation on fullscreen windows"; font.pixelSize: Theme.fontSizeSmall }
                Toggle {
                    checked: Wallpapers.pauseOnFullscreen
                    onToggled: Wallpapers.setPauseOnFullscreen(!Wallpapers.pauseOnFullscreen)
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: "Animated mode turns off outside Performance power mode and restores automatically when switching back."
                font.pixelSize: 11
                color: Theme.textDim
                wrapMode: Text.WordWrap
            }
        }
    }
}
