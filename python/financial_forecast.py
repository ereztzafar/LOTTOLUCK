# -*- coding: utf-8 -*-
import sys
import json
import argparse
from datetime import datetime, timedelta
from flatlib.chart import Chart
from flatlib.datetime import Datetime
from flatlib.geopos import GeoPos
from flatlib import const, angle

# ========================
# Helpers
# ========================

def dec_to_flatlib_str(value, is_lat=True):
    """
    Convert decimal degrees to flatlib GeoPos string.
    Example: 32.083 -> '32n05', 34.883 -> '34e53'
    """
    sign = 'n' if (value >= 0 and is_lat) else 's' if is_lat else ('e' if value >= 0 else 'w')
    v = abs(value)
    deg = int(v)
    minutes = int(round((v - deg) * 60))
    return f"{deg}{sign}{minutes:02d}"

def build_geopos(lat_dec, lon_dec):
    lat_s = dec_to_flatlib_str(lat_dec, is_lat=True)
    lon_s = dec_to_flatlib_str(lon_dec, is_lat=False)
    return GeoPos(lat_s, lon_s)

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

# ========================
# Astro Config
# ========================

PLANETS = [
    const.SUN, const.MOON, const.MERCURY, const.VENUS, const.MARS,
    const.JUPITER, const.SATURN, const.URANUS, const.NEPTUNE, const.PLUTO
]

MONEY_OBJECTS = [const.VENUS, const.JUPITER, const.MOON, const.PLUTO, 'FORTUNE']
HARMONIC_ANGLES = [0, 60, 120, 180]
ORB_DEG = 3  # אורב לאספקט

PLANET_ICONS = {
    const.SUN: "☀️", const.MOON: "🌙", const.MERCURY: "☿", const.VENUS: "♀",
    const.MARS: "♂", const.JUPITER: "♃", const.SATURN: "♄", const.URANUS: "♅",
    const.NEPTUNE: "♆", const.PLUTO: "♇", 'FORTUNE': "🎯"
}

ANGLE_MEANINGS = {
    0: "צמידות חדה",
    60: "הזדמנות שקטה",
    120: "זרימה כספית",
    180: "הפתעה פתאומית"
}

# שעות בדיקה ביום (חלונות כל 3 שעות כברירת מחדל)
DEFAULT_START_HOUR = 5
DEFAULT_END_HOUR = 23
DEFAULT_INTERVAL = 3

# ========================
# Core astro funcs
# ========================

def create_chart(date_str, time_str, tz_offset, geopos):
    dt = Datetime(date_str, time_str, tz_offset)
    return Chart(dt, geopos, IDs=PLANETS)

def calc_angle(pos1, pos2):
    diff = abs(pos1 - pos2) % 360
    return min(diff, 360 - diff)

def calculate_part_of_fortune(chart):
    asc = chart.get(const.ASC).lon
    moon = chart.get(const.MOON).lon
    sun = chart.get(const.SUN).lon
    return angle.norm(asc + moon - sun)

def estimate_potential_text(n):
    if n >= 9:
        return "🟢🟢 95–100%"
    elif n >= 7:
        return "🟢 85–94%"
    elif n >= 5:
        return "🟢 70–84%"
    elif n >= 3:
        return "🟡 50–69%"
    elif n >= 1:
        return "🔘 30–49%"
    else:
        return "⬜ 0%"

def find_lucky_blocks_for_day(
    date_obj, tz_offset, geopos,
    birth_chart, fortune_birth,
    start_hour=DEFAULT_START_HOUR,
    end_hour=DEFAULT_END_HOUR,
    interval_hours=DEFAULT_INTERVAL
):
    date_str = date_obj.strftime('%Y/%m/%d')
    blocks = []

    for hour in range(start_hour, end_hour + 1, interval_hours):
        time_str = f"{hour:02d}:00"
        transit_chart = create_chart(date_str, time_str, tz_offset, geopos)
        fortune_now = calculate_part_of_fortune(transit_chart)

        found_aspects = []
        # בדיקת זוויות הרמוניות בין MONEY_OBJECTS של לידה ↔ טרנזיט
        for p1 in MONEY_OBJECTS:
            pos1 = birth_chart.get(p1).lon if p1 != 'FORTUNE' else fortune_birth
            for p2 in MONEY_OBJECTS:
                pos2 = transit_chart.get(p2).lon if p2 != 'FORTUNE' else fortune_now
                ang_val = calc_angle(pos1, pos2)
                for h_angle in HARMONIC_ANGLES:
                    if abs(ang_val - h_angle) <= ORB_DEG:
                        icon1 = PLANET_ICONS.get(p1, p1)
                        icon2 = PLANET_ICONS.get(p2, p2)
                        meaning = ANGLE_MEANINGS.get(h_angle, "")
                        found_aspects.append(f"{icon1} {p1} ↔ {icon2} {p2} — {h_angle}° {meaning}")

        if found_aspects:
            blocks.append({
                "time": time_str,
                "aspects": found_aspects,
                "score_text": estimate_potential_text(len(found_aspects)),
                "score_est": clamp(50 + len(found_aspects) * 6, 0, 100)  # ניקוד גס 0..100
            })

    return blocks

