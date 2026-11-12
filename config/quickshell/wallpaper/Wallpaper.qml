import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

// Wallpaper surface for one monitor on the Wayland background layer.
// Delegates visual rendering (folder slideshow, single image, live shaders, animated GIFs, solid color)
// to WallpaperScene and tracks per-screen fullscreen state to skip transitions / pause animations.
PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.bg

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "hcs-wallpaper"

    readonly property string screenName: root.screen?.name ?? ""
    readonly property bool fullscreenActive: Hyprland.monitorFor(screen)?.activeWorkspace?.hasFullscreen ?? false
    readonly property real dpr: root.screen?.devicePixelRatio ?? 1

    property string currentUrl: ""

    function pickInitialOrNext() {
        if (Wallpapers.mode === "folder") {
            let url = "";
            if (Wallpapers.syncScreens && Wallpapers.current) {
                url = Wallpapers.current;
            } else {
                const existing = Wallpapers.screenUrls[root.screenName];
                url = existing || Wallpapers.pickNextUrl(root.screenName, root.currentUrl);
            }
            if (url) root.currentUrl = url;
        } else if (Wallpapers.mode === "image") {
            if (Wallpapers.resolvedSingleImageUrl) root.currentUrl = Wallpapers.resolvedSingleImageUrl;
        } else if (Wallpapers.mode === "animated" && Wallpapers.animatedKind === "file") {
            if (Wallpapers.resolvedAnimatedFileUrl) root.currentUrl = Wallpapers.resolvedAnimatedFileUrl;
        }
    }

    function advanceSlideshow() {
        if (Wallpapers.mode !== "folder") return;
        const url = Wallpapers.pickNextUrl(root.screenName, root.currentUrl);
        if (url) root.currentUrl = url;
    }

    WallpaperScene {
        id: scene
        anchors.fill: parent
        imageUrl: root.currentUrl
        paused: (Wallpapers.mode === "animated" && Wallpapers.animatedPaused)
             || (Wallpapers.pauseOnFullscreen && root.fullscreenActive)
        instantTransitions: root.fullscreenActive
        decodeWidth: root.width * root.dpr
        decodeHeight: root.height * root.dpr
        reportScreenUrl: Wallpapers.mode === "folder"
        screenName: root.screenName
    }

    Connections {
        target: Wallpapers
        function onTick() { root.advanceSlideshow(); }
        function onScreenForceUrl(sn: string, url: string) {
            if (sn === "" || sn === root.screenName) root.currentUrl = url;
        }
        function onFolderFilesChanged() {
            if (Wallpapers.mode !== "folder" || Wallpapers.folderFiles.length === 0) return;
            if (Wallpapers.syncScreens) {
                if (Wallpapers.current && Wallpapers.folderFiles.some(f => f.url === Wallpapers.current))
                    root.currentUrl = Wallpapers.current;
                return;
            }
            const cur = root.currentUrl;
            const stillPresent = cur !== "" && Wallpapers.folderFiles.some(f => f.url === cur);
            if (!stillPresent) {
                const url = Wallpapers.pickNextUrl(root.screenName, "");
                if (url) root.currentUrl = url;
            }
        }
        function onModeChanged() { root.pickInitialOrNext(); }
        function onAnimatedKindChanged() { root.pickInitialOrNext(); }
        function onResolvedSingleImageUrlChanged() {
            if (Wallpapers.mode === "image") root.currentUrl = Wallpapers.resolvedSingleImageUrl;
        }
        function onResolvedAnimatedFileUrlChanged() {
            if (Wallpapers.mode === "animated" && Wallpapers.animatedKind === "file")
                root.currentUrl = Wallpapers.resolvedAnimatedFileUrl;
        }
        function onReadyChanged() {
            if (Wallpapers.ready) root.pickInitialOrNext();
        }
    }

    Component.onCompleted: pickInitialOrNext()
}
