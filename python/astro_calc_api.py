# -*- coding: utf-8 -*-
"""
astro_calc_api.py
API קטן לחישובים אסטרולוגיים עבור האפליקציה:
- ללא טלגרם
- קולט פרמטרים מהשורה (או מהאפליקציה)
- מדפיס JSON ב-UTF-8 ל-stdout
"""

import sys
import json
import argparse
from datetime import datetime, timedelta

from flatlib.chart import Chart
from flatlib.datetime import Datetime
from flatlib.geopos import GeoPos
from flatlib import const, angle

# ========= הגדרות ברירת מחדל =========
PLANETS = [
    const.SUN, const.MOON, const.MERCURY, const.VENUS, const.MARS,
    const.JUPITER, const.SATURN, const.URANUS, const.NEPTUNE, const.PLUTO
]
ALL_OBJECTS = PLANETS + ['FORTUNE']

# קבוצת "כסף" (כמו שהשתמשנו עד עכשיו)
MONEY_GROUP = [const.VENUS, const.JUPITER, const.MOON, const.PLUTO, 'FORTUNE', const.URANUS]

HARMONIC_ANGLES = [0, 60, 120, 180]  # צמידות, סקסטיל, טריין, אופוזיציה
ORBS_DEG = 3.0
START_HOUR = 5
END_HOUR   = 23
INTERVAL_H = 3

# ניקוד משוקלל (כמו בקוד הפייתון שלך)
BENEFICS = {const.VENUS, const.JUPITER, 'FORTUNE'}
MAX_URANUS_PER_BLOCK = 3  # תקרת תרומת אוראנוס לכל חלון של 3 שעות

# סמלים
PLANET_ICONS = {
    const.SUN: "☀️", const.MOON: "🌙", const.MERCURY: "☿", const.VENUS: "♀",
    const.MARS: "♂", const.JUPITER: "♃", const.SATURN: "♄", const.URANUS: "♅",
    const.NEPTUNE: "♆", const.PLUTO: "♇", 'FORTUNE': "🎯"
}
ANGLE_MEANINGS_HE = {0: "צמידות", 60: "שישית", 120: "משולש", 180: "ניגוד"}
ANGLE_MEANINGS_EN = {0: "Conjunction", 60: "Sextile", 120: "Trine", 180: "Opposition"}

# ========= עזרים =========
def stdout_utf8():
    try:
        sys.stdout.reconfigure(encoding='utf-8')  # Py3.7+
    except Exception:
        pass

def to_float(s, fallback=0.0):
    try: return float(s)
    except Exception: return fallback

def cyc_dist(a, b):
    d = abs(a - b) % 360.0
    return d if d <= 180.0 else 360.0 - d

