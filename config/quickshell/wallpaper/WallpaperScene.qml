import QtQuick
import QtQuick.Effects
import qs
import qs.services

// Reusable wallpaper renderer supporting all 4 background modes:
//   - "folder" / "image": double-buffered Image & AnimatedImage (.gif / .webp) crossfades + optional Ken Burns motion (plus VideoLayer for .apng)
//   - "animated" ("scene"): GPU Fragment ShaderEffect (aurora, orbs, stars, waves, plasma)
//   - "animated" ("file"):  VideoLayer (QtMultimedia full-framerate video / APNG) or AnimatedImage (.webp / .gif / ffmpeg fallback)
//   - "solid":              Solid color with optional subtle radial vignette
// Used by desktop Wallpaper.qml, live popup previews, and LockSurface.qml.
Item {
    id: root

    property string mode: Wallpapers.mode
    property string imageUrl: ""
    property string animatedKind: Wallpapers.animatedKind
    property string sceneId: Wallpapers.sceneId
    property color paletteBg: Wallpapers.activePalette().bg
    property color paletteC1: Wallpapers.activePalette().c1
    property color paletteC2: Wallpapers.activePalette().c2
    property color paletteC3: Wallpapers.activePalette().c3
    property real animSpeed: Wallpapers.animSpeed
    property real animIntensity: Wallpapers.animIntensity
    property string solidColor: Wallpapers.solidColor
    property bool solidVignette: Wallpapers.solidVignette
    property string fitMode: Wallpapers.fitMode
    property int transitionMs: Wallpapers.transitionMs
    property bool kenBurns: Wallpapers.kenBurns
    property real dimAmount: Wallpapers.dimAmount
    property real blurAmount: Wallpapers.blurAmount
    property bool paused: false
    property bool staticPreviewOnly: false
    property bool isApngMedia: false
    property bool instantTransitions: false
    property real decodeWidth: width
    property real decodeHeight: height
    property bool reportScreenUrl: false
    property string screenName: ""

    readonly property bool isMediaMode: mode === "folder" || mode === "image" || (mode === "animated" && animatedKind === "file")
    readonly property bool isShaderMode: mode === "animated" && animatedKind === "scene"
    readonly property bool isSolidMode: mode === "solid"
    readonly property bool useVideoLayer: isMediaMode && !staticPreviewOnly && isVideoUrl(imageUrl) && imageUrl !== ""

    readonly property int resolvedFillMode: {
        if (fitMode === "fit") return Image.PreserveAspectFit;
        if (fitMode === "stretch") return Image.Stretch;
        if (fitMode === "center") return Image.Pad;
        return Image.PreserveAspectCrop;
    }

    property var frontSlot: slotA
    property var backSlot: slotB
    property bool shownOnce: false
    property string pendingUrl: ""

    signal imageApplied(string url)

    function urlLowerClean(u: string): string {
        return (u || "").toLowerCase().split("?")[0];
    }

    function isGifUrl(u: string): bool {
        return urlLowerClean(u).endsWith(".gif");
    }

    function isAnimatedImgUrl(u: string): bool {
        const clean = urlLowerClean(u);
        return clean.endsWith(".gif") || (Wallpapers.hasWebpPlugin && clean.endsWith(".webp"));
    }

    function isVideoUrl(u: string): bool {
        if (!Wallpapers.hasVideoBackend || !u) return false;
        const clean = urlLowerClean(u);
        if (clean.endsWith(".mp4") || clean.endsWith(".webm") || clean.endsWith(".mkv")
            || clean.endsWith(".mov") || clean.endsWith(".m4v") || clean.endsWith(".avi")
            || clean.endsWith(".apng")) {
            return true;
        }
        if (clean.endsWith(".png")) {
            if (root.isApngMedia) return true;
            if (root.mode === "animated" && root.animatedKind === "file"
                && Wallpapers.animatedFileIsApng && u === Wallpapers.resolvedAnimatedFileUrl) return true;
            if (root.mode === "image"
                && Wallpapers.singleImageIsApng && u === Wallpapers.resolvedSingleImageUrl) return true;
        }
        return false;
    }

    function loadUrl(url: string) {
        if (!url) return;
        if (url === root.frontSlot.url && root.frontSlot.loaded) {
            if (root.reportScreenUrl) Wallpapers.setScreenUrl(root.screenName, url);
            return;
        }
        root.pendingUrl = url;
        root.backSlot.load(url);
    }

    function revealSlot(slot) {
        if (slot !== root.backSlot || !slot.loaded) return;
        if (root.pendingUrl && slot.url !== root.pendingUrl) return;

        root.backSlot = root.frontSlot;
        root.frontSlot = slot;
        slot.z = 1;
        root.backSlot.z = 0;

        if (root.reportScreenUrl) Wallpapers.setScreenUrl(root.screenName, slot.url);
        root.imageApplied(slot.url);

        const ms = (root.instantTransitions || !root.shownOnce) ? 0 : root.transitionMs;
        if (ms <= 0) {
            fade.stop();
            slot.opacity = 1;
            root.backSlot.opacity = 0;
            root.shownOnce = true;
        } else {
            root.shownOnce = true;
            fade.duration = ms;
            fade.target = slot;
            fade.restart();
        }
    }

    onImageUrlChanged: {
        if (isMediaMode && imageUrl !== "" && !useVideoLayer) loadUrl(imageUrl);
    }
    onIsMediaModeChanged: {
        if (isMediaMode && imageUrl !== "" && !useVideoLayer) loadUrl(imageUrl);
    }
    onUseVideoLayerChanged: {
        if (useVideoLayer) {
            slotA.unload();
            slotB.unload();
        } else if (isMediaMode && imageUrl !== "") {
            loadUrl(imageUrl);
        }
    }

    clip: true

    // ---- Visual Content Container (optionally blurred via MultiEffect below) ----
    Item {
        id: visualRoot
        anchors.fill: parent

        // Base backdrop color (visible under "fit"/"center" fit modes and "solid" mode)
        Rectangle {
            anchors.fill: parent
            color: root.isSolidMode ? root.solidColor : Theme.bg
        }

        // Solid mode subtle radial vignette
        Canvas {
            id: vignetteCanvas
            anchors.fill: parent
            visible: root.isSolidMode && root.solidVignette
            onVisibleChanged: if (visible) requestPaint()
            onWidthChanged: if (visible) requestPaint()
            onHeightChanged: if (visible) requestPaint()
            Connections {
                target: root
                function onSolidColorChanged() { if (vignetteCanvas.visible) vignetteCanvas.requestPaint(); }
            }
            onPaint: {
                const ctx = getContext("2d");
                const w = width, h = height;
                ctx.clearRect(0, 0, w, h);
                if (w <= 0 || h <= 0) return;
                const cx = w * 0.5, cy = h * 0.44;
                const r = Math.max(w, h) * 0.72;
                const g = ctx.createRadialGradient(cx, cy, r * 0.05, cx, cy, r);
                g.addColorStop(0, "rgba(255, 255, 255, 0.055)");
                g.addColorStop(0.55, "rgba(0, 0, 0, 0.0)");
                g.addColorStop(1, "rgba(0, 0, 0, 0.36)");
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, w, h);
            }
        }

        // Built-in Live GPU Shader Scene
        Loader {
            id: shaderLoader
            anchors.fill: parent
            active: root.isShaderMode
            sourceComponent: Item {
                id: shaderHost
                anchors.fill: parent

                property real animTime: 14.0

                FrameAnimation {
                    running: root.isShaderMode && !root.paused
                    onTriggered: shaderHost.animTime += frameTime * root.animSpeed
                }

                ShaderEffect {
                    anchors.fill: parent
                    property real u_time: shaderHost.animTime
                    property real u_intensity: root.animIntensity
                    property vector2d u_resolution: Qt.vector2d(Math.max(1, width), Math.max(1, height))
                    property color u_bg: root.paletteBg
                    property color u_c1: root.paletteC1
                    property color u_c2: root.paletteC2
                    property color u_c3: root.paletteC3
                    fragmentShader: Qt.resolvedUrl("shaders/" + root.sceneId + ".frag.qsb")
                }
            }
        }

        // Native QtMultimedia Video / APNG layer (full framerate & resolution)
        Loader {
            id: videoLoader
            anchors.fill: parent
            active: root.useVideoLayer
            sourceComponent: Wallpapers.videoLayerComponent
        }

        Binding {
            target: videoLoader.item
            property: "sourceUrl"
            value: root.imageUrl
            when: videoLoader.status === Loader.Ready && videoLoader.item !== null
        }
        Binding {
            target: videoLoader.item
            property: "fitMode"
            value: root.fitMode
            when: videoLoader.status === Loader.Ready && videoLoader.item !== null
        }
        Binding {
            target: videoLoader.item
            property: "paused"
            value: root.paused
            when: videoLoader.status === Loader.Ready && videoLoader.item !== null
        }
        Binding {
            target: videoLoader.item
            property: "playbackRate"
            value: (root.mode === "animated" || root.mode === "image") ? root.animSpeed : 1.0
            when: videoLoader.status === Loader.Ready && videoLoader.item !== null
        }

        Connections {
            target: videoLoader.item
            function onMediaReady() {
                if (root.reportScreenUrl) Wallpapers.setScreenUrl(root.screenName, root.imageUrl);
                root.imageApplied(root.imageUrl);
            }
            function onMediaError(msg) {
                if (root.mode === "animated" && root.animatedKind === "file") {
                    Wallpapers.reportVideoError(msg);
                }
            }
        }

        // Media layer (Folder slideshow, Single Image, or AnimatedImage .webp / .gif / fallback loop)
        Item {
            id: mediaStage
            anchors.fill: parent
            visible: root.isMediaMode && !root.useVideoLayer

            // Subtle Ken Burns motion (only for static images when enabled and unpaused)
            readonly property bool kbActive: visible && root.kenBurns && !root.paused && root.frontSlot.allowsKenBurns
            property real kbScale: 1.0
            property real kbOffsetX: 0.0
            property real kbOffsetY: 0.0

            transform: [
                Translate {
                    x: mediaStage.kbActive ? mediaStage.kbOffsetX : 0
                    y: mediaStage.kbActive ? mediaStage.kbOffsetY : 0
                },
                Scale {
                    origin.x: mediaStage.width / 2
                    origin.y: mediaStage.height / 2
                    xScale: mediaStage.kbActive ? mediaStage.kbScale : 1.0
                    yScale: mediaStage.kbActive ? mediaStage.kbScale : 1.0
                }
            ]

            SequentialAnimation {
                running: mediaStage.kbActive
                loops: Animation.Infinite
                ParallelAnimation {
                    NumberAnimation { target: mediaStage; property: "kbScale"; from: 1.0; to: 1.075; duration: 14000; easing.type: Easing.InOutSine }
                    NumberAnimation { target: mediaStage; property: "kbOffsetX"; from: -mediaStage.width * 0.014; to: mediaStage.width * 0.014; duration: 14000; easing.type: Easing.InOutSine }
                    NumberAnimation { target: mediaStage; property: "kbOffsetY"; from: -mediaStage.height * 0.010; to: mediaStage.height * 0.010; duration: 14000; easing.type: Easing.InOutSine }
                }
                ParallelAnimation {
                    NumberAnimation { target: mediaStage; property: "kbScale"; from: 1.075; to: 1.015; duration: 14000; easing.type: Easing.InOutSine }
                    NumberAnimation { target: mediaStage; property: "kbOffsetX"; from: mediaStage.width * 0.014; to: -mediaStage.width * 0.014; duration: 14000; easing.type: Easing.InOutSine }
                    NumberAnimation { target: mediaStage; property: "kbOffsetY"; from: mediaStage.height * 0.010; to: -mediaStage.height * 0.010; duration: 14000; easing.type: Easing.InOutSine }
                }
            }

            component MediaSlot: Item {
                id: slot
                anchors.fill: parent
                opacity: 0

                property string url: ""
                property bool isGif: false
                property bool loaded: false
                readonly property bool allowsKenBurns: !slot.isGif || (gifImg.status === AnimatedImage.Ready && gifImg.frameCount <= 1)

                function unload() {
                    slot.loaded = false;
                    slot.isGif = false;
                    slot.url = "";
                    slot.opacity = 0;
                    staticImg.source = "";
                    gifImg.source = "";
                }

                function load(u: string) {
                    const g = root.isAnimatedImgUrl(u);
                    slot.loaded = false;
                    slot.isGif = g;
                    slot.url = u;
                    if (g) {
                        staticImg.source = "";
                        gifImg.source = u;
                    } else {
                        gifImg.source = "";
                        staticImg.source = u;
                    }
                }

                Image {
                    id: staticImg
                    anchors.fill: parent
                    visible: !slot.isGif
                    fillMode: root.resolvedFillMode
                    asynchronous: true
                    cache: false
                    smooth: true
                    sourceSize.width: Math.max(64, Math.round(root.decodeWidth))
                    sourceSize.height: Math.max(64, Math.round(root.decodeHeight))
                    onStatusChanged: {
                        if (status === Image.Ready && !slot.isGif) {
                            slot.loaded = true;
                            root.revealSlot(slot);
                        }
                    }
                }

                AnimatedImage {
                    id: gifImg
                    anchors.fill: parent
                    visible: slot.isGif
                    fillMode: root.resolvedFillMode
                    asynchronous: true
                    cache: false
                    smooth: true
                    playing: slot.isGif && mediaStage.visible && !root.paused && slot.opacity > 0.01 && gifImg.frameCount !== 1
                    speed: root.mode === "animated" || root.mode === "image" ? root.animSpeed : 1.0
                    onStatusChanged: {
                        if (status === AnimatedImage.Ready && slot.isGif) {
                            slot.loaded = true;
                            root.revealSlot(slot);
                        }
                    }
                }
            }

            MediaSlot { id: slotA }
            MediaSlot { id: slotB }

            NumberAnimation {
                id: fade
                property: "opacity"
                from: 0
                to: 1
                duration: 1200
                easing.type: Easing.InOutQuad
                onFinished: if (root.backSlot) root.backSlot.opacity = 0
            }
        }
    }

    // Optional Wallpaper Blur (only instantiated when blurAmount > 0)
    Loader {
        anchors.fill: parent
        active: root.blurAmount > 0.01
        sourceComponent: MultiEffect {
            source: visualRoot
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 48
            blur: root.blurAmount
        }
    }

    // Optional Dimming Overlay
    Rectangle {
        anchors.fill: parent
        visible: root.dimAmount > 0.005
        color: Qt.rgba(0, 0, 0, root.dimAmount)
    }
}
