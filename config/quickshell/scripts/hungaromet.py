#!/usr/bin/env python3
"""
Fetch live 10-minute SYNOP station observations from HungaroMet Open Data (odp.met.hu)
and return the nearest Hungarian weather measurements within range as JSON.
Usage: hungaromet.py <lat> <lon> [max_km]
"""
from datetime import datetime, timezone
import io
import json
import math
import sys
import urllib.request
import zipfile

ODP_10M_URL = "https://odp.met.hu/weather/weather_reports/synoptic/hungary/10_minutes/csv/HABP_10M_SYNOP_LATEST.csv.zip"


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    )
    return 2.0 * 6371.0 * math.asin(math.sqrt(min(1.0, a)))


def parse_num(raw: str | None):
    if raw is None:
        return None
    s = raw.strip()
    if not s:
        return None
    try:
        v = float(s)
    except ValueError:
        return None
    return None if v <= -900 else v


def parse_time(ts: str) -> datetime | None:
    s = ts.strip()
    if len(s) != 12 or not s.isdigit():
        return None
    try:
        return datetime.strptime(s, "%Y%m%d%H%M").replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def mslp_hpa(p_station: float, elev_m: float, temp_c: float) -> float:
    denom = temp_c + 273.15 + 0.0065 * elev_m
    if denom <= 0 or elev_m < -50 or elev_m > 3000:
        return p_station
    factor = 1.0 - (0.0065 * elev_m) / denom
    if factor <= 0:
        return p_station
    return p_station * (factor ** -5.257)


def fail(reason: str) -> None:
    print(json.dumps({"available": False, "reason": reason}))
    sys.exit(0)


def main() -> None:
    if len(sys.argv) < 3:
        fail("missing_args")
    try:
        target_lat = float(sys.argv[1])
        target_lon = float(sys.argv[2])
        max_km = float(sys.argv[3]) if len(sys.argv) >= 4 else 50.0
    except ValueError:
        fail("invalid_args")

    # Quick bounding-box check around Hungary before hitting odp.met.hu.
    if not (45.2 <= target_lat <= 49.1 and 15.5 <= target_lon <= 23.5):
        fail("outside_hungary")

    try:
        req = urllib.request.Request(ODP_10M_URL, headers={"User-Agent": "quickshell-weather/1.0"})
        with urllib.request.urlopen(req, timeout=8) as resp:
            raw_zip = resp.read()
    except Exception as exc:
        fail(f"fetch_error:{exc}")

    try:
        with zipfile.ZipFile(io.BytesIO(raw_zip)) as zf:
            names = [n for n in zf.namelist() if n.endswith(".csv")]
            if not names:
                fail("empty_zip")
            text = zf.read(names[0]).decode("utf-8", errors="replace")
    except Exception as exc:
        fail(f"zip_error:{exc}")

    lines = text.splitlines()
    if len(lines) < 2:
        fail("empty_csv")

    hdr = [c.strip() for c in lines[0].split(";")]
    idx = {name: i for i, name in enumerate(hdr)}
    for req_col in ("Time", "StationNumber", "StationName", "Latitude", "Longitude", "Elevation", "t"):
        if req_col not in idx:
            fail("bad_schema")

    def col(row: list[str], name: str) -> str | None:
        pos = idx.get(name)
        return row[pos] if pos is not None and pos < len(row) else None

    latest_by_station: dict[str, dict] = {}
    newest_time: datetime | None = None

    for line in lines[1:]:
        if not line.strip():
            continue
        row = [c.strip() for c in line.split(";")]
        dt = parse_time(col(row, "Time") or "")
        st_id = (col(row, "StationNumber") or "").strip()
        lat = parse_num(col(row, "Latitude"))
        lon = parse_num(col(row, "Longitude"))
        if dt is None or not st_id or lat is None or lon is None:
            continue

        if newest_time is None or dt > newest_time:
            newest_time = dt

        prev = latest_by_station.get(st_id)
        if prev is not None and prev["dt"] >= dt:
            continue

        latest_by_station[st_id] = {
            "dt": dt,
            "id": st_id,
            "name": (col(row, "StationName") or "").strip(),
            "lat": lat,
            "lon": lon,
            "elev": parse_num(col(row, "Elevation")) or 0.0,
            "t": parse_num(col(row, "t")),
            "u": parse_num(col(row, "u")),
            "r": parse_num(col(row, "r")),
            "v": parse_num(col(row, "v")),
            "p": parse_num(col(row, "p")),
            "fs": parse_num(col(row, "fs")),
            "fsd": parse_num(col(row, "fsd")),
            "fx": parse_num(col(row, "fx")),
        }

    if not latest_by_station or newest_time is None:
        fail("no_stations")

    nearby: list[dict] = []
    for st in latest_by_station.values():
        # Skip stale/offline stations older than 2 hours behind latest snapshot.
        if (newest_time - st["dt"]).total_seconds() > 7200:
            continue
        dist = haversine_km(target_lat, target_lon, st["lat"], st["lon"])
        if dist <= max_km:
            st["dist"] = dist
            nearby.append(st)

    nearby.sort(key=lambda s: s["dist"])
    primary = next((s for s in nearby if s["t"] is not None), None)
    if primary is None:
        fail("no_nearby_station")

    def nearest_with(field: str, limit_km: float):
        return next((s for s in nearby if s["dist"] <= limit_km and s[field] is not None), None)

    u_st = primary if primary["u"] is not None else nearest_with("u", 35.0)
    w_st = primary if primary["fs"] is not None else nearest_with("fs", 35.0)
    v_st = primary if primary["v"] is not None else nearest_with("v", max_km)
    p_st = primary if (primary["p"] is not None and primary["t"] is not None) else next(
        (s for s in nearby if s["p"] is not None and s["t"] is not None), None
    )

    wind_kmh = round(w_st["fs"] * 3.6, 1) if w_st is not None else None
    gusts_kmh = round(w_st["fx"] * 3.6, 1) if (w_st is not None and w_st["fx"] is not None) else None
    wind_dir = round(w_st["fsd"]) if (w_st is not None and w_st["fsd"] is not None) else None
    mslp = (
        round(mslp_hpa(p_st["p"], p_st["elev"], p_st["t"]), 1)
        if p_st is not None
        else None
    )

    out = {
        "available": True,
        "stationNumber": primary["id"],
        "stationName": primary["name"] or primary["id"],
        "distanceKm": round(primary["dist"], 1),
        "obsTimeIso": primary["dt"].strftime("%Y-%m-%dT%H:%MZ"),
        "tempC": round(primary["t"], 1),
        "humidity": round(u_st["u"]) if u_st is not None else None,
        "windKmh": wind_kmh,
        "gustsKmh": gusts_kmh,
        "windDir": wind_dir,
        "pressureHpa": mslp,
        "visibilityM": round(v_st["v"]) if v_st is not None else None,
        "precip10mMm": round(primary["r"], 1) if primary["r"] is not None else None,
    }
    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
