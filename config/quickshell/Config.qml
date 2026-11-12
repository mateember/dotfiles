pragma Singleton

import QtQuick
import Quickshell

// User-tunable settings (hot-reloaded on save).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") ?? ""

    readonly property string clockFormat: "ddd, MMM d, HH:mm"
    // Empty = system locale; e.g. "hu_HU" for Hungarian day/month names
    readonly property string locale: "en_US"
    readonly property int firstDayOfWeek: Qt.Sunday

    // GNOME Calendar / Online Accounts (EDS); unchecked calendars are skipped automatically
    readonly property var calendarHidden: []
    readonly property bool calendarShowTasks: true
    readonly property int calendarRefreshMinutes: 15

    // Default weather settings (used on first run / reset; live changes are saved in weather-config.json)
    readonly property real weatherLat: 47.42733
    readonly property real weatherLon: 19.40133
    readonly property string weatherLocation: "Gyömrő"
    readonly property int weatherRefreshMinutes: 15
    readonly property bool weatherAutoLocate: false // true ignores lat/lon and geolocates by IP

    readonly property string wallpaperDir: home + "/Pictures/BingWallpaper"
    // Next image: qs ipc call wallpaper next
    readonly property int wallpaperIntervalSec: 300

    // HCS_NO_NOTIFY=1 disables the notification server
    readonly property bool notificationsEnabled: (Quickshell.env("HCS_NO_NOTIFY") ?? "") !== "1"
}
