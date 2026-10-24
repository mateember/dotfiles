import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

// Wallpaper for one screen, on the background layer. Crossfades to a new random image from
// Wallpapers on every tick. While a fullscreen window is on this monitor (games, video) the
// image switches instantly instead of animating, like the old swww.sh "game mode".
PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.bg

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "hcs-wallpaper"

    readonly property bool fullscreenActive: Hyprland.monitorFor(screen)?.activeWorkspace?.hasFullscreen ?? false
    property Image front: imgA
    property Image back: imgB
    property bool shownOnce: false

    function change() {
        const url = Wallpapers.randomUrl(String(root.front.source));
        if (url === "") return;
        root.back.source = url;   // shown by onStatusChanged once decoded
    }

    function reveal(img: Image) {
        if (img !== root.back || img.status !== Image.Ready) return;
        root.back = root.front;
        root.front = img;
        img.z = 1;
        root.back.z = 0;
        // First image and fullscreen: switch instantly. Otherwise crossfade.
        if (root.fullscreenActive || !root.shownOnce) {
            fade.stop();
            img.opacity = 1;
            root.back.opacity = 0;
            root.shownOnce = true;
        } else {
            fade.target = img;
            fade.restart();
        }
    }

    component Wall: Image {
        id: wall
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop   // COSMIC "Zoom"
        asynchronous: true
        cache: false
        smooth: true
        opacity: 0
        sourceSize.width: root.width * (root.screen?.devicePixelRatio ?? 1)
        sourceSize.height: root.height * (root.screen?.devicePixelRatio ?? 1)
        onStatusChanged: root.reveal(wall)
    }

    Wall { id: imgA }
    Wall { id: imgB }

    NumberAnimation {
        id: fade
        property: "opacity"
        from: 0
        to: 1
        duration: 1200
        easing.type: Easing.InOutQuad
        onFinished: if (root.back) root.back.opacity = 0
    }

    Connections {
        target: Wallpapers
        function onTick() { root.change(); }
        function onCountChanged() { if (!root.front.source.toString()) root.change(); }
    }

    Component.onCompleted: change()
}
