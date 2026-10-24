pragma Singleton

import QtQuick
import Quickshell

// User-tunable settings. Edit and save; Quickshell hot-reloads.
// The only absolute paths come from $HOME and the project root.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") ?? ""

    // ---- clock (CosmicAppletTime: military_time, show_weekday, first_day_of_week 0) ----
    // "Sat, Oct 24, 15:52"
    readonly property string clockFormat: "ddd, MMM d, HH:mm"
    // Empty = system locale. Set to e.g. "hu_HU" for Hungarian day/month names.
    readonly property string locale: "en_US"
    readonly property int firstDayOfWeek: Qt.Sunday

    // ---- weather (from com.vintagetechie.CosmicExtAppletTempest) ----
    readonly property real weatherLat: 47.42733
    readonly property real weatherLon: 19.40133
    readonly property string weatherLocation: "Gyömrő"
    readonly property int weatherRefreshMinutes: 15
    // If true, ignore the coordinates above and geolocate by IP.
    readonly property bool weatherAutoLocate: false

    // ---- wallpaper (from com.system76.CosmicBackground) ----
    readonly property string wallpaperDir: home + "/Pictures/BingWallpaper"
    // Random slideshow; 300 s = COSMIC's rotation_frequency. Next image now: qs ... ipc call wallpaper next
    readonly property int wallpaperIntervalSec: 300

    // ---- notifications ----
    // HCS_NO_NOTIFY=1 skips the notification server (e.g. to test under another desktop).
    readonly property bool notificationsEnabled: (Quickshell.env("HCS_NO_NOTIFY") ?? "") !== "1"
}
