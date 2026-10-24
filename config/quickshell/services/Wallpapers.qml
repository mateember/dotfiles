pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs

// Wallpaper slideshow source: images in Config.wallpaperDir, picked at random.
// The folder is watched, so new Bing images show up without a restart.
// Each screen asks for its own random image on every tick (see wallpaper/Wallpaper.qml).
Singleton {
    id: root

    readonly property int count: folder.count
    signal tick()   // time to change wallpaper

    function randomUrl(exclude: string): string {
        if (folder.count === 0) return "";
        let url = "";
        for (let tries = 0; tries < 5; tries++) {
            url = String(folder.get(Math.floor(Math.random() * folder.count), "fileUrl"));
            if (url !== exclude || folder.count === 1) break;
        }
        return url;
    }

    FolderListModel {
        id: folder
        folder: "file://" + Config.wallpaperDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        showDirs: false
        caseSensitive: false
    }

    Timer {
        interval: Config.wallpaperIntervalSec * 1000
        running: root.count > 1
        repeat: true
        onTriggered: root.tick()
    }

    // qs -p <root>/shell ipc call wallpaper next
    IpcHandler {
        target: "wallpaper"
        function next(): void { root.tick(); }
    }
}
