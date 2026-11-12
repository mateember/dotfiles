pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs

// Weather service powered by Open-Meteo (forecast + geocoding, no API key) and IP geolocation.
// Fetches canonical metric units and converts at display time so unit changes apply instantly.
Singleton {
    id: root

    property bool ready: false     // true once any data (cached or fresh) is parsed
    property bool stale: false     // last fetch failed; showing cached data or error
    property bool loading: false
    property string error: ""

    // Current conditions (canonical metric units)
    property real tempC: 0
    property real feelsLikeC: 0
    property real dewPointC: 0
    property int code: -1
    property bool isDay: true
    property real humidity: 0          // %
    property real cloudCover: 0        // %
    property real windKmh: 0           // km/h
    property real gustsKmh: 0          // km/h
    property real windDir: 0           // degrees wind comes FROM
    property real pressureHpa: 0       // hPa
    property real visibilityM: 0       // meters
    property real uvCurrent: 0
    property real uvMax: 0
    property real precipCurrentMm: 0   // mm
    property real rainTodayMm: 0       // mm
    property int rainChance: 0         // % (today's max)
    property string sunriseStr: ""     // "HH:mm" in location timezone
    property string sunsetStr: ""      // "HH:mm" in location timezone
    property string timezoneAbbr: ""
    property date updated: new Date(0)
    property date fetchedAt: new Date(0)

    // Resolved location metadata
    property string detectedLocation: ""
    property string detectedRegion: ""
    property real fetchedLat: NaN
    property real fetchedLon: NaN

    // Data source / station metadata (populated when HungaroMet hybrid applies)
    property string activeSource: "openmeteo"   // "hybrid" | "openmeteo"
    property string stationName: ""
    property real stationDistanceKm: -1
    property string stationTimeIso: ""

    // Forecasts
    property var hourly: []            // [{ isoTime, code, isDay, tempC, rainChance, precipMm }]
    property var daily: []             // [{ date, code, maxC, minC, rainMm, rainChance, uvMax, windMaxKmh, sunriseStr, sunsetStr }]

    // Geocoding search state
    property bool searching: false
    property string searchError: ""
    property var searchResults: []

    property bool _pendingRefresh: false
    property real _pendingLat: 0
    property real _pendingLon: 0
    property string _pendingLocName: ""
    property string _pendingLocRegion: ""
    property bool _pendingAuto: false
    property bool _pendingForecastDone: false
    property bool _pendingObsDone: false
    property bool _pendingForecastOk: false
    property var _pendingForecastJson: null
    property var _pendingObs: null
    property var _lastForecastJson: null
    property var _lastForecastMeta: null
    property string _queuedSearch: ""
    property string _activeSearch: ""

    readonly property string icon: info(code, isDay).icon
    readonly property string description: info(code, isDay).text
    readonly property string cacheFile: Quickshell.cachePath("weather.json")
    readonly property string hungarometScript: Quickshell.shellPath("scripts/hungaromet.py")

    readonly property string displayLocation: {
        if (WeatherConfig.autoLocate)
            return detectedLocation !== "" ? detectedLocation : "Auto-locate";
        return WeatherConfig.locationName !== "" ? WeatherConfig.locationName : "Weather";
    }

    readonly property string displayRegion: {
        if (WeatherConfig.autoLocate) return detectedRegion;
        return WeatherConfig.locationRegion;
    }

    // WMO weather interpretation codes -> Material Symbols icon + text.
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

    // ---- Unit conversion & display helpers ----
    function convertTemp(c: real): real {
        return WeatherConfig.tempUnit === "F" ? (c * 9 / 5 + 32) : c;
    }

    function formatTemp(c: real, includeUnit: bool): string {
        const val = Math.round(convertTemp(c));
        return val + (includeUnit ? ("°" + WeatherConfig.tempUnit) : "°");
    }

    function formatWindValue(kmh: real): string {
        const u = WeatherConfig.windUnit;
        if (u === "ms") {
            const v = kmh / 3.6;
            return v < 10 ? v.toFixed(1) : String(Math.round(v));
        }
        if (u === "mph") return String(Math.round(kmh * 0.621371));
        if (u === "kn") return String(Math.round(kmh * 0.539957));
        return String(Math.round(kmh));
    }

    function windUnitLabel(): string {
        const u = WeatherConfig.windUnit;
        if (u === "ms") return "m/s";
        if (u === "mph") return "mph";
        if (u === "kn") return "kn";
        return "km/h";
    }

    function formatWind(kmh: real): string {
        return formatWindValue(kmh) + " " + windUnitLabel();
    }

    function formatPrecip(mm: real): string {
        if (WeatherConfig.precipUnit === "in")
            return (mm / 25.4).toFixed(2) + " in";
        return mm.toFixed(1) + " mm";
    }

    function formatPressure(hpa: real): string {
        if (WeatherConfig.pressureUnit === "inHg")
            return (hpa * 0.02953).toFixed(2) + " inHg";
        if (WeatherConfig.pressureUnit === "mmHg")
            return Math.round(hpa * 0.750062) + " mmHg";
        return Math.round(hpa) + " hPa";
    }

    function formatVisibility(meters: real): string {
        if (WeatherConfig.visibilityUnit === "mi")
            return (meters / 1609.344).toFixed(1) + " mi";
        if (meters >= 1000) {
            const km = meters / 1000;
            return (km >= 10 ? Math.round(km) : km.toFixed(1)) + " km";
        }
        return Math.round(meters) + " m";
    }

    function formatClockHHMM(hhmm: string): string {
        if (!hhmm || hhmm.length < 5) return "--:--";
        const parts = hhmm.split(":");
        const h = parseInt(parts[0], 10);
        const m = parseInt(parts[1], 10);
        if (isNaN(h) || isNaN(m)) return hhmm;
        if (WeatherConfig.timeFormat === "12h") {
            const suffix = h >= 12 ? "PM" : "AM";
            const h12 = h % 12 === 0 ? 12 : h % 12;
            return `${h12}:${String(m).padStart(2, "0")} ${suffix}`;
        }
        return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
    }

    function formatHourLabel(isoTime: string, index: int): string {
        if (index === 0) return "Now";
        if (!isoTime || isoTime.length < 16) return "";
        const h = parseInt(isoTime.slice(11, 13), 10);
        if (isNaN(h)) return isoTime.slice(11, 16);
        if (WeatherConfig.timeFormat === "12h") {
            const suffix = h >= 12 ? "PM" : "AM";
            const h12 = h % 12 === 0 ? 12 : h % 12;
            return `${h12} ${suffix}`;
        }
        return isoTime.slice(11, 16);
    }

    function uvCategory(uv: real): string {
        if (uv < 3) return "low";
        if (uv < 6) return "moderate";
        if (uv < 8) return "high";
        if (uv < 11) return "very high";
        return "extreme";
    }

    function tileData(id: string): var {
        switch (id) {
            case "rain":
                return {
                    icon: "rainy",
                    label: "Rain",
                    value: root.rainChance + "%",
                    sub: root.formatPrecip(root.rainTodayMm) + " today",
                    iconRotation: 0
                };
            case "humidity":
                return {
                    icon: "humidity_percentage",
                    label: "Humidity",
                    value: Math.round(root.humidity) + "%",
                    sub: "dew " + root.formatTemp(root.dewPointC, false),
                    iconRotation: 0
                };
            case "wind":
                return {
                    icon: "navigation",
                    label: "Wind",
                    value: root.formatWind(root.windKmh),
                    sub: root.compass(root.windDir) + " · gusts " + root.formatWindValue(root.gustsKmh),
                    iconRotation: root.windDir + 180
                };
            case "uv":
                return {
                    icon: "light_mode",
                    label: "UV",
                    value: root.uvMax.toFixed(0),
                    sub: root.uvCategory(root.uvMax) + (root.uvCurrent >= 0.5 ? ` · now ${root.uvCurrent.toFixed(0)}` : ""),
                    iconRotation: 0
                };
            case "pressure":
                return {
                    icon: "compress",
                    label: "Pressure",
                    value: root.formatPressure(root.pressureHpa),
                    sub: "",
                    iconRotation: 0
                };
            case "sun":
                return {
                    icon: "wb_twilight",
                    label: "Sun",
                    value: root.formatClockHHMM(root.sunriseStr),
                    sub: "sets " + root.formatClockHHMM(root.sunsetStr),
                    iconRotation: 0
                };
            case "feelsLike":
                return {
                    icon: "thermostat",
                    label: "Feels like",
                    value: root.formatTemp(root.feelsLikeC, true),
                    sub: Math.abs(root.feelsLikeC - root.tempC) >= 1
                        ? (root.feelsLikeC > root.tempC ? "warmer than air" : "cooler than air")
                        : "matches air",
                    iconRotation: 0
                };
            case "cloudCover":
                return {
                    icon: "cloud",
                    label: "Clouds",
                    value: Math.round(root.cloudCover) + "%",
                    sub: root.cloudCover < 20 ? "mostly clear" : root.cloudCover < 60 ? "scattered" : "overcast",
                    iconRotation: 0
                };
            case "visibility":
                return {
                    icon: "visibility",
                    label: "Visibility",
                    value: root.formatVisibility(root.visibilityM),
                    sub: root.visibilityM >= 10000 ? "clear view" : root.visibilityM >= 4000 ? "moderate" : "reduced",
                    iconRotation: 0
                };
            case "dewPoint":
                return {
                    icon: "dew_point",
                    label: "Dew point",
                    value: root.formatTemp(root.dewPointC, true),
                    sub: root.dewPointC >= 20 ? "muggy"
                       : root.dewPointC >= 15 ? "humid"
                       : (root.tempC - root.dewPointC) <= 2 ? "saturated"
                       : root.dewPointC >= 8 ? "comfortable" : "dry",
                    iconRotation: 0
                };
            default:
                return { icon: "cloud", label: id, value: "--", sub: "", iconRotation: 0 };
        }
    }

    function barItemText(id: string): string {
        if (!root.ready) return id === "temp" ? "--°" : "";
        switch (id) {
            case "temp":      return root.formatTemp(root.tempC, WeatherConfig.barShowUnit);
            case "condition": return root.description;
            case "feelsLike": return "Feels " + root.formatTemp(root.feelsLikeC, WeatherConfig.barShowUnit);
            case "rain":      return root.rainChance + "%";
            case "wind":      return root.formatWind(root.windKmh);
            case "humidity":  return Math.round(root.humidity) + "%";
            case "highLow": {
                if (root.daily.length === 0) return "";
                const d0 = root.daily[0];
                return root.formatTemp(d0.maxC, false) + "/" + root.formatTemp(d0.minC, false);
            }
            case "location":  return root.displayLocation;
            default:          return "";
        }
    }

    // ---- Parsing & Caching ----
    function isoToHHMM(iso: string): string {
        if (!iso || iso.length < 16) return "";
        return iso.slice(11, 16);
    }

    function applyPayload(j: var, meta: var): bool {
        if (!j || !j.current || !j.daily || !Array.isArray(j.daily.time))
            return false;

        const c = j.current;
        const d = j.daily;

        root.tempC = Number(c.temperature_2m ?? 0);
        root.feelsLikeC = Number(c.apparent_temperature ?? root.tempC);
        root.dewPointC = Number(c.dew_point_2m ?? root.tempC);
        root.code = Number(c.weather_code ?? -1);
        root.isDay = c.is_day === 1;
        root.humidity = Number(c.relative_humidity_2m ?? 0);
        root.cloudCover = Number(c.cloud_cover ?? 0);
        root.windKmh = Number(c.wind_speed_10m ?? 0);
        root.gustsKmh = Number(c.wind_gusts_10m ?? 0);
        root.windDir = Number(c.wind_direction_10m ?? 0);
        root.pressureHpa = Number(c.pressure_msl ?? 0);
        root.visibilityM = Number(c.visibility ?? 0);
        root.uvCurrent = Number(c.uv_index ?? 0);
        root.precipCurrentMm = Number(c.precipitation ?? 0);
        root.timezoneAbbr = String(j.timezone_abbreviation ?? "");

        const curTimeStr = String(c.time ?? "");
        root.updated = curTimeStr !== "" ? new Date(curTimeStr) : new Date();

        if (meta && meta.fetchedAt)
            root.fetchedAt = new Date(meta.fetchedAt);
        else
            root.fetchedAt = root.updated;

        if (meta && typeof meta.lat === "number" && !isNaN(meta.lat))
            root.fetchedLat = meta.lat;
        else if (typeof j.latitude === "number")
            root.fetchedLat = j.latitude;

        if (meta && typeof meta.lon === "number" && !isNaN(meta.lon))
            root.fetchedLon = meta.lon;
        else if (typeof j.longitude === "number")
            root.fetchedLon = j.longitude;

        if (meta && meta.autoLocated) {
            if (meta.locationLabel) root.detectedLocation = String(meta.locationLabel);
            if (meta.locationRegion !== undefined) root.detectedRegion = String(meta.locationRegion);
        }

        // Daily forecast
        root.daily = d.time.map((t, i) => ({
            date: new Date(t + "T12:00"),
            code: Number(d.weather_code?.[i] ?? 0),
            maxC: Number(d.temperature_2m_max?.[i] ?? 0),
            minC: Number(d.temperature_2m_min?.[i] ?? 0),
            rainMm: Number(d.precipitation_sum?.[i] ?? 0),
            rainChance: Math.round(Number(d.precipitation_probability_max?.[i] ?? 0)),
            uvMax: Number(d.uv_index_max?.[i] ?? 0),
            windMaxKmh: Number(d.wind_speed_10m_max?.[i] ?? 0),
            sunriseStr: isoToHHMM(d.sunrise?.[i] ?? ""),
            sunsetStr: isoToHHMM(d.sunset?.[i] ?? "")
        }));

        root.uvMax = d.uv_index_max?.[0] ?? 0;
        root.rainTodayMm = d.precipitation_sum?.[0] ?? 0;
        root.rainChance = Math.round(Number(d.precipitation_probability_max?.[0] ?? 0));
        root.sunriseStr = isoToHHMM(d.sunrise?.[0] ?? "");
        root.sunsetStr = isoToHHMM(d.sunset?.[0] ?? "");

        // Hourly forecast sliced from current location hour
        const h = j.hourly;
        if (h && Array.isArray(h.time)) {
            const curHourKey = curTimeStr.length >= 13 ? (curTimeStr.slice(0, 13) + ":00") : "";
            let startIdx = 0;
            if (curHourKey !== "") {
                const idx = h.time.findIndex(t => t >= curHourKey);
                if (idx >= 0) startIdx = idx;
            }
            const endIdx = Math.min(h.time.length, startIdx + 24);
            const slice = [];
            for (let i = startIdx; i < endIdx; i++) {
                slice.push({
                    isoTime: String(h.time[i]),
                    code: Number(h.weather_code?.[i] ?? 0),
                    isDay: h.is_day?.[i] !== undefined ? (h.is_day[i] === 1) : true,
                    tempC: Number(h.temperature_2m?.[i] ?? 0),
                    rainChance: Math.round(Number(h.precipitation_probability?.[i] ?? 0)),
                    precipMm: Number(h.precipitation?.[i] ?? 0)
                });
            }
            root.hourly = slice;
        } else {
            root.hourly = [];
        }

        root._lastForecastJson = j;
        root._lastForecastMeta = meta;

        const obs = (WeatherConfig.dataSource === "hybrid" && meta && meta.hungaromet && meta.hungaromet.available === true)
            ? meta.hungaromet
            : null;
        if (obs) {
            root.activeSource = "hybrid";
            root.stationName = String(obs.stationName || "");
            root.stationDistanceKm = Number(obs.distanceKm ?? -1);
            root.stationTimeIso = String(obs.obsTimeIso || "");

            if (obs.tempC !== null && obs.tempC !== undefined) root.tempC = Number(obs.tempC);
            if (obs.humidity !== null && obs.humidity !== undefined) root.humidity = Number(obs.humidity);
            if (obs.windKmh !== null && obs.windKmh !== undefined) root.windKmh = Number(obs.windKmh);
            if (obs.gustsKmh !== null && obs.gustsKmh !== undefined) root.gustsKmh = Number(obs.gustsKmh);
            if (obs.windDir !== null && obs.windDir !== undefined) root.windDir = Number(obs.windDir);
            if (obs.pressureHpa !== null && obs.pressureHpa !== undefined) root.pressureHpa = Number(obs.pressureHpa);
            if (obs.visibilityM !== null && obs.visibilityM !== undefined) root.visibilityM = Number(obs.visibilityM);
            if (obs.precip10mMm !== null && obs.precip10mMm !== undefined) {
                root.precipCurrentMm = Number(obs.precip10mMm);
                if (obs.precip10mMm >= 0.4 && root.code < 51)
                    root.code = root.tempC <= 1.0 ? 73 : 61;
                else if (obs.precip10mMm > 0 && root.code < 51)
                    root.code = root.tempC <= 1.0 ? 71 : 51;
            }

            // Recompute dew point (Magnus) & apparent temp (Steadman) from measured station values.
            const rh = Math.max(1, Math.min(100, root.humidity));
            const gamma = (17.625 * root.tempC) / (243.04 + root.tempC) + Math.log(rh / 100.0);
            root.dewPointC = (243.04 * gamma) / (17.625 - gamma);

            const e = (Math.max(0, Math.min(100, root.humidity)) / 100.0) * 6.105
                * Math.exp((17.27 * root.tempC) / (237.7 + root.tempC));
            root.feelsLikeC = root.tempC + 0.33 * e - 0.70 * (root.windKmh / 3.6) - 4.00;

            if (root.hourly.length > 0) {
                const h0 = Object.assign({}, root.hourly[0], { tempC: root.tempC });
                root.hourly = [h0].concat(root.hourly.slice(1));
            }
        } else {
            root.activeSource = "openmeteo";
            root.stationName = "";
            root.stationDistanceKm = -1;
            root.stationTimeIso = "";
        }

        root.ready = true;
        return true;
    }

    function parseCache(text: string) {
        try {
            const raw = JSON.parse(text);
            const payload = raw.data ?? raw;
            const meta = raw.data ? raw : null;
            applyPayload(payload, meta);
        } catch (e) {
            console.warn("Weather: could not parse cache:", e);
        }
    }

    // ---- Refresh & Fetching ----
    function refresh() {
        if (!WeatherConfig.ready) return;
        if (root.loading) {
            root._pendingRefresh = true;
            return;
        }
        root.loading = true;
        root.error = "";

        if (WeatherConfig.autoLocate) {
            geoFetch.runCommand(["sh", "-c", `
                out=$(curl -sf -m 5 "https://ipwho.is/")
                if echo "$out" | grep -q '"success":true'; then
                    printf '%s' "$out"
                else
                    curl -sf -m 5 "http://ip-api.com/json/?fields=status,lat,lon,city,regionName,country,countryCode"
                fi
            `]);
        } else {
            startForecastFetch(
                WeatherConfig.latitude,
                WeatherConfig.longitude,
                WeatherConfig.locationName,
                WeatherConfig.locationRegion,
                false
            );
        }
    }

    function inHungaryRegion(lat: real, lon: real): bool {
        return lat >= 45.2 && lat <= 49.1 && lon >= 15.5 && lon <= 23.5;
    }

    function startForecastFetch(lat: real, lon: real, locName: string, locRegion: string, auto: bool) {
        root._pendingLat = lat;
        root._pendingLon = lon;
        root._pendingLocName = locName;
        root._pendingLocRegion = locRegion;
        root._pendingAuto = auto;
        root._pendingForecastDone = false;
        root._pendingForecastOk = false;
        root._pendingForecastJson = null;
        root._pendingObs = null;

        const url = "https://api.open-meteo.com/v1/forecast"
            + `?latitude=${lat}&longitude=${lon}`
            + "&current=temperature_2m,apparent_temperature,weather_code,is_day,relative_humidity_2m,dew_point_2m,cloud_cover,precipitation,wind_speed_10m,wind_direction_10m,wind_gusts_10m,pressure_msl,uv_index,visibility"
            + "&hourly=temperature_2m,weather_code,is_day,precipitation_probability,precipitation"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,uv_index_max,wind_speed_10m_max,sunrise,sunset"
            + "&timezone=auto&forecast_days=10";
        forecastFetch.runCommand(["curl", "-sf", "-m", "15", url]);

        if (WeatherConfig.dataSource === "hybrid" && inHungaryRegion(lat, lon)) {
            root._pendingObsDone = false;
            hungarometFetch.runCommand(["python3", root.hungarometScript, String(lat), String(lon), "50"]);
        } else {
            root._pendingObsDone = true;
        }
    }

    function maybeFinalizeFetch() {
        if (!root._pendingForecastDone || !root._pendingObsDone) return;
        if (root._pendingForecastOk && root._pendingForecastJson) {
            const meta = {
                fetchedAt: Date.now(),
                locationLabel: root._pendingLocName,
                locationRegion: root._pendingLocRegion,
                autoLocated: root._pendingAuto,
                lat: root._pendingLat,
                lon: root._pendingLon,
                dataSource: WeatherConfig.dataSource,
                hungaromet: root._pendingObs
            };
            if (root.applyPayload(root._pendingForecastJson, meta)) {
                cache.setText(JSON.stringify(Object.assign({}, meta, { data: root._pendingForecastJson })));
                root.finishFetch(true, "");
                return;
            }
        }
        root.finishFetch(false, "Could not fetch forecast from Open-Meteo");
    }

    function finishFetch(ok: bool, errMsg: string) {
        root.stale = !ok;
        root.error = ok ? "" : errMsg;
        root.loading = false;
        if (root._pendingRefresh) {
            root._pendingRefresh = false;
            root.refresh();
        }
    }

    // ---- Geocoding search ----
    function searchLocations(query: string) {
        const q = (query || "").trim();
        if (q.length < 2) {
            root.searchResults = [];
            root.searchError = "";
            root.searching = false;
            root._queuedSearch = "";
            return;
        }
        if (searchProc.running) {
            root._queuedSearch = q;
            return;
        }
        root._queuedSearch = "";
        root._activeSearch = q;
        root.searching = true;
        root.searchError = "";
        const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(q)}&count=8&language=en&format=json`;
        searchProc.runCommand(["curl", "-sf", "-m", "10", url]);
    }

    function clearSearch() {
        root._queuedSearch = "";
        root._activeSearch = "";
        root.searchResults = [];
        root.searchError = "";
        root.searching = false;
    }

    Connections {
        target: WeatherConfig
        function onLocationConfigChanged() {
            root.refresh();
        }
        function onSourceConfigChanged() {
            if (root._lastForecastJson)
                root.applyPayload(root._lastForecastJson, root._lastForecastMeta);
            root.refresh();
        }
    }

    FileView {
        id: cache
        path: root.cacheFile
        atomicWrites: true
        printErrors: false
        onLoaded: root.parseCache(text())
    }

    // Synchronizes Process exit and StdioCollector stream completion so stdout is never read early.
    component HttpProcess: Process {
        id: hp
        property string outBuf: ""
        property int exitCode: -1
        property bool streamDone: false
        property bool procDone: false
        signal finished(int code, string output)

        function runCommand(cmd: var) {
            outBuf = "";
            exitCode = -1;
            streamDone = false;
            procDone = false;
            command = cmd;
            running = true;
        }

        function maybeFinish() {
            if (streamDone && procDone)
                finished(exitCode, outBuf);
        }

        stdout: StdioCollector {
            onStreamFinished: {
                hp.outBuf = text;
                hp.streamDone = true;
                hp.maybeFinish();
            }
        }
        onExited: code => {
            hp.exitCode = code;
            hp.procDone = true;
            hp.maybeFinish();
        }
    }

    HttpProcess {
        id: geoFetch
        onFinished: (code, output) => {
            if (code === 0 && output.trim() !== "") {
                try {
                    const g = JSON.parse(output);
                    const lat = Number(g.latitude ?? g.lat);
                    const lon = Number(g.longitude ?? g.lon);
                    if (!isNaN(lat) && !isNaN(lon) && g.success !== false && g.status !== "fail") {
                        const city = String(g.city || "");
                        const region = [g.region || g.regionName, g.country_code || g.countryCode].filter(Boolean).join(", ");
                        if (city !== "") root.detectedLocation = city;
                        root.detectedRegion = region;
                        root.startForecastFetch(lat, lon, city || "Auto-locate", region, true);
                        return;
                    }
                } catch (e) {
                    console.warn("Weather: could not parse geolocation response:", e);
                }
            }
            root.finishFetch(false, "Could not detect location via IP");
        }
    }

    HttpProcess {
        id: forecastFetch
        onFinished: (code, output) => {
            if (code === 0 && output.trim() !== "") {
                try {
                    const j = JSON.parse(output);
                    if (j && j.current && j.daily && Array.isArray(j.daily.time)) {
                        root._pendingForecastJson = j;
                        root._pendingForecastOk = true;
                    }
                } catch (e) {
                    console.warn("Weather: could not parse forecast response:", e);
                }
            }
            root._pendingForecastDone = true;
            root.maybeFinalizeFetch();
        }
    }

    HttpProcess {
        id: hungarometFetch
        onFinished: (code, output) => {
            if (code === 0 && output.trim() !== "") {
                try {
                    const obs = JSON.parse(output);
                    if (obs && obs.available === true)
                        root._pendingObs = obs;
                } catch (e) {
                    console.warn("Weather: could not parse HungaroMet output:", e);
                }
            }
            root._pendingObsDone = true;
            root.maybeFinalizeFetch();
        }
    }

    HttpProcess {
        id: searchProc
        onFinished: (code, output) => {
            if (root._queuedSearch !== "") {
                const nextQ = root._queuedSearch;
                root._queuedSearch = "";
                root.searching = false;
                root.searchLocations(nextQ);
                return;
            }
            root.searching = false;
            if (code !== 0 || output.trim() === "") {
                root.searchError = "Search failed — check network connection";
                root.searchResults = [];
                return;
            }
            try {
                const j = JSON.parse(output);
                const rawList = Array.isArray(j.results) ? j.results : [];
                root.searchResults = rawList.map(r => ({
                    name: String(r.name || ""),
                    region: [r.admin1, r.country].filter(Boolean).join(", "),
                    countryCode: String(r.country_code || ""),
                    lat: Number(r.latitude),
                    lon: Number(r.longitude)
                }));
                root.searchError = "";
            } catch (e) {
                root.searchError = "Could not parse search results";
                root.searchResults = [];
            }
        }
    }

    Timer {
        interval: Math.max(5, WeatherConfig.refreshMinutes) * 60 * 1000
        running: WeatherConfig.ready
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    signal openPageRequested(string screenName, string pageName)

    IpcHandler {
        target: "weather"
        function refresh(): void { root.refresh(); }
        function open(page: string): void {
            const scr = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
            root.openPageRequested(scr, page || "");
        }
    }
}
