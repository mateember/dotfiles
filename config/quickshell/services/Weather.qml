pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Weather from Open-Meteo (no API key). The response is cached in Quickshell's cache dir,
// so the last known weather shows immediately at startup and when offline.
Singleton {
    id: root

    property bool ready: false     // true once any data (cached or fresh) is parsed
    property bool stale: false     // last fetch failed; showing cached data
    property real temp: 0
    property real feelsLike: 0
    property int code: -1
    property bool isDay: true
    property var daily: []         // [{ date: Date, code, max, min, rain (mm), rainChance (%) }]
    // Today's details (current conditions + today's daily values)
    property real humidity: 0      // %
    property real wind: 0          // km/h
    property real gusts: 0         // km/h
    property real windDir: 0       // degrees the wind comes FROM
    property real pressure: 0      // hPa (sea level)
    property real uvMax: 0
    property real rainToday: 0     // mm
    property int rainChance: 0     // % (max today)
    property date sunrise: new Date(0)
    property date sunset: new Date(0)
    property date updated: new Date(0)

    readonly property string icon: info(code, isDay).icon
    readonly property string description: info(code, isDay).text
    readonly property string cacheFile: Quickshell.cachePath("weather.json")

    // WMO weather interpretation codes → Material Symbols icon + text.
    function info(c: int, day: bool): var {
        if (c === 0) return { icon: day ? "clear_day" : "clear_night", text: "Clear" };
        if (c === 1) return { icon: day ? "partly_cloudy_day" : "partly_cloudy_night", text: "Mainly clear" };
        if (c === 2) return { icon: day ? "partly_cloudy_day" : "partly_cloudy_night", text: "Partly cloudy" };
        if (c === 3) return { icon: "cloud", text: "Overcast" };
        if (c === 45 || c === 48) return { icon: "foggy", text: "Fog" };
        if (c >= 51 && c <= 57) return { icon: "rainy_light", text: "Drizzle" };
        if (c >= 61 && c <= 67) return { icon: "rainy", text: "Rain" };
        if (c >= 71 && c <= 77) return { icon: "weather_snowy", text: "Snow" };
        if (c >= 80 && c <= 82) return { icon: "rainy_heavy", text: "Showers" };
        if (c === 85 || c === 86) return { icon: "weather_snowy", text: "Snow showers" };
        if (c >= 95) return { icon: "thunderstorm", text: "Thunderstorm" };
        return { icon: "cloud", text: "" };
    }

    // 16-point compass name for a wind direction (where the wind comes from).
    function compass(deg: real): string {
        const n = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
        return n[Math.round(((deg % 360) + 360) % 360 / 22.5) % 16];
    }

    function parse(text: string) {
        try {
            const j = JSON.parse(text);
            root.temp = j.current.temperature_2m;
            root.feelsLike = j.current.apparent_temperature;
            root.code = j.current.weather_code;
            root.isDay = j.current.is_day === 1;
            root.updated = new Date(j.current.time);
            root.humidity = j.current.relative_humidity_2m ?? 0;
            root.wind = j.current.wind_speed_10m ?? 0;
            root.gusts = j.current.wind_gusts_10m ?? 0;
            root.windDir = j.current.wind_direction_10m ?? 0;
            root.pressure = j.current.pressure_msl ?? 0;
            const d = j.daily;
            root.daily = d.time.map((t, i) => ({
                date: new Date(t + "T12:00"),
                code: d.weather_code[i],
                max: d.temperature_2m_max[i],
                min: d.temperature_2m_min[i],
                rain: d.precipitation_sum?.[i] ?? 0,
                rainChance: d.precipitation_probability_max?.[i] ?? 0
            }));
            root.uvMax = d.uv_index_max?.[0] ?? 0;
            root.rainToday = d.precipitation_sum?.[0] ?? 0;
            root.rainChance = d.precipitation_probability_max?.[0] ?? 0;
            if (d.sunrise) root.sunrise = new Date(d.sunrise[0]);
            if (d.sunset) root.sunset = new Date(d.sunset[0]);
            root.ready = true;
        } catch (e) {
            console.warn("Weather: could not parse cache:", e);
        }
    }

    function refresh() {
        if (!fetch.running) fetch.running = true;
    }

    FileView {
        id: cache
        path: root.cacheFile
        printErrors: false
        onLoaded: root.parse(text())
    }

    // Fetches into a temp file and renames, so a failed fetch never clobbers the cache.
    Process {
        id: fetch
        command: ["sh", "-c", `
            cache=$1 lat=$2 lon=$3 auto=$4
            if [ "$auto" = 1 ]; then
              l=$(curl -sf -m 5 "http://ip-api.com/line/?fields=lat,lon") && {
                lat=$(echo "$l" | sed -n 1p); lon=$(echo "$l" | sed -n 2p); }
            fi
            mkdir -p "$(dirname "$cache")"
            curl -sf -m 15 -o "$cache.tmp" "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,apparent_temperature,weather_code,is_day,relative_humidity_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m,pressure_msl&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,uv_index_max,sunrise,sunset&timezone=auto&forecast_days=5" \
              && mv "$cache.tmp" "$cache"`,
            "sh", root.cacheFile, String(Config.weatherLat), String(Config.weatherLon), Config.weatherAutoLocate ? "1" : "0"]
        onExited: code => {
            root.stale = code !== 0;
            if (code === 0) cache.reload();
        }
    }

    Timer {
        interval: Config.weatherRefreshMinutes * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