def deg_to_sign_str(deg, lang='he'):
    signs_he = ["טלה", "שור", "תאומים", "סרטן", "אריה", "בתולה",
                "מאזניים", "עקרב", "קשת", "גדי", "דלי", "דגים"]
    signs_en = ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
                "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"]
    signs = signs_he if lang == 'he' else signs_en
    d = deg % 360.0
    sign_idx = int(d // 30)
    sign_deg = int(d % 30)
    return f"{signs[sign_idx]} {sign_deg}°"

def calc_part_of_fortune(chart):
    asc = chart.get(const.ASC).lon
    moon = chart.get(const.MOON).lon
    sun  = chart.get(const.SUN).lon
    return angle.norm(asc + moon - sun)

def _flatlib_coord_from_decimal(val: float, is_lat: bool) -> str:
    hemi = ('n' if is_lat else 'e') if val >= 0 else ('s' if is_lat else 'w')
    v = abs(float(val))
    d = int(v)
    m = int(round((v - d) * 60))
    if m == 60:
        d += 1; m = 0
    return f"{d}{hemi}{m}"

def _parse_geo_component(s: str, is_lat: bool) -> str:
    s_clean = s.strip().lower()
    if any(ch in s_clean for ch in ('n', 's', 'e', 'w')):
        return s_clean
    val = to_float(s_clean, 0.0)
    return _flatlib_coord_from_decimal(val, is_lat)

def build_chart(date_str, time_str, tz, lat, lon):
    dt = Datetime(date_str, time_str, tz)
    lat_fmt = _parse_geo_component(str(lat), is_lat=True)
    lon_fmt = _parse_geo_component(str(lon), is_lat=False)
    pos = GeoPos(lat_fmt, lon_fmt)
    return Chart(dt, pos, IDs=PLANETS)

def estimate_potential_score(n):
    if n >= 9: return "🟢🟢 95–100%"
    elif n >= 7: return "🟢 85–94%"
    elif n >= 5: return "🟢 70–84%"
    elif n >= 3: return "🟡 50–69%"
    elif n >= 1: return "🔘 30–49%"
    else: return "⬜ 0%"

# ========= ניקוד משוקלל (מספרי) =========
def _aspect_weight(p1, p2, h_angle):
    involves_uranus = (p1 == const.URANUS or p2 == const.URANUS)
    benefic_involved = (p1 in BENEFICS or p2 in BENEFICS)
    # אוראנוס: רק 120°
    if involves_uranus:
        return 2.0 if h_angle == 120 else 0.0
    if h_angle == 120:
        return 2.0 if benefic_involved else 1.5
    if h_angle == 60:
        return 1.0 if benefic_involved else 0.5
    if h_angle in (0, 180):
        return 0.5 if benefic_involved else 0.0
    return 0.0

def _score_block_numeric(natal_chart, transit_chart, target_objects, orb_deg=ORBS_DEG):
    natal_fortune   = calc_part_of_fortune(natal_chart)
    transit_fortune = calc_part_of_fortune(transit_chart)

    def get_lon(chart, p):
        return chart.get(p).lon if p != 'FORTUNE' else (natal_fortune if chart is natal_chart else transit_fortune)

    score_sum = 0.0
    uranus_used = 0
    for p1 in target_objects:
        pos1 = get_lon(natal_chart, p1)
        for p2 in target_objects:
            pos2 = get_lon(transit_chart, p2)
            d = cyc_dist(pos1, pos2)
            for a in HARMONIC_ANGLES:
                if abs(d - a) <= orb_deg:
                    w = _aspect_weight(p1, p2, a)
                    if w > 0:
                        if (p1 == const.URANUS or p2 == const.URANUS):
                            if uranus_used < MAX_URANUS_PER_BLOCK:
                                score_sum += w
                                uranus_used += 1
                        else:
                            score_sum += w
                    break
    return round(score_sum, 2)

# ========= חישובים =========
def planets_dict(chart, lang='he'):
    out, raw, retro = {}, {}, {}
    for pid in PLANETS:
        obj = chart.get(pid)
        icon = PLANET_ICONS.get(pid, '')
        sign_str = deg_to_sign_str(obj.lon, lang)
        rflag = obj.isRetrograde()
        label = f"{icon} {pid}"
        val   = f"{sign_str}" + (" ℞" if rflag else "")
        out[label] = val
        raw[label] = round(obj.lon % 360.0, 4)
        retro[label] = bool(rflag)
    return out, raw, retro

def find_aspects(natal_chart, transit_chart, target_objects, lang='he', orb_deg=ORBS_DEG):
    meanings = ANGLE_MEANINGS_HE if lang == 'he' else ANGLE_MEANINGS_EN
    aspects = []

    natal_fortune   = calc_part_of_fortune(natal_chart)
    transit_fortune = calc_part_of_fortune(transit_chart)

    def get_lon(chart, p):
        return chart.get(p).lon if p != 'FORTUNE' else (natal_fortune if chart is natal_chart else transit_fortune)

    def retro_of(chart, p):
        return False if p == 'FORTUNE' else chart.get(p).isRetrograde()

    for t in target_objects:
        t_lon = get_lon(transit_chart, t)
        t_name = f"{PLANET_ICONS.get(t,'')} {t}"
        t_retro = retro_of(transit_chart, t)

        for n in target_objects:
            n_lon = get_lon(natal_chart, n)
            n_name = f"{PLANET_ICONS.get(n,'')} {n}"
            n_retro = retro_of(natal_chart, n)

            d = cyc_dist(t_lon, n_lon)
            for a in HARMONIC_ANGLES:
                if abs(d - a) <= orb_deg:
                    aspects.append({
                        "tPlanet": t_name + (" ℞" if t_retro else ""),
                        "nPlanet": n_name + (" ℞" if n_retro else ""),
                        "tRetro": bool(t_retro),
                        "nRetro": bool(n_retro),
                        "aspect": meanings.get(a, f"{a}°"),
                        "orb": round(abs(d - a), 2),
                        "tPos": deg_to_sign_str(t_lon, lang) + (" ℞" if t_retro else ""),
                        "nPos": deg_to_sign_str(n_lon, lang) + (" ℞" if n_retro else ""),
                    })
                    break
    return aspects

def find_lucky_windows(date_obj, natal_chart, tz, lat, lon, target_objects, lang='he', orb_deg=ORBS_DEG):
    """בכל 3 שעות מחשב קשרים ומחזיר כל החלונות ליום, עם score_sum מספרי עקבי."""
    windows = []
    date_str = date_obj.strftime('%Y/%m/%d')

    for hour in range(START_HOUR, END_HOUR + 1, INTERVAL_H):
        transit = build_chart(date_str, f"{hour:02d}:00", tz, lat, lon)

        # רשימת היבטים טקסטואלית להצגה
        found = []
        transit_fortune = calc_part_of_fortune(transit)
        natal_fortune   = calc_part_of_fortune(natal_chart)

        def lon_of(chart_or_tag, p):
            if p == 'FORTUNE':
                return transit_fortune if chart_or_tag == 'tr' else natal_fortune
            return (transit if chart_or_tag == 'tr' else natal_chart).get(p).lon

        meanings = ANGLE_MEANINGS_HE if lang == 'he' else ANGLE_MEANINGS_EN
        for p1 in target_objects:  # natal
            pos1 = lon_of('na', p1)
            for p2 in target_objects:  # transit
                pos2 = lon_of('tr', p2)
                d = cyc_dist(pos1, pos2)
                for a in HARMONIC_ANGLES:
                    if abs(d - a) <= orb_deg:
                        icon1 = PLANET_ICONS.get(p1, p1)
                        icon2 = PLANET_ICONS.get(p2, p2)
                        meaning = meanings.get(a, f"{a}°")
                        found.append(f"{icon1} {p1} ↔ {icon2} {p2} — {meaning} ({round(abs(d-a),2)}°)")
                        break

        if found:
            # ניקוד מספרי (זה הדבר החשוב ל-Flutter)
            score_num = _score_block_numeric(natal_chart, transit, target_objects, orb_deg=orb_deg)

            end_h = (hour + INTERVAL_H) % 24
            windows.append({
                "from": f"{hour:02d}:00",
                "to":   f"{end_h:02d}:00",
                "count": len(found),
                "score": estimate_potential_score(len(found)),  # תווית להצגה
                "score_sum": score_num,                         # ← תמיד מספר!
                "aspects": found
            })
    return windows

def summarize_retro_list(transit_retro_flags):
    items = []
    for label, flag in transit_retro_flags.items():
        if flag:
            items.append(label if "℞" in label else label + " ℞")
    return items

# ========= API ראשי =========
def main():
    stdout_utf8()

    parser = argparse.ArgumentParser(description="Astro Calc API (no Telegram). Prints JSON to stdout.")
    parser.add_argument("--date", required=True, help="Birth date or base date (YYYY-MM-DD)")
    parser.add_argument("--time", required=True, help="Birth time (HH:MM)")
    parser.add_argument("--lat",  required=True, type=str, help="Latitude (e.g. 32.08 or 32n5)")
    parser.add_argument("--lon",  required=True, type=str, help="Longitude (e.g. 34.78 or 34e53)")
    parser.add_argument("--tz",   required=False, default="+02:00", help="Timezone offset like +02:00")
    parser.add_argument("--lang", required=False, default="he", choices=["he","en"], help="Language for labels")
    parser.add_argument("--transit-date", required=False, help="Transit date YYYY-MM-DD (default = --date)")
    parser.add_argument("--objects", required=False, choices=["money", "all"], default="money",
                        help="Which objects group to use: money (Venus,Jupiter,Moon,Pluto,Fortune,Uranus) or all")
    parser.add_argument("--days", type=int, default=1, help="Number of consecutive days to compute (1..3)")
    args = parser.parse_args()

    target_objects = (ALL_OBJECTS if args.objects == "all" else MONEY_GROUP)

    birth_date = args.date.replace("-", "/")
    birth_time = args.time
    tz = args.tz
    lat = args.lat
    lon = args.lon
    lang = args.lang
    base_transit_date = (args.transit_date or args.date).replace("-", "/")
    num_days = max(1, min(int(args.days), 3))

    natal_chart = build_chart(birth_date, birth_time, tz, lat, lon)

    start_dt = datetime.strptime(base_transit_date, "%Y/%m/%d")
    days_payload = []

    for i in range(num_days):
        day_dt = start_dt + timedelta(days=i)
        day_str = day_dt.strftime("%Y/%m/%d")

        transit_chart = build_chart(day_str, "12:00", tz, lat, lon)

        natal,  natal_raw,  natal_retro     = planets_dict(natal_chart, lang)
        transit, transit_raw, transit_retro = planets_dict(transit_chart, lang)

        aspects = find_aspects(natal_chart, transit_chart, target_objects, lang=lang, orb_deg=ORBS_DEG)
        lucky   = find_lucky_windows(day_dt, natal_chart, tz, lat, lon, target_objects, lang=lang, orb_deg=ORBS_DEG)

        best = max(lucky, key=lambda w: w.get("count", 0)) if lucky else None
        recommendation = None
        if best:
            recommendation = {
                "text": f"🟢 המלצה: למלא לוטו/חישגד/צ'אנס סביב {best['from']}–{best['to']}",
                "from": best["from"],
                "to": best["to"],
                "score": best["score"],
                "count": best["count"]
            }

        day_payload = {
            "date": day_str.replace("/", "-"),
            "lang": lang,
            "natal": natal,
            "transit": transit,
            "aspects": aspects,
            "lucky_hours": lucky,
            "natal_raw": natal_raw,
            "transit_raw": transit_raw,
            "natal_retro_flags": natal_retro,
            "transit_retro_flags": transit_retro,
            "retro_list": summarize_retro_list(transit_retro),
            "natal_asc_deg": round(natal_chart.get(const.ASC).lon % 360.0, 4),
            "natal_mc_deg":  round(natal_chart.get(const.MC).lon  % 360.0, 4),
            "recommendation": recommendation,
        }
        days_payload.append(day_payload)

    today = days_payload[0]
    payload = dict(today)
    payload["days"] = days_payload

    print(json.dumps(payload, ensure_ascii=False))

if __name__ == "__main__":
    main()
