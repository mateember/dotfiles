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

    // On-demand native QML Canvas dominant-accent sampler (zero external scripts).
    // Runs only on the first screen while ThemeSync.extractingAccent is true.
    Loader {
        active: ThemeSync.extractingAccent
             && Quickshell.screens.length > 0
             && root.screenName === Quickshell.screens[0].name
        sourceComponent: Canvas {
            id: accentCanvas
            width: 48
            height: 48
            visible: false
            property string targetUrl: ThemeSync.extractImageUrl

            function toHexByte(n: int): string {
                const s = Math.max(0, Math.min(255, Math.round(n))).toString(16);
                return s.length < 2 ? "0" + s : s;
            }

            Component.onCompleted: {
                if (targetUrl) loadImage(targetUrl);
                else ThemeSync.finishAccentExtraction("");
            }

            onImageLoaded: requestPaint()

            onPaint: {
                if (!isImageLoaded(targetUrl)) return;
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.drawImage(targetUrl, 0, 0, width, height);
                const img = ctx.getImageData(0, 0, width, height);
                const d = img.data;
                // Bucket pixels into 24 hue bins weighted by saturation and pleasant mid-luminance.
                const bins = [];
                for (let b = 0; b < 24; b++) bins.push({ w: 0, r: 0, g: 0, bl: 0 });
                for (let i = 0; i < d.length; i += 4) {
                    const r = d[i] / 255, g = d[i + 1] / 255, bl = d[i + 2] / 255;
                    const max = Math.max(r, g, bl), min = Math.min(r, g, bl);
                    const l = (max + min) / 2;
                    const delta = max - min;
                    if (delta < 0.10 || l < 0.14 || l > 0.88) continue;
                    const s = delta / (1 - Math.abs(2 * l - 1));
                    let h = 0;
                    if (max === r) h = ((g - bl) / delta) % 6;
                    else if (max === g) h = (bl - r) / delta + 2;
                    else h = (r - g) / delta + 4;
                    h = (h * 60 + 360) % 360;
                    const idx = Math.min(23, Math.floor(h / 15));
                    const weight = s * s * (1 - Math.abs(l - 0.55));
                    bins[idx].w += weight;
                    bins[idx].r += d[i] * weight;
                    bins[idx].g += d[i + 1] * weight;
                    bins[idx].bl += d[i + 2] * weight;
                }
                let best = null;
                for (const bin of bins) {
                    if (bin.w > 0 && (!best || bin.w > best.w)) best = bin;
                }
                if (best && best.w > 0) {
                    const hex = "#" + toHexByte(best.r / best.w) + toHexByte(best.g / best.w) + toHexByte(best.bl / best.w);
                    ThemeSync.finishAccentExtraction(hex);
                } else {
                    ThemeSync.finishAccentExtraction("#FFAD00");
                }
            }
        }
    }
}
