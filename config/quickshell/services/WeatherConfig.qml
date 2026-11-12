pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Persistent configuration for the modular Weather widget:
// location, saved cities, units, refresh interval, bar modules, popup sections, and detail tiles.
// Stored in Quickshell's state dir (weather-config.json); Config.qml provides initial defaults.
Singleton {
    id: root

    property bool ready: false
    readonly property string stateFile: Quickshell.statePath("weather-config.json")

    signal locationConfigChanged()

    // ---- Location ----
    property bool autoLocate: Config.weatherAutoLocate
    property string locationName: Config.weatherLocation
    property string locationRegion: ""
    property real latitude: Config.weatherLat
    property real longitude: Config.weatherLon
    property var savedLocations: defaultSavedLocations()

    // ---- Units & Refresh ----
    property string tempUnit: "C"          // "C" | "F"
    property string windUnit: "kmh"        // "kmh" | "ms" | "mph" | "kn"
    property string precipUnit: "mm"       // "mm" | "in"
    property string pressureUnit: "hPa"    // "hPa" | "inHg" | "mmHg"
    property string visibilityUnit: "km"   // "km" | "mi"
    property string timeFormat: "24h"      // "24h" | "12h"
    property int refreshMinutes: Config.weatherRefreshMinutes

    // ---- Bar appearance ----
    property bool barShowUnit: true
    property bool barFilledIcon: true

    // ---- Popup options ----
    property int hourlyHours: 12           // 12 | 24
    property int forecastDays: 5           // 3 | 5 | 7 | 10
    property int detailColumns: 3          // 2 | 3

    readonly property var defaultBarItems: [
        { id: "icon",      name: "Condition Icon", subtitle: "Weather symbol for current conditions", icon: "partly_cloudy_day",   enabled: true },
        { id: "temp",      name: "Temperature",    subtitle: "Current temperature",                   icon: "device_thermostat",   enabled: true },
        { id: "condition", name: "Condition Text", subtitle: "Short text (e.g. Clear, Rain)",         icon: "cloud",               enabled: false },
        { id: "feelsLike", name: "Feels Like",     subtitle: "Apparent temperature",                  icon: "thermostat",          enabled: false },
        { id: "rain",      name: "Rain Chance",    subtitle: "Today's precipitation probability",     icon: "water_drop",          enabled: false },
        { id: "wind",      name: "Wind Speed",     subtitle: "Current wind speed",                    icon: "air",                 enabled: false },
        { id: "humidity",  name: "Humidity",       subtitle: "Relative humidity percentage",          icon: "humidity_percentage", enabled: false },
        { id: "highLow",   name: "High / Low",     subtitle: "Today's max and min temperature",       icon: "swap_vert",           enabled: false },
        { id: "location",  name: "Location",       subtitle: "Active city or location name",          icon: "location_on",         enabled: false }
    ]

    readonly property var defaultPopupSections: [
        { id: "hero",    name: "Current Summary", subtitle: "Big icon, temperature, feels like & high/low", icon: "partly_cloudy_day", enabled: true },
        { id: "hourly",  name: "Hourly Forecast", subtitle: "Scrollable temperature & rain timeline",       icon: "schedule",          enabled: true },
        { id: "details", name: "Detail Tiles",    subtitle: "Modular grid of current weather metrics",      icon: "grid_view",         enabled: true },
        { id: "daily",   name: "Daily Forecast",  subtitle: "Multi-day outlook with rain & high/low",       icon: "calendar_today",    enabled: true },
        { id: "footer",  name: "Status Footer",   subtitle: "Last updated time, source & status",           icon: "info",              enabled: true }
    ]

    readonly property var defaultDetailTiles: [
        { id: "rain",       name: "Rain",        subtitle: "Probability & today's total",   icon: "rainy",               enabled: true },
        { id: "humidity",   name: "Humidity",    subtitle: "Relative humidity",             icon: "humidity_percentage", enabled: true },
        { id: "wind",       name: "Wind",        subtitle: "Speed, direction & gusts",      icon: "air",                 enabled: true },
        { id: "uv",         name: "UV Index",    subtitle: "Today's peak UV rating",        icon: "light_mode",          enabled: true },
        { id: "pressure",   name: "Pressure",    subtitle: "Mean sea-level pressure",       icon: "compress",            enabled: true },
        { id: "sun",        name: "Sun",         subtitle: "Sunrise & sunset times",        icon: "wb_twilight",         enabled: true },
        { id: "feelsLike",  name: "Feels Like",  subtitle: "Apparent temperature",          icon: "thermostat",          enabled: false },
        { id: "cloudCover", name: "Cloud Cover", subtitle: "Current sky cloudiness %",      icon: "cloud",               enabled: false },
        { id: "visibility", name: "Visibility",  subtitle: "Atmospheric visibility range",  icon: "visibility",          enabled: false },
        { id: "dewPoint",   name: "Dew Point",   subtitle: "Condensation temperature",      icon: "dew_point",           enabled: false }
    ]

    property var barItems: cloneList(defaultBarItems)
    property var popupSections: cloneList(defaultPopupSections)
    property var detailTiles: cloneList(defaultDetailTiles)

    readonly property var enabledBarItems: barItems.filter(i => i.enabled)
    readonly property var enabledPopupSections: popupSections.filter(i => i.enabled)
    readonly property var enabledDetailTiles: detailTiles.filter(i => i.enabled)

    function defaultSavedLocations(): var {
        return [{
            name: Config.weatherLocation,
            region: "",
            lat: Config.weatherLat,
            lon: Config.weatherLon
        }];
    }

    function cloneList(arr: var): var {
        return arr.map(i => Object.assign({}, i));
    }

    function mergeList(saved: var, defaults: var): var {
        if (!Array.isArray(saved)) return cloneList(defaults);
        const byId = {};
        for (const d of defaults) byId[d.id] = d;
        const seen = {};
        const merged = [];
        for (const s of saved) {
            if (!s || !byId[s.id] || seen[s.id]) continue;
            seen[s.id] = true;
            merged.push(Object.assign({}, byId[s.id], {
                enabled: s.enabled !== undefined ? Boolean(s.enabled) : byId[s.id].enabled
            }));
        }
        for (const d of defaults) {
            if (!seen[d.id]) merged.push(Object.assign({}, d));
        }
        return merged;
    }

    function listFor(kind: string): var {
        if (kind === "bar") return root.barItems;
        if (kind === "sections") return root.popupSections;
        if (kind === "tiles") return root.detailTiles;
        return [];
    }

    function setListFor(kind: string, next: var) {
        if (kind === "bar") root.barItems = next;
        else if (kind === "sections") root.popupSections = next;
        else if (kind === "tiles") root.detailTiles = next;
        save();
    }

    function toggleListItem(kind: string, id: string) {
        const next = listFor(kind).map(i => i.id === id ? Object.assign({}, i, { enabled: !i.enabled }) : i);
        setListFor(kind, next);
    }

    function moveListItem(kind: string, id: string, delta: int) {
        const list = listFor(kind).slice();
        const idx = list.findIndex(i => i.id === id);
        const target = idx + delta;
        if (idx < 0 || target < 0 || target >= list.length) return;
        const tmp = list[idx];
        list[idx] = list[target];
        list[target] = tmp;
        setListFor(kind, list);
    }

    function applyBarPreset(preset: string) {
        const activeIds = preset === "icon" ? ["icon"]
                        : preset === "temp" ? ["temp"]
                        : preset === "compact" ? ["icon", "temp", "rain"]
                        : preset === "detailed" ? ["location", "icon", "temp", "condition", "rain", "wind"]
                        : ["icon", "temp"];
        const ordered = [];
        const byId = {};
        for (const d of root.defaultBarItems) byId[d.id] = d;
        for (const id of activeIds) {
            if (byId[id]) ordered.push(Object.assign({}, byId[id], { enabled: true }));
        }
        for (const item of root.barItems) {
            if (activeIds.indexOf(item.id) < 0)
                ordered.push(Object.assign({}, item, { enabled: false }));
        }
        root.barItems = ordered;
        save();
    }

    function setBarShowUnit(v: bool) { root.barShowUnit = v; save(); }
    function setBarFilledIcon(v: bool) { root.barFilledIcon = v; save(); }

    function setHourlyHours(h: int) { root.hourlyHours = h; save(); }
    function setForecastDays(d: int) { root.forecastDays = d; save(); }
    function setDetailColumns(c: int) { root.detailColumns = c; save(); }

    function setTempUnit(u: string) { root.tempUnit = u; save(); }
    function setWindUnit(u: string) { root.windUnit = u; save(); }
    function setPrecipUnit(u: string) { root.precipUnit = u; save(); }
    function setPressureUnit(u: string) { root.pressureUnit = u; save(); }
    function setVisibilityUnit(u: string) { root.visibilityUnit = u; save(); }
    function setTimeFormat(f: string) { root.timeFormat = f; save(); }
    function setRefreshMinutes(m: int) { root.refreshMinutes = Math.max(5, m); save(); }

    function applyUnitSystem(sys: string) {
        if (sys === "imperial") {
            root.tempUnit = "F";
            root.windUnit = "mph";
            root.precipUnit = "in";
            root.pressureUnit = "inHg";
            root.visibilityUnit = "mi";
        } else {
            root.tempUnit = "C";
            root.windUnit = "kmh";
            root.precipUnit = "mm";
            root.pressureUnit = "hPa";
            root.visibilityUnit = "km";
        }
        save();
    }

    function coordsMatch(aLat: real, aLon: real, bLat: real, bLon: real): bool {
        return Math.abs(aLat - bLat) < 0.005 && Math.abs(aLon - bLon) < 0.005;
    }

    function isLocationSaved(lat: real, lon: real): bool {
        return root.savedLocations.some(loc => coordsMatch(loc.lat, loc.lon, lat, lon));
    }

    function setLocation(name: string, region: string, lat: real, lon: real) {
        const cleanName = (name || "").trim() || `${lat.toFixed(2)}, ${lon.toFixed(2)}`;
        const changed = root.autoLocate
            || !coordsMatch(root.latitude, root.longitude, lat, lon)
            || root.locationName !== cleanName;
        root.autoLocate = false;
        root.locationName = cleanName;
        root.locationRegion = (region || "").trim();
        root.latitude = lat;
        root.longitude = lon;
        save();
        if (changed) root.locationConfigChanged();
    }

    function setAutoLocate(on: bool) {
        if (root.autoLocate === on) return;
        root.autoLocate = on;
        save();
        root.locationConfigChanged();
    }

    function saveLocation(name: string, region: string, lat: real, lon: real) {
        if (isLocationSaved(lat, lon)) return;
        const entry = {
            name: (name || "").trim() || `${lat.toFixed(2)}, ${lon.toFixed(2)}`,
            region: (region || "").trim(),
            lat: Number(lat),
            lon: Number(lon)
        };
        root.savedLocations = root.savedLocations.concat([entry]);
        save();
    }

    function removeSavedLocation(index: int) {
        if (index < 0 || index >= root.savedLocations.length) return;
        const next = root.savedLocations.slice();
        next.splice(index, 1);
        root.savedLocations = next;
        save();
    }

    function reset() {
        const locChanged = root.autoLocate !== Config.weatherAutoLocate
            || !coordsMatch(root.latitude, root.longitude, Config.weatherLat, Config.weatherLon)
            || root.locationName !== Config.weatherLocation;
        root.autoLocate = Config.weatherAutoLocate;
        root.locationName = Config.weatherLocation;
        root.locationRegion = "";
        root.latitude = Config.weatherLat;
        root.longitude = Config.weatherLon;
        root.savedLocations = defaultSavedLocations();
        root.tempUnit = "C";
        root.windUnit = "kmh";
        root.precipUnit = "mm";
        root.pressureUnit = "hPa";
        root.visibilityUnit = "km";
        root.timeFormat = "24h";
        root.refreshMinutes = Config.weatherRefreshMinutes;
        root.barShowUnit = true;
        root.barFilledIcon = true;
        root.hourlyHours = 12;
        root.forecastDays = 5;
        root.detailColumns = 3;
        root.barItems = cloneList(defaultBarItems);
        root.popupSections = cloneList(defaultPopupSections);
        root.detailTiles = cloneList(defaultDetailTiles);
        save();
        if (locChanged) root.locationConfigChanged();
    }

    function save() {
        const payload = {
            autoLocate: root.autoLocate,
            locationName: root.locationName,
            locationRegion: root.locationRegion,
            latitude: root.latitude,
            longitude: root.longitude,
            savedLocations: root.savedLocations,
            tempUnit: root.tempUnit,
            windUnit: root.windUnit,
            precipUnit: root.precipUnit,
            pressureUnit: root.pressureUnit,
            visibilityUnit: root.visibilityUnit,
            timeFormat: root.timeFormat,
            refreshMinutes: root.refreshMinutes,
            barShowUnit: root.barShowUnit,
            barFilledIcon: root.barFilledIcon,
            hourlyHours: root.hourlyHours,
            forecastDays: root.forecastDays,
            detailColumns: root.detailColumns,
            barItems: root.barItems.map(i => ({ id: i.id, enabled: i.enabled })),
            popupSections: root.popupSections.map(i => ({ id: i.id, enabled: i.enabled })),
            detailTiles: root.detailTiles.map(i => ({ id: i.id, enabled: i.enabled }))
        };
        store.setText(JSON.stringify(payload, null, 2));
    }

    function loadJson(raw: string) {
        try {
            const d = JSON.parse(raw);
            if (!d || typeof d !== "object") return;
            if (typeof d.autoLocate === "boolean") root.autoLocate = d.autoLocate;
            if (typeof d.locationName === "string" && d.locationName.trim() !== "") root.locationName = d.locationName;
            if (typeof d.locationRegion === "string") root.locationRegion = d.locationRegion;
            if (typeof d.latitude === "number" && !isNaN(d.latitude)) root.latitude = d.latitude;
            if (typeof d.longitude === "number" && !isNaN(d.longitude)) root.longitude = d.longitude;
            if (Array.isArray(d.savedLocations)) {
                root.savedLocations = d.savedLocations.filter(l =>
                    l && typeof l.name === "string" && typeof l.lat === "number" && typeof l.lon === "number");
            }
            if (d.tempUnit === "C" || d.tempUnit === "F") root.tempUnit = d.tempUnit;
            if (["kmh", "ms", "mph", "kn"].indexOf(d.windUnit) >= 0) root.windUnit = d.windUnit;
            if (d.precipUnit === "mm" || d.precipUnit === "in") root.precipUnit = d.precipUnit;
            if (["hPa", "inHg", "mmHg"].indexOf(d.pressureUnit) >= 0) root.pressureUnit = d.pressureUnit;
            if (d.visibilityUnit === "km" || d.visibilityUnit === "mi") root.visibilityUnit = d.visibilityUnit;
            if (d.timeFormat === "24h" || d.timeFormat === "12h") root.timeFormat = d.timeFormat;
            if (typeof d.refreshMinutes === "number" && d.refreshMinutes >= 5) root.refreshMinutes = d.refreshMinutes;
            if (typeof d.barShowUnit === "boolean") root.barShowUnit = d.barShowUnit;
            if (typeof d.barFilledIcon === "boolean") root.barFilledIcon = d.barFilledIcon;
            if (d.hourlyHours === 12 || d.hourlyHours === 24) root.hourlyHours = d.hourlyHours;
            if ([3, 5, 7, 10].indexOf(d.forecastDays) >= 0) root.forecastDays = d.forecastDays;
            if (d.detailColumns === 2 || d.detailColumns === 3) root.detailColumns = d.detailColumns;
            root.barItems = mergeList(d.barItems, root.defaultBarItems);
            root.popupSections = mergeList(d.popupSections, root.defaultPopupSections);
            root.detailTiles = mergeList(d.detailTiles, root.defaultDetailTiles);
        } catch (e) {
            console.warn("WeatherConfig: could not parse config:", e);
        }
    }

    Process {
        running: true
        command: ["mkdir", "-p", Quickshell.stateDir, Quickshell.cacheDir]
    }

    FileView {
        id: store
        path: root.stateFile
        atomicWrites: true
        printErrors: false
        onLoaded: {
            root.loadJson(text());
            root.ready = true;
        }
        onLoadFailed: root.ready = true
    }
}