def list_retrograde_planets(date_obj, tz_offset, geopos):
    """בדיקת כוכבים בנסיגה בצהרי היום."""
    date_str = date_obj.strftime('%Y/%m/%d')
    chart = create_chart(date_str, '12:00', tz_offset, geopos)
    retros = []
    for p in PLANETS:
        if chart.get(p).isRetrograde():
            retros.append({"name": p, "icon": PLANET_ICONS.get(p, "")})
    return retros

# ========================
# Public API
# ========================

def build_forecast_json(
    birth_date, birth_time, tz_offset, lat_dec, lon_dec,
    days=3, start_hour=DEFAULT_START_HOUR, end_hour=DEFAULT_END_HOUR, interval_hours=DEFAULT_INTERVAL,
    start_date=None
):
    """
    מחזיר dict שניתן להדפיס כ-JSON.
    - birth_date: 'YYYY/MM/DD'
    - birth_time: 'HH:MM'
    - tz_offset:  '+02:00' (מחרוזת)
    - lat_dec/lon_dec: float (Decimal Degrees)
    - days: number of forecast days (default 3)
    - start_date: 'YYYY/MM/DD' (אם None – היום במערכת)
    """
    geopos = build_geopos(lat_dec, lon_dec)

    # מפת לידה פעם אחת
    birth_chart = create_chart(birth_date, birth_time, tz_offset, geopos)
    fortune_birth = calculate_part_of_fortune(birth_chart)

    # תאריך התחלה
    if start_date:
        base = datetime.strptime(start_date, '%Y/%m/%d')
    else:
        # "היום" לפי שעון מערכת – Flatlib ישתמש ב-tz_offset עצמו
        base = datetime.utcnow()

    days_out = []
    for i in range(days):
        day = base + timedelta(days=i)
        date_str = day.strftime('%Y/%m/%d')

        retro = list_retrograde_planets(day, tz_offset, geopos)
        blocks = find_lucky_blocks_for_day(
            day, tz_offset, geopos, birth_chart, fortune_birth,
            start_hour=start_hour, end_hour=end_hour, interval_hours=interval_hours
        )

        best_time = None
        if blocks:
            best_time = max(blocks, key=lambda b: b.get("score_est", 0))["time"]

        days_out.append({
            "date": date_str,
            "retro": retro,                # [{name, icon}]
            "windows": blocks,             # [{time, aspects[], score_text, score_est}]
            "recommendation": (
                f"🟢 מומלץ למלא סביב {best_time}" if best_time else "אין המלצה ליום זה"
            )
        })

    return {
        "meta": {
            "version": "1.0",
            "tz_offset": tz_offset,
            "lat": lat_dec,
            "lon": lon_dec,
            "orb_deg": ORB_DEG,
            "angles": HARMONIC_ANGLES
        },
        "natal": {
            "birth_date": birth_date,
            "birth_time": birth_time
        },
        "days": days_out
    }

# ========================
# CLI
# ========================

def main():
    parser = argparse.ArgumentParser(
        description="Financial lucky windows forecast (JSON output)"
    )
    parser.add_argument("--birth-date", required=True, help="YYYY/MM/DD")
    parser.add_argument("--birth-time", required=True, help="HH:MM (24h)")
    parser.add_argument("--tz", required=True, help="+02:00 / -05:00 ... (Flatlib offset)")
    parser.add_argument("--lat", required=True, type=float, help="Latitude decimal degrees")
    parser.add_argument("--lon", required=True, type=float, help="Longitude decimal degrees")
    parser.add_argument("--days", type=int, default=3, help="How many days ahead")
    parser.add_argument("--start-date", default=None, help="Start date YYYY/MM/DD (optional)")
    parser.add_argument("--start-hour", type=int, default=DEFAULT_START_HOUR)
    parser.add_argument("--end-hour", type=int, default=DEFAULT_END_HOUR)
    parser.add_argument("--interval", type=int, default=DEFAULT_INTERVAL)

    args = parser.parse_args()

    data = build_forecast_json(
        birth_date=args.birth_date,
        birth_time=args.birth_time,
        tz_offset=args.tz,
        lat_dec=args.lat,
        lon_dec=args.lon,
        days=args.days,
        start_hour=args.start_hour,
        end_hour=args.end_hour,
        interval_hours=args.interval,
        start_date=args.start_date
    )
    print(json.dumps(data, ensure_ascii=False))

if __name__ == "__main__":
    main()
