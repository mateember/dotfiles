pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs

// Persistent wallpaper & background controller supporting:
//   - "folder":   Folder slideshow (random / sequential, configurable interval, optional subfolders)
//   - "image":    Single static image or animated GIF
//   - "animated": Built-in live GPU shaders (Aurora, Orbs, Stars, Waves, Plasma) or GIF/video loop
//   - "solid":    Solid color or subtle vignette backdrop
//
// Settings persist in Quickshell.statePath("wallpaper-config.json"); live per-screen URLs persist
// across hot reloads in PersistentProperties ("hcs-wallpapers") and are exposed to lock.qml via IPC.
Singleton {
    id: root

    property bool ready: false
    property bool passiveMode: false   // true inside lock.qml so it won't run timers or mutate config
    readonly property string stateFile: Quickshell.statePath("wallpaper-config.json")
    readonly property string cacheDir: Quickshell.cachePath("wallpapers")

    // ---- Mode & Display Options ----
    property string mode: "folder"                // "folder" | "image" | "animated" | "solid"
    property string lastStaticMode: "folder"      // "folder" | "image" | "solid" fallback when leaving Performance
    property bool resumeAnimatedOnPerf: false     // true when Animated auto-disabled on non-Performance mode
    property string fitMode: "crop"               // "crop" | "fit" | "stretch" | "center"
    property int transitionMs: 1200               // 0 | 400 | 1200 | 2000
    property bool kenBurns: false                 // subtle slow pan & zoom on still images
    property real dimAmount: 0.0                  // 0.0 .. 0.70
    property real blurAmount: 0.0                 // 0.0 .. 1.0
    property bool syncScreens: false              // true = same image across all monitors

    // ---- Folder Slideshow ----
    property string folderPath: Config.wallpaperDir
    property bool includeSubfolders: false
    property string order: "random"               // "random" | "sequential"
    property int intervalSec: Config.wallpaperIntervalSec   // 0 = manual only
    property bool slideshowPaused: false
    property var recentFolders: defaultFolders()

    // ---- Single Image ----
    property string singleImagePath: ""
    property string resolvedSingleImageUrl: ""
    property var recentImages: []
    property string browseDir: Config.wallpaperDir

    // ---- Animated ----
    property string animatedKind: "scene"         // "scene" | "file"
    property string sceneId: "aurora"             // "aurora" | "orbs" | "stars" | "waves" | "plasma"
    property string paletteId: "cosmic"           // "cosmic" | "northern" | "ocean" | "sunset" | "mono" | "custom"
    property string customColor1: "#FFAD00"
    property string customColor2: "#3B82F6"
    property string customBg: "#101116"
    property real animSpeed: 1.0                  // 0.25 .. 2.0
    property real animIntensity: 1.0              // 0.3 .. 1.5
    property string animatedFilePath: ""
    property string resolvedAnimatedFileUrl: ""
    property bool animatedPaused: false
    property bool pauseOnFullscreen: true

    // ---- Solid ----
    property string solidColor: "#1B1B1B"
    property bool solidVignette: true

    // ---- Transient Status ----
    property bool scanningFolder: false
    property var folderFiles: []                  // [{ name, path, url, isGif }]
    property bool convertingMedia: false
    property string convertError: ""
    property bool bingFetching: false
    property string bingStatus: ""
    property bool pickerOpen: false

    readonly property int count: folderFiles.length
    readonly property string current: persist.current
    readonly property var screenUrls: {
        try { return JSON.parse(persist.screenUrlsJson || "{}"); }
        catch (e) { return {}; }
    }

    // Animated wallpapers are only enabled when PowerProfile is in Performance mode.
    readonly property bool animatedAllowed: PowerProfile.mode === "performance"

    // Signals sent to Wallpaper.qml instances
    signal tick()                                 // advance folder slideshow
    signal screenForceUrl(string screenName, string url)
    signal refreshTriggered()

    // ---- Catalogs ----
    readonly property var scenes: [
        { id: "aurora", name: "Aurora Silk",  subtitle: "Flowing northern light ribbons",   icon: "auto_awesome" },
        { id: "orbs",   name: "Ambient Orbs", subtitle: "Soft drifting luminous bokeh",     icon: "blur_on" },
        { id: "stars",  name: "Starfield",    subtitle: "Parallax deep-space stars",        icon: "star" },
        { id: "waves",  name: "Silk Waves",   subtitle: "Layered topographic contours",     icon: "waves" },
        { id: "plasma", name: "Velvet Flow",  subtitle: "Smooth organic fluid currents",    icon: "animation" }
    ]

    readonly property var palettes: [
        { id: "cosmic",   name: "COSMIC Amber",    bg: "#111114", c1: "#FFAD00", c2: "#E06D1F", c3: "#4A588A" },
        { id: "northern", name: "Northern Lights", bg: "#09131C", c1: "#34D399", c2: "#22D3EE", c3: "#818CF8" },
        { id: "ocean",    name: "Oceanic",         bg: "#08121E", c1: "#38BDF8", c2: "#0EA5E9", c3: "#2DD4BF" },
        { id: "sunset",   name: "Sunset Ember",    bg: "#160F17", c1: "#FB7185", c2: "#F59E0B", c3: "#A855F7" },
        { id: "mono",     name: "Monochrome",      bg: "#121214", c1: "#A1A1AA", c2: "#71717A", c3: "#52525B" },
        { id: "custom",   name: "Custom",          bg: "",        c1: "",        c2: "",        c3: "" }
    ]

    readonly property var solidSwatches: [
        { hex: "#1B1B1B", name: "COSMIC Dark" },
        { hex: "#121214", name: "Obsidian" },
        { hex: "#000000", name: "Pitch Black" },
        { hex: "#161B26", name: "Midnight Navy" },
        { hex: "#1A1624", name: "Deep Plum" },
        { hex: "#141F1B", name: "Pine Slate" },
        { hex: "#231916", name: "Warm Espresso" },
        { hex: "#22262E", name: "Cool Graphite" }
    ]

    function activePalette(): var {
        if (root.paletteId === "custom") {
            return {
                id: "custom",
                name: "Custom",
                bg: validHex(root.customBg) ? root.customBg : "#101116",
                c1: validHex(root.customColor1) ? root.customColor1 : "#FFAD00",
                c2: validHex(root.customColor2) ? root.customColor2 : "#3B82F6",
                c3: mixHex(
                    validHex(root.customColor1) ? root.customColor1 : "#FFAD00",
                    validHex(root.customColor2) ? root.customColor2 : "#3B82F6"
                )
            };
        }
        for (const p of root.palettes) {
            if (p.id === root.paletteId) return p;
        }
        return root.palettes[0];
    }

    function validHex(s: string): bool {
        return /^#[0-9A-Fa-f]{6}$/.test((s || "").trim());
    }

    function normalizeHex(s: string, fallback: string): string {
        let t = (s || "").trim().toUpperCase();
        if (!t.startsWith("#")) t = "#" + t;
        return /^#[0-9A-F]{6}$/.test(t) ? t : fallback;
    }

    function mixHex(a: string, b: string): string {
        const ra = parseInt(a.slice(1, 3), 16), ga = parseInt(a.slice(3, 5), 16), ba = parseInt(a.slice(5, 7), 16);
        const rb = parseInt(b.slice(1, 3), 16), gb = parseInt(b.slice(3, 5), 16), bb = parseInt(b.slice(5, 7), 16);
        const hex = n => Math.max(0, Math.min(255, Math.round(n))).toString(16).padStart(2, "0").toUpperCase();
        return "#" + hex((ra + rb) / 2) + hex((ga + gb) / 2) + hex((ba + bb) / 2);
    }

    function defaultFolders(): var {
        return [
            Config.wallpaperDir,
            Config.home + "/.local/share/backgrounds",
            Config.home + "/Pictures"
        ];
    }

    function normalizePath(p: string): string {
        let s = (p || "").trim();
        if (s.startsWith("file://")) s = urlToPath(s);
        if (s === "~") s = Config.home;
        else if (s.startsWith("~/")) s = Config.home + s.slice(1);
        while (s.length > 1 && s.endsWith("/")) s = s.slice(0, -1);
        return s;
    }

    function displayPath(p: string): string {
        const s = normalizePath(p);
        if (!s) return "";
        if (Config.home && s === Config.home) return "~";
        if (Config.home && s.startsWith(Config.home + "/")) return "~" + s.slice(Config.home.length);
        return s;
    }

    function baseName(p: string): string {
        const s = normalizePath(p);
        if (!s) return "";
        const idx = s.lastIndexOf("/");
        return idx >= 0 ? s.slice(idx + 1) : s;
    }

    function pathToUrl(p: string): string {
        const clean = normalizePath(p);
        if (!clean) return "";
        return "file://" + clean.split("/").map(seg => encodeURIComponent(seg)).join("/");
    }

    function urlToPath(u: string): string {
        const s = (u || "").trim();
        if (!s.startsWith("file://")) return s;
        try { return decodeURIComponent(s.slice(7)); }
        catch (e) { return s.slice(7); }
    }

    function isGifPath(p: string): bool {
        return normalizePath(p).toLowerCase().endsWith(".gif");
    }

    function isWebpPath(p: string): bool {
        return normalizePath(p).toLowerCase().endsWith(".webp");
    }

    function isVideoPath(p: string): bool {
        const low = normalizePath(p).toLowerCase();
        return low.endsWith(".mp4") || low.endsWith(".webm") || low.endsWith(".mkv") || low.endsWith(".mov");
    }

    function needsConversion(p: string): bool {
        return isWebpPath(p) || isVideoPath(p);
    }

    // ---- Runtime Per-Screen History & Active URLs ----
    PersistentProperties {
        id: persist
        reloadableId: "hcs-wallpapers"
        property string current: ""
        property string screenUrlsJson: "{}"
        property string historyJson: "{}"
        property string seqIndexJson: "{}"
    }

    function getHistoryMap(): var {
        try { return JSON.parse(persist.historyJson || "{}"); }
        catch (e) { return {}; }
    }

    function pushHistory(screenName: string, url: string) {
        if (!url) return;
        const key = screenName || "_default";
        const map = getHistoryMap();
        const arr = Array.isArray(map[key]) ? map[key].slice() : [];
        if (arr.length > 0 && arr[arr.length - 1] === url) return;
        arr.push(url);
        if (arr.length > 40) arr.splice(0, arr.length - 40);
        map[key] = arr;
        persist.historyJson = JSON.stringify(map);
    }

    function setScreenUrl(screenName: string, url: string): void {
        if (!url) return;
        persist.current = url;
        const key = screenName || "_default";
        const nextMap = Object.assign({}, root.screenUrls);
        if (nextMap[key] && nextMap[key] !== url)
            pushHistory(key, nextMap[key]);
        nextMap[key] = url;
        persist.screenUrlsJson = JSON.stringify(nextMap);
    }

    function urlForScreen(screenName: string): string {
        const map = root.screenUrls;
        if (screenName && map[screenName]) return map[screenName];
        if (persist.current) return persist.current;
        return root.pickNextUrl(screenName, "");
    }

    function activeUrlForScreen(screenName: string): string {
        if (root.mode === "image") return root.resolvedSingleImageUrl;
        if (root.mode === "animated") return root.animatedKind === "file" ? root.resolvedAnimatedFileUrl : "";
        if (root.mode === "solid") return "";
        return root.urlForScreen(screenName);
    }

    function pickNextUrl(screenName: string, exclude: string): string {
        const files = root.folderFiles;
        if (!files || files.length === 0) return "";
        if (files.length === 1) return files[0].url;

        if (root.order === "sequential") {
            let idx = -1;
            if (exclude) idx = files.findIndex(f => f.url === exclude);
            if (idx < 0) {
                try {
                    const seqMap = JSON.parse(persist.seqIndexJson || "{}");
                    const saved = seqMap[screenName || "_default"];
                    if (typeof saved === "number") idx = saved;
                } catch (e) {}
            }
            const nextIdx = (idx + 1) % files.length;
            try {
                const seqMap = JSON.parse(persist.seqIndexJson || "{}");
                seqMap[screenName || "_default"] = nextIdx;
                persist.seqIndexJson = JSON.stringify(seqMap);
            } catch (e) {}
            return files[nextIdx].url;
        }

        let url = "";
        for (let tries = 0; tries < 6; tries++) {
            url = files[Math.floor(Math.random() * files.length)].url;
            if (url !== exclude) break;
        }
        return url;
    }

    // Legacy alias kept for compatibility with Wallpaper.qml / callers
    function randomUrl(exclude: string): string {
        return pickNextUrl("", exclude);
    }

    function next(): void {
        if (root.mode !== "folder") return;
        if (root.syncScreens) {
            const cur = persist.current || root.urlForScreen("");
            const url = root.pickNextUrl("", cur);
            if (!url) return;
            pushHistory("_sync", cur);
            setScreenUrl("", url);
            for (const s of Quickshell.screens) {
                setScreenUrl(s.name, url);
                root.screenForceUrl(s.name, url);
            }
        } else {
            root.tick();
        }
        if (slideshowTimer.running) slideshowTimer.restart();
    }

    function prev(screenName: string): void {
        if (root.mode !== "folder") return;
        const map = getHistoryMap();
        if (root.syncScreens) {
            const arr = Array.isArray(map["_sync"]) ? map["_sync"].slice() : [];
            if (arr.length === 0) return;
            const prevUrl = arr.pop();
            map["_sync"] = arr;
            persist.historyJson = JSON.stringify(map);
            for (const s of Quickshell.screens) {
                const nextMap = Object.assign({}, root.screenUrls);
                nextMap[s.name] = prevUrl;
                persist.screenUrlsJson = JSON.stringify(nextMap);
                persist.current = prevUrl;
                root.screenForceUrl(s.name, prevUrl);
            }
        } else {
            const targets = screenName ? [screenName] : Quickshell.screens.map(s => s.name);
            for (const sn of targets) {
                const arr = Array.isArray(map[sn]) ? map[sn].slice() : [];
                if (arr.length === 0) continue;
                const prevUrl = arr.pop();
                map[sn] = arr;
                const nextMap = Object.assign({}, root.screenUrls);
                nextMap[sn] = prevUrl;
                persist.screenUrlsJson = JSON.stringify(nextMap);
                persist.current = prevUrl;
                root.screenForceUrl(sn, prevUrl);
            }
            persist.historyJson = JSON.stringify(map);
        }
        if (slideshowTimer.running) slideshowTimer.restart();
    }

    function selectFolderImage(url: string, screenName: string): void {
        if (!url) return;
        root.lastStaticMode = "folder";
        root.resumeAnimatedOnPerf = false;
        if (root.mode !== "folder") {
            root.mode = "folder";
            scheduleSave();
        }
        if (root.syncScreens || !screenName) {
            for (const s of Quickshell.screens) {
                setScreenUrl(s.name, url);
                root.screenForceUrl(s.name, url);
            }
        } else {
            setScreenUrl(screenName, url);
            root.screenForceUrl(screenName, url);
        }
        if (slideshowTimer.running) slideshowTimer.restart();
    }

    // ---- Configuration Mutators & Power-Mode Sync ----
    function resolveStaticFallback(): string {
        if (root.lastStaticMode === "solid") return "solid";
        if (root.lastStaticMode === "image" && (root.resolvedSingleImageUrl !== "" || root.singleImagePath !== ""))
            return "image";
        if (root.folderFiles.length > 0 || root.scanningFolder || root.folderPath !== "")
            return "folder";
        return "solid";
    }

    function syncPowerMode(): void {
        if (root.passiveMode || !root.ready || !PowerProfile.ready) return;
        if (PowerProfile.mode !== "performance") {
            if (root.mode === "animated") {
                root.resumeAnimatedOnPerf = true;
                root.mode = resolveStaticFallback();
                scheduleSave();
            }
        } else {
            if (root.resumeAnimatedOnPerf) {
                root.resumeAnimatedOnPerf = false;
                root.mode = "animated";
                scheduleSave();
            }
        }
    }

    Connections {
        target: PowerProfile
        function onModeChanged() { root.syncPowerMode(); }
        function onReadyChanged() { root.syncPowerMode(); }
    }

    function setMode(m: string): void {
        if (["folder", "image", "animated", "solid"].indexOf(m) < 0) return;
        if (m === "animated") {
            if (!root.animatedAllowed) return;
            root.resumeAnimatedOnPerf = false;
        } else {
            root.lastStaticMode = m;
            root.resumeAnimatedOnPerf = false;
            if (m === "image" && !root.singleImagePath) {
                const fallback = urlToPath(persist.current || (root.folderFiles[0]?.url ?? ""));
                if (fallback) setSingleImage(fallback, false);
            }
        }
        root.mode = m;
        scheduleSave();
    }

    function addRecentFolder(path: string) {
        const clean = normalizePath(path);
        if (!clean) return;
        root.recentFolders = [clean].concat(root.recentFolders.filter(f => normalizePath(f) !== clean)).slice(0, 8);
    }

    function removeRecentFolder(path: string) {
        const clean = normalizePath(path);
        const defs = defaultFolders().map(d => normalizePath(d));
        if (defs.indexOf(clean) >= 0) return;
        root.recentFolders = root.recentFolders.filter(f => normalizePath(f) !== clean);
        scheduleSave();
    }

    function setFolder(path: string): void {
        const clean = normalizePath(path);
        if (!clean) return;
        const changed = root.folderPath !== clean;
        root.folderPath = clean;
        root.browseDir = clean;
        addRecentFolder(clean);
        root.lastStaticMode = "folder";
        root.resumeAnimatedOnPerf = false;
        root.mode = "folder";
        scheduleSave();
        if (changed) {
            persist.current = "";
            persist.screenUrlsJson = "{}";
            refreshFolderFiles();
        }
    }

    function setBrowseDir(path: string): void {
        const clean = normalizePath(path);
        if (!clean) return;
        root.browseDir = clean;
        addRecentFolder(clean);
        scheduleSave();
    }

    function setIncludeSubfolders(on: bool): void {
        if (root.includeSubfolders === on) return;
        root.includeSubfolders = on;
        scheduleSave();
        refreshFolderFiles();
    }

    function setOrder(o: string): void {
        if (o !== "random" && o !== "sequential") return;
        root.order = o;
        scheduleSave();
    }

    function setIntervalSec(sec: int): void {
        root.intervalSec = Math.max(0, sec);
        if (sec > 0 && root.slideshowPaused) root.slideshowPaused = false;
        scheduleSave();
    }

    function toggleSlideshowPause(): void {
        root.slideshowPaused = !root.slideshowPaused;
        scheduleSave();
    }

    function setSyncScreens(on: bool): void {
        if (root.syncScreens === on) return;
        root.syncScreens = on;
        if (on && root.mode === "folder") {
            const url = persist.current || root.urlForScreen("");
            if (url) {
                for (const s of Quickshell.screens) {
                    setScreenUrl(s.name, url);
                    root.screenForceUrl(s.name, url);
                }
            }
        }
        scheduleSave();
    }

    function addRecentImage(path: string) {
        const clean = normalizePath(path);
        if (!clean) return;
        root.recentImages = [clean].concat(root.recentImages.filter(p => normalizePath(p) !== clean)).slice(0, 12);
    }

    function setSingleImage(path: string, switchMode): void {
        const clean = normalizePath(path);
        if (!clean) return;
        const doSwitch = switchMode !== false;
        root.singleImagePath = clean;
        addRecentImage(clean);
        if (doSwitch) {
            root.lastStaticMode = "image";
            root.resumeAnimatedOnPerf = false;
            root.mode = "image";
        }
        resolveSingleMedia(clean);
        scheduleSave();
    }

    function setAnimatedKind(kind: string): void {
        if (kind !== "scene" && kind !== "file") return;
        root.animatedKind = kind;
        if (root.animatedAllowed) {
            root.resumeAnimatedOnPerf = false;
            if (root.mode !== "animated") root.mode = "animated";
        }
        scheduleSave();
    }

    function setScene(id: string): void {
        if (!root.scenes.some(s => s.id === id)) return;
        root.sceneId = id;
        root.animatedKind = "scene";
        if (root.animatedAllowed) {
            root.resumeAnimatedOnPerf = false;
            root.mode = "animated";
        }
        scheduleSave();
    }

    function setPalette(id: string): void {
        if (!root.palettes.some(p => p.id === id)) return;
        root.paletteId = id;
        scheduleSave();
    }

    function setCustomColors(bg: string, c1: string, c2: string): void {
        root.customBg = normalizeHex(bg, root.customBg);
        root.customColor1 = normalizeHex(c1, root.customColor1);
        root.customColor2 = normalizeHex(c2, root.customColor2);
        root.paletteId = "custom";
        scheduleSave();
    }

    function setAnimSpeed(v: real): void {
        root.animSpeed = Math.round(Math.max(0.25, Math.min(2.0, v)) * 20) / 20;
        scheduleSave();
    }

    function setAnimIntensity(v: real): void {
        root.animIntensity = Math.round(Math.max(0.3, Math.min(1.5, v)) * 20) / 20;
        scheduleSave();
    }

    function setAnimatedFile(path: string): void {
        const clean = normalizePath(path);
        if (!clean) return;
        root.animatedFilePath = clean;
        root.animatedKind = "file";
        if (root.animatedAllowed) {
            root.resumeAnimatedOnPerf = false;
            root.mode = "animated";
        }
        resolveAnimatedMedia(clean);
        scheduleSave();
    }

    function toggleAnimatedPause(): void {
        root.animatedPaused = !root.animatedPaused;
        scheduleSave();
    }

    function toggleCurrentPause(): void {
        if (root.mode === "animated") toggleAnimatedPause();
        else if (root.mode === "folder") toggleSlideshowPause();
    }

    function setPauseOnFullscreen(on: bool): void {
        root.pauseOnFullscreen = on;
        scheduleSave();
    }

    function setSolidColor(hex: string): void {
        root.solidColor = normalizeHex(hex, root.solidColor);
        root.lastStaticMode = "solid";
        root.resumeAnimatedOnPerf = false;
        root.mode = "solid";
        scheduleSave();
    }

    function setSolidVignette(on: bool): void {
        root.solidVignette = on;
        scheduleSave();
    }

    function setFitMode(m: string): void {
        if (["crop", "fit", "stretch", "center"].indexOf(m) < 0) return;
        root.fitMode = m;
        scheduleSave();
    }

    function setTransitionMs(ms: int): void {
        root.transitionMs = Math.max(0, Math.min(3000, ms));
        scheduleSave();
    }

    function setKenBurns(on: bool): void {
        root.kenBurns = on;
        scheduleSave();
    }

    function setDimAmount(v: real): void {
        root.dimAmount = Math.round(Math.max(0, Math.min(0.7, v)) * 100) / 100;
        scheduleSave();
    }

    function setBlurAmount(v: real): void {
        root.blurAmount = Math.round(Math.max(0, Math.min(1.0, v)) * 100) / 100;
        scheduleSave();
    }

    function reset(): void {
        root.mode = "folder";
        root.lastStaticMode = "folder";
        root.resumeAnimatedOnPerf = false;
        root.fitMode = "crop";
        root.transitionMs = 1200;
        root.kenBurns = false;
        root.dimAmount = 0.0;
        root.blurAmount = 0.0;
        root.syncScreens = false;
        root.folderPath = Config.wallpaperDir;
        root.includeSubfolders = false;
        root.order = "random";
        root.intervalSec = Config.wallpaperIntervalSec;
        root.slideshowPaused = false;
        root.recentFolders = defaultFolders();
        root.singleImagePath = "";
        root.resolvedSingleImageUrl = "";
        root.browseDir = Config.wallpaperDir;
        root.animatedKind = "scene";
        root.sceneId = "aurora";
        root.paletteId = "cosmic";
        root.customColor1 = "#FFAD00";
        root.customColor2 = "#3B82F6";
        root.customBg = "#101116";
        root.animSpeed = 1.0;
        root.animIntensity = 1.0;
        root.animatedFilePath = "";
        root.resolvedAnimatedFileUrl = "";
        root.animatedPaused = false;
        root.pauseOnFullscreen = true;
        root.solidColor = "#1B1B1B";
        root.solidVignette = true;
        saveNow();
        refreshFolderFiles();
        Qt.callLater(() => root.next());
    }

    // ---- Media Resolution (Native vs ffmpeg Cache for .webp / video) ----
    function hashString(str: string): string {
        let h = 2166136261;
        for (let i = 0; i < str.length; i++) {
            h ^= str.charCodeAt(i);
            h = Math.imul(h, 16777619);
        }
        return (h >>> 0).toString(16);
    }

    function resolveSingleMedia(path: string): void {
        const clean = normalizePath(path);
        if (!clean) {
            root.resolvedSingleImageUrl = "";
            return;
        }
        if (!needsConversion(clean)) {
            root.resolvedSingleImageUrl = pathToUrl(clean);
            return;
        }
        if (root.passiveMode) return;
        startMediaConvert("single", clean, isVideoPath(clean));
    }

    function resolveAnimatedMedia(path: string): void {
        const clean = normalizePath(path);
        if (!clean) {
            root.resolvedAnimatedFileUrl = "";
            return;
        }
        if (isGifPath(clean)) {
            root.convertError = "";
            root.resolvedAnimatedFileUrl = pathToUrl(clean);
            return;
        }
        if (!needsConversion(clean)) {
            root.convertError = "";
            root.resolvedAnimatedFileUrl = pathToUrl(clean);
            return;
        }
        if (root.passiveMode) return;
        startMediaConvert("animated", clean, isVideoPath(clean));
    }

    function startMediaConvert(slot: string, srcPath: string, asGif: bool): void {
        root.convertError = "";
        root.convertingMedia = true;
        const ext = asGif ? ".gif" : ".png";
        const outPath = root.cacheDir + "/" + hashString(srcPath) + ext;
        convertProc.pendingSlot = slot;
        convertProc.pendingOut = outPath;
        convertProc.running = false;
        if (asGif) {
            // Convert video (capped at first 12s, 15fps, 960px wide) to a looping GIF in cache.
            convertProc.command = [
                "sh", "-c",
                'mkdir -p "$3"; ' +
                'if [ ! -s "$2" ] || [ "$1" -nt "$2" ]; then ' +
                '  ffmpeg -y -v error -t 12 -i "$1" -vf "fps=15,scale=\'min(960,iw)\':-2:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=192[p];[s1][p]paletteuse=dither=bayer" "$2"; ' +
                'fi',
                "sh", srcPath, outPath, root.cacheDir
            ];
        } else {
            convertProc.command = [
                "sh", "-c",
                'mkdir -p "$3"; ' +
                'if [ ! -s "$2" ] || [ "$1" -nt "$2" ]; then ' +
                '  ffmpeg -y -v error -i "$1" -frames:v 1 "$2"; ' +
                'fi',
                "sh", srcPath, outPath, root.cacheDir
            ];
        }
        convertProc.running = true;
    }

    Process {
        id: convertProc
        property string pendingSlot: ""
        property string pendingOut: ""
        stderr: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t) root.convertError = t.split("\n")[0];
            }
        }
        onExited: code => {
            root.convertingMedia = false;
            if (code !== 0) {
                if (!root.convertError) root.convertError = "Could not decode media file";
                return;
            }
            root.convertError = "";
            const url = root.pathToUrl(pendingOut);
            if (pendingSlot === "single") root.resolvedSingleImageUrl = url;
            else if (pendingSlot === "animated") root.resolvedAnimatedFileUrl = url;
        }
    }

    // ---- Folder Scanning (Live FolderListModel + Optional Recursive find) ----
    function rebuildFromFolderModel(): void {
        if (root.includeSubfolders) return;
        const arr = [];
        for (let i = 0; i < folder.count; i++) {
            const url = String(folder.get(i, "fileUrl") || "");
            const name = String(folder.get(i, "fileName") || "");
            const path = String(folder.get(i, "filePath") || urlToPath(url));
            if (url) arr.push({ name: name, path: path, url: url, isGif: isGifPath(name) });
        }
        root.folderFiles = arr;
        if (!root.passiveMode && root.mode === "folder" && root.syncScreens && arr.length > 0) {
            if (!persist.current || !arr.some(f => f.url === persist.current))
                Qt.callLater(() => root.next());
        }
    }

    function refreshFolderFiles(): void {
        if (root.includeSubfolders) {
            root.scanningFolder = true;
            recursiveScanProc.running = false;
            recursiveScanProc.command = [
                "sh", "-c",
                'find "$1" -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" -o -iname "*.svg" -o -iname "*.gif" \\) 2>/dev/null | sort -V | head -n 2000',
                "sh", root.folderPath
            ];
            recursiveScanProc.running = true;
        } else {
            rebuildDebounce.restart();
        }
    }

    Timer {
        id: rebuildDebounce
        interval: 40
        onTriggered: root.rebuildFromFolderModel()
    }

    FolderListModel {
        id: folder
        folder: root.includeSubfolders ? "" : root.pathToUrl(root.folderPath)
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.svg", "*.gif"]
        showDirs: false
        caseSensitive: false
        sortField: FolderListModel.Name
        onCountChanged: if (!root.includeSubfolders) rebuildDebounce.restart()
        onStatusChanged: if (!root.includeSubfolders && status === FolderListModel.Ready) rebuildDebounce.restart()
    }

    Process {
        id: recursiveScanProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim() !== "");
                const arr = [];
                for (const p of lines) {
                    arr.push({
                        name: root.baseName(p),
                        path: p,
                        url: root.pathToUrl(p),
                        isGif: root.isGifPath(p)
                    });
                }
                root.folderFiles = arr;
                root.scanningFolder = false;
                if (!root.passiveMode && root.mode === "folder" && root.syncScreens && arr.length > 0) {
                    if (!persist.current || !arr.some(f => f.url === persist.current))
                        Qt.callLater(() => root.next());
                }
            }
        }
        onExited: root.scanningFolder = false
    }

    // ---- Slideshow Timer ----
    Timer {
        id: slideshowTimer
        interval: Math.max(5, root.intervalSec) * 1000
        running: !root.passiveMode && root.mode === "folder" && !root.slideshowPaused && root.intervalSec > 0 && root.count > 1
        repeat: true
        onTriggered: root.next()
    }

    // ---- Native Zenity File / Folder Picker ----
    function pickFolder(): void { openPicker("folder", root.folderPath); }
    function pickBrowseFolder(): void { openPicker("browseFolder", root.browseDir); }
    function pickImage(): void { openPicker("image", root.singleImagePath || root.browseDir); }
    function pickAnimatedFile(): void { openPicker("animatedFile", root.animatedFilePath || Config.home + "/Videos"); }

    function openPicker(kind: string, startPath: string): void {
        if (root.passiveMode || pickerProc.running) return;
        const cleanStart = normalizePath(startPath) || Config.home;
        let cmd;
        if (kind === "folder" || kind === "browseFolder") {
            cmd = [
                "sh", "-c",
                'zenity --file-selection --directory --title="Select Wallpaper Folder" --filename="$1/" < /dev/null',
                "sh", cleanStart
            ];
        } else if (kind === "animatedFile") {
            cmd = [
                "sh", "-c",
                'zenity --file-selection --title="Select Animated Wallpaper (GIF / Video)" --filename="$1" --file-filter="Animated & Video | *.gif *.mp4 *.webm *.mkv *.mov *.webp" --file-filter="All files | *" < /dev/null',
                "sh", cleanStart
            ];
        } else {
            cmd = [
                "sh", "-c",
                'zenity --file-selection --title="Select Wallpaper Image" --filename="$1" --file-filter="Images & GIFs | *.jpg *.jpeg *.png *.webp *.gif *.bmp *.svg" --file-filter="All files | *" < /dev/null',
                "sh", cleanStart
            ];
        }
        root.pickerOpen = true;
        pickerProc.pendingKind = kind;
        pickerProc.command = cmd;
        pickerProc.running = true;
    }

    Process {
        id: pickerProc
        property string pendingKind: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const chosen = text.trim();
                if (!chosen) return;
                if (pickerProc.pendingKind === "folder") root.setFolder(chosen);
                else if (pickerProc.pendingKind === "browseFolder") root.setBrowseDir(chosen);
                else if (pickerProc.pendingKind === "image") root.setSingleImage(chosen, true);
                else if (pickerProc.pendingKind === "animatedFile") root.setAnimatedFile(chosen);
            }
        }
        onExited: root.pickerOpen = false
    }

    // ---- Bing Daily Fetcher Integration ----
    function fetchBingNow(): void {
        if (root.passiveMode || bingProc.running) return;
        root.bingFetching = true;
        root.bingStatus = "Downloading today's Bing 4K…";
        bingProc.running = true;
    }

    Process {
        id: bingProc
        command: ["sh", "-c", '"$HOME/.scripts/bingpaper.sh" < /dev/null']
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                root.bingStatus = t ? t.split("\n").pop() : "Up to date";
            }
        }
        onExited: code => {
            root.bingFetching = false;
            if (code !== 0) root.bingStatus = "Bing fetch failed";
            else if (!root.bingStatus) root.bingStatus = "Bing folder synced";
            bingClearTimer.restart();
            if (root.includeSubfolders) root.refreshFolderFiles();
        }
    }

    Timer {
        id: bingClearTimer
        interval: 4000
        onTriggered: root.bingStatus = ""
    }

    // ---- Persistence (wallpaper-config.json) ----
    function scheduleSave(): void {
        if (root.passiveMode) return;
        saveTimer.restart();
    }

    function saveNow(): void {
        if (root.passiveMode) return;
        saveTimer.stop();
        const payload = {
            mode: root.mode,
            lastStaticMode: root.lastStaticMode,
            resumeAnimatedOnPerf: root.resumeAnimatedOnPerf,
            fitMode: root.fitMode,
            transitionMs: root.transitionMs,
            kenBurns: root.kenBurns,
            dimAmount: root.dimAmount,
            blurAmount: root.blurAmount,
            syncScreens: root.syncScreens,
            folderPath: root.folderPath,
            includeSubfolders: root.includeSubfolders,
            order: root.order,
            intervalSec: root.intervalSec,
            slideshowPaused: root.slideshowPaused,
            recentFolders: root.recentFolders,
            singleImagePath: root.singleImagePath,
            recentImages: root.recentImages,
            browseDir: root.browseDir,
            animatedKind: root.animatedKind,
            sceneId: root.sceneId,
            paletteId: root.paletteId,
            customColor1: root.customColor1,
            customColor2: root.customColor2,
            customBg: root.customBg,
            animSpeed: root.animSpeed,
            animIntensity: root.animIntensity,
            animatedFilePath: root.animatedFilePath,
            animatedPaused: root.animatedPaused,
            pauseOnFullscreen: root.pauseOnFullscreen,
            solidColor: root.solidColor,
            solidVignette: root.solidVignette
        };
        store.setText(JSON.stringify(payload, null, 2));
    }

    Timer {
        id: saveTimer
        interval: 150
        onTriggered: root.saveNow()
    }

    function loadJson(raw: string): void {
        try {
            const d = JSON.parse(raw);
            if (!d || typeof d !== "object") return;
            if (["folder", "image", "animated", "solid"].indexOf(d.mode) >= 0) root.mode = d.mode;
            if (["folder", "image", "solid"].indexOf(d.lastStaticMode) >= 0) root.lastStaticMode = d.lastStaticMode;
            else if (d.mode !== "animated" && ["folder", "image", "solid"].indexOf(d.mode) >= 0) root.lastStaticMode = d.mode;
            if (typeof d.resumeAnimatedOnPerf === "boolean") root.resumeAnimatedOnPerf = d.resumeAnimatedOnPerf;
            if (["crop", "fit", "stretch", "center"].indexOf(d.fitMode) >= 0) root.fitMode = d.fitMode;
            if (typeof d.transitionMs === "number") root.transitionMs = Math.max(0, Math.min(3000, d.transitionMs));
            if (typeof d.kenBurns === "boolean") root.kenBurns = d.kenBurns;
            if (typeof d.dimAmount === "number") root.dimAmount = Math.max(0, Math.min(0.7, d.dimAmount));
            if (typeof d.blurAmount === "number") root.blurAmount = Math.max(0, Math.min(1.0, d.blurAmount));
            if (typeof d.syncScreens === "boolean") root.syncScreens = d.syncScreens;

            if (typeof d.folderPath === "string" && d.folderPath.trim()) root.folderPath = normalizePath(d.folderPath);
            if (typeof d.includeSubfolders === "boolean") root.includeSubfolders = d.includeSubfolders;
            if (d.order === "random" || d.order === "sequential") root.order = d.order;
            if (typeof d.intervalSec === "number") root.intervalSec = Math.max(0, d.intervalSec);
            if (typeof d.slideshowPaused === "boolean") root.slideshowPaused = d.slideshowPaused;
            if (Array.isArray(d.recentFolders)) {
                const cleaned = d.recentFolders.filter(f => typeof f === "string" && f.trim()).map(f => normalizePath(f));
                if (cleaned.length > 0) root.recentFolders = cleaned.slice(0, 8);
            }

            if (typeof d.singleImagePath === "string") root.singleImagePath = normalizePath(d.singleImagePath);
            if (Array.isArray(d.recentImages)) {
                root.recentImages = d.recentImages.filter(f => typeof f === "string" && f.trim()).map(f => normalizePath(f)).slice(0, 12);
            }
            if (typeof d.browseDir === "string" && d.browseDir.trim()) root.browseDir = normalizePath(d.browseDir);

            if (d.animatedKind === "scene" || d.animatedKind === "file") root.animatedKind = d.animatedKind;
            if (typeof d.sceneId === "string" && root.scenes.some(s => s.id === d.sceneId)) root.sceneId = d.sceneId;
            if (typeof d.paletteId === "string" && root.palettes.some(p => p.id === d.paletteId)) root.paletteId = d.paletteId;
            if (typeof d.customColor1 === "string") root.customColor1 = normalizeHex(d.customColor1, root.customColor1);
            if (typeof d.customColor2 === "string") root.customColor2 = normalizeHex(d.customColor2, root.customColor2);
            if (typeof d.customBg === "string") root.customBg = normalizeHex(d.customBg, root.customBg);
            if (typeof d.animSpeed === "number") root.animSpeed = Math.max(0.25, Math.min(2.0, d.animSpeed));
            if (typeof d.animIntensity === "number") root.animIntensity = Math.max(0.3, Math.min(1.5, d.animIntensity));
            if (typeof d.animatedFilePath === "string") root.animatedFilePath = normalizePath(d.animatedFilePath);
            if (typeof d.animatedPaused === "boolean") root.animatedPaused = d.animatedPaused;
            if (typeof d.pauseOnFullscreen === "boolean") root.pauseOnFullscreen = d.pauseOnFullscreen;

            if (typeof d.solidColor === "string") root.solidColor = normalizeHex(d.solidColor, root.solidColor);
            if (typeof d.solidVignette === "boolean") root.solidVignette = d.solidVignette;
        } catch (e) {
            console.warn("Wallpapers: could not parse wallpaper-config.json:", e);
        }
    }

    Process {
        running: !root.passiveMode
        command: ["mkdir", "-p", Quickshell.stateDir, root.cacheDir]
    }

    FileView {
        id: store
        path: root.stateFile
        atomicWrites: true
        printErrors: false
        onLoaded: {
            root.loadJson(text());
            if (root.singleImagePath) root.resolveSingleMedia(root.singleImagePath);
            if (root.animatedFilePath) root.resolveAnimatedMedia(root.animatedFilePath);
            if (root.includeSubfolders) root.refreshFolderFiles();
            root.ready = true;
            root.syncPowerMode();
        }
        onLoadFailed: {
            root.ready = true;
            root.syncPowerMode();
        }
    }

    // qs ipc call wallpaper <method>; screenUrls is read by lock.qml
    IpcHandler {
        target: "wallpaper"
        function next(): void { root.next(); }
        function prev(): void { root.prev(""); }
        function togglePause(): void { root.toggleCurrentPause(); }
        function setMode(m: string): void { root.setMode(m); }
        function setFolder(p: string): void { root.setFolder(p); }
        function setImage(p: string): void { root.setSingleImage(p, true); }
        function setScene(id: string): void { root.setScene(id); }
        function setPalette(id: string): void { root.setPalette(id); }
        function setSolidColor(hex: string): void { root.setSolidColor(hex); }
        function screenUrls(): string {
            const pal = root.activePalette();
            return JSON.stringify({
                mode: root.mode,
                current: root.mode === "image" ? root.resolvedSingleImageUrl
                       : (root.mode === "animated" && root.animatedKind === "file") ? root.resolvedAnimatedFileUrl
                       : persist.current,
                screens: root.screenUrls,
                fitMode: root.fitMode,
                animatedKind: root.animatedKind,
                sceneId: root.sceneId,
                paletteBg: pal.bg,
                paletteC1: pal.c1,
                paletteC2: pal.c2,
                paletteC3: pal.c3,
                animSpeed: root.animSpeed,
                animIntensity: root.animIntensity,
                animatedFileUrl: root.resolvedAnimatedFileUrl,
                solidColor: root.solidColor,
                solidVignette: root.solidVignette
            });
        }
    }
}
