import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.components
import qs.services
import qs.wallpaper

// Live compact preview card at the top of the Background popup, with multi-monitor
// switcher pills and inline Prev / Play-Pause / Next controls.
ColumnLayout {
    id: root

    property string targetScreen: ""
    property bool popupOpen: false

    signal screenPicked(string screenName)

    spacing: Theme.spaceXxs

    readonly property string activeUrl: Wallpapers.activeUrlForScreen(root.targetScreen)

    function intervalLabel(sec: int): string {
        if (sec <= 0) return "Manual";
        if (sec < 60) return sec + "s";
        if (sec < 3600) return Math.round(sec / 60) + "m";
        return Math.round(sec / 3600) + "h";
    }

    function currentSceneName(): string {
        for (const s of Wallpapers.scenes) {
            if (s.id === Wallpapers.sceneId) return s.name;
        }
        return "Live Shader";
    }

    readonly property string modeSummary: {
        if (Wallpapers.mode === "folder") {
            const timing = Wallpapers.slideshowPaused ? "Paused" : intervalLabel(Wallpapers.intervalSec);
            return "Folder • " + timing + " • " + Wallpapers.count + (Wallpapers.count === 1 ? " image" : " images");
        }
        if (Wallpapers.mode === "image") {
            const kind = Wallpapers.isGifPath(Wallpapers.singleImagePath) ? "Animated GIF" : "Single Image";
            return kind + (Wallpapers.kenBurns ? " • Ken Burns" : "");
        }
        if (Wallpapers.mode === "animated") {
            const kind = Wallpapers.animatedKind === "scene" ? "Live Shader" : "Loop";
            const state = Wallpapers.batterySaverPause ? "Paused (Power Saver)"
                        : Wallpapers.animatedPaused ? "Paused"
                        : "Playing";
            return kind + " • " + state;
        }
        return Wallpapers.solidVignette ? "Solid • Subtle Vignette" : "Solid Backdrop";
    }

    readonly property string titleSummary: {
        if (Wallpapers.mode === "folder") {
            return root.activeUrl ? Wallpapers.baseName(root.activeUrl)
                 : Wallpapers.scanningFolder ? "Scanning folder…"
                 : "No compatible images";
        }
        if (Wallpapers.mode === "image") {
            return Wallpapers.singleImagePath ? Wallpapers.baseName(Wallpapers.singleImagePath) : "No image selected";
        }
        if (Wallpapers.mode === "animated") {
            if (Wallpapers.animatedKind === "scene") {
                return root.currentSceneName() + " · " + Wallpapers.activePalette().name;
            }
            return Wallpapers.animatedFilePath ? Wallpapers.baseName(Wallpapers.animatedFilePath) : "No animation selected";
        }
        return Wallpapers.solidColor;
    }

    // Monitor selector pills when multiple outputs are connected
    RowLayout {
        visible: Quickshell.screens.length > 1
        Layout.fillWidth: true
        spacing: Theme.spaceXxxs

        StyledText {
            text: Wallpapers.syncScreens ? "All screens:" : "Screen:"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textDim
            Layout.rightMargin: 2
        }

        Repeater {
            model: Quickshell.screens
            delegate: Rectangle {
                required property var modelData
                readonly property bool selected: root.targetScreen === modelData.name

                implicitHeight: 22
                implicitWidth: Math.max(48, scrLabel.implicitWidth + 14)
                radius: Theme.radiusXl
                color: selected ? Theme.accent
                     : scrMouse.containsMouse ? Theme.componentHover
                     : Theme.component
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                StyledText {
                    id: scrLabel
                    anchors.centerIn: parent
                    text: modelData.name
                    font.pixelSize: 11
                    font.weight: selected ? Font.DemiBold : Font.Normal
                    color: selected ? Theme.fgOnAccent : Theme.text
                }

                MouseArea {
                    id: scrMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.screenPicked(modelData.name)
                }
            }
        }

        Item { Layout.fillWidth: true }
    }

    ClippingRectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 112
        radius: Theme.radiusS
        color: Theme.bg
        border.width: 1
        border.color: Theme.componentDivider

        WallpaperScene {
            anchors.fill: parent
            imageUrl: root.activeUrl
            transitionMs: Math.min(280, Wallpapers.transitionMs)
            instantTransitions: !root.popupOpen
            paused: !root.popupOpen || (Wallpapers.mode === "animated" && Wallpapers.effectivelyAnimatedPaused)
            decodeWidth: 640
            decodeHeight: 360
        }

        // Bottom contrast scrim
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 62
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.80) }
            }
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spaceXs
            spacing: Theme.spaceXxs

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: root.modeSummary
                    font.pixelSize: 11
                    color: Theme.accent
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.titleSummary
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                    elide: Text.ElideMiddle
                }
            }

            // Inline transport pill for folder slideshow / animation pause
            Rectangle {
                visible: Wallpapers.mode === "folder" || Wallpapers.mode === "animated"
                implicitHeight: 30
                implicitWidth: transportRow.implicitWidth + 8
                radius: Theme.radiusXl
                color: Qt.rgba(0.11, 0.11, 0.11, 0.82)
                border.width: 1
                border.color: Theme.componentDivider

                RowLayout {
                    id: transportRow
                    anchors.centerIn: parent
                    spacing: 2

                    IconButton {
                        visible: Wallpapers.mode === "folder"
                        icon: "skip_previous"
                        implicitWidth: 26
                        implicitHeight: 26
                        iconSize: 17
                        enabled: Wallpapers.count > 1
                        onClicked: Wallpapers.prev(root.targetScreen)
                    }

                    IconButton {
                        icon: Wallpapers.mode === "folder"
                            ? (Wallpapers.slideshowPaused ? "play_arrow" : "pause")
                            : (Wallpapers.effectivelyAnimatedPaused ? "play_arrow" : "pause")
                        filled: true
                        implicitWidth: 26
                        implicitHeight: 26
                        iconSize: 17
                        highlighted: Wallpapers.mode === "folder"
                            ? Wallpapers.slideshowPaused
                            : Wallpapers.effectivelyAnimatedPaused
                        onClicked: Wallpapers.toggleCurrentPause()
                    }

                    IconButton {
                        visible: Wallpapers.mode === "folder"
                        icon: "skip_next"
                        implicitWidth: 26
                        implicitHeight: 26
                        iconSize: 17
                        enabled: Wallpapers.count > 1
                        onClicked: Wallpapers.next()
                    }
                }
            }
        }
    }
}
