# -*- coding: utf-8 -*-
import sys, json, io
from datetime import datetime, timedelta
import pytz
from flatlib.chart import Chart
from flatlib.datetime import Datetime
from flatlib.geopos import GeoPos
from flatlib import const, angle

# ===== תמיכה בעברית ב-Windows =====
try:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', newline='\n')
except Exception:
    pass

# שימוש:
# python astrology_forecast.py YYYY-MM-DD HH:MM City LAT LON [TZID] [lang]

if len(sys.argv) < 6:
    print(json.dumps({"error": "Missing arguments (need: date time city lat lon [tzid] [lang])"}), flush=True)
    sys.exit(1)

birth_date = sys.argv[1]
birth_time = sys.argv[2]
city_name  = sys.argv[3]
lat        = float(sys.argv[4])
lon        = float(sys.argv[5])

tzid = None
lang = "he"

if len(sys.argv) >= 7:
    candidate = sys.argv[6]
    if "/" in candidate:
        tzid = candidate
        if len(sys.argv) >= 8:
            lang = sys.argv[7]
    else:
        lang = candidate

def guess_tzid(lat, lon):
    try:
        from timezonefinder import TimezoneFinder
        tzf = TimezoneFinder()
        return tzf.timezone_at(lat=lat, lng=lon)
    except Exception:
        return None

if not tzid:
    tzid = guess_tzid(lat, lon) or "Etc/UTC"

# ---- המרה decimal -> GeoPos ----
def dec_to_geostr(val, is_lat=True):
    sign = 'n' if is_lat else 'e'
    if val < 0:
        sign = 's' if is_lat else 'w'
    aval = abs(val)
    deg = int(aval)
    minutes = int(round((aval - deg) * 60))
    if minutes == 60:
        deg += 1
        minutes = 0
    return f"{deg}{sign}{minutes}"

LAT_STR = dec_to_geostr(lat, True)
LON_STR = dec_to_geostr(lon, False)
LOCATION = GeoPos(LAT_STR, LON_STR)

# ---- offset לפי אזור זמן ----
def tz_offset_str(dt_naive, tz_name):
    tz = pytz.timezone(tz_name)
    localized = tz.localize(dt_naive, is_dst=None)
    off = localized.utcoffset() or timedelta()
    total_min = int(off.total_seconds() // 60)
    sgn = "+" if total_min >= 0 else "-"
    hh, mm = divmod(abs(total_min), 60)
    return f"{sgn}{hh:02d}:{mm:02d}"

# ==== רשימת אובייקטים לצ'ארט ====
OBJECTS = [
    const.SUN, const.MOON, const.MERCURY, const.VENUS, const.MARS,
    const.JUPITER, const.SATURN, const.URANUS, const.NEPTUNE, const.PLUTO
]

# ===== מפת לידה =====
birth_dt_local = datetime.strptime(f"{birth_date} {birth_time}", "%Y-%m-%d %H:%M")
birth_off = tz_offset_str(birth_dt_local, tzid)
natal_dt = Datetime(
    birth_dt_local.strftime('%Y/%m/%d'),
    birth_dt_local.strftime('%H:%M'),
    birth_off
)
natal_chart = Chart(natal_dt, LOCATION, IDs=OBJECTS)

# ===== מפת טרנזיט (עכשיו) =====
now_local = datetime.now(pytz.timezone(tzid)).replace(second=0, microsecond=0)  # aware
now_local_naive = now_local.replace(tzinfo=None)  # naive
now_off = tz_offset_str(now_local_naive, tzid)
transit_dt = Datetime(
    now_local_naive.strftime('%Y/%m/%d'),
    now_local_naive.strftime('%H:%M'),
    now_off
)
transit_chart = Chart(transit_dt, LOCATION, IDs=OBJECTS)

# ===== שמות כוכבים =====
planet_names = {
    "he": {
        const.SUN:"☀️ שמש", const.MOON:"🌙 ירח", const.MERCURY:"☿ מרקורי", const.VENUS:"♀ ונוס",
        const.MARS:"♂ מארס", const.JUPITER:"♃ צדק", const.SATURN:"♄ שבתאי", const.URANUS:"♅ אורנוס",
        const.NEPTUNE:"♆ נפטון", const.PLUTO:"♇ פלוטו"
    },
    "en": {
        const.SUN:"☀️ Sun", const.MOON:"🌙 Moon", const.MERCURY:"☿ Mercury", const.VENUS:"♀ Venus",
        const.MARS:"♂ Mars", const.JUPITER:"♃ Jupiter", const.SATURN:"♄ Saturn", const.URANUS:"♅ Uranus",
        const.NEPTUNE:"♆ Neptune", const.PLUTO:"♇ Pluto"
    },
}
names = planet_names.get(lang, planet_names["he"])
PLANETS = list(OBJECTS)

def fmt_degmin(lon, sign_name):
    """מציג מיקום בתוך המזל: 0°00′–29°59′ + שם המזל."""
    L = angle.norm(float(lon))          # 0..360
    pos_in_sign = L % 30.0
    d = int(pos_in_sign)
    m = int(round((pos_in_sign - d) * 60))
    if m == 60:
        d += 1
        m = 0
        if d == 30:
            d = 0
    return f"{sign_name} {d}°{m:02d}′"

def positions_dict(chart):
    """טקסט לתצוגה + ℞ בסוף אם צריך"""
    out = {}
    for p in PLANETS:
        try:
            obj = chart.get(p)
            label = names.get(p, str(p))
            retro = " ℞" if obj.isRetrograde() else ""
            out[label] = f"{fmt_degmin(obj.lon, obj.sign)}{retro}"
        except Exception:
            continue
    return out

def positions_raw(chart):
    """תאימות לאחור: {label: lon} בלבד (0..360)"""
    out = {}
    for p in PLANETS:
        try:
            obj = chart.get(p)
            label = names.get(p, str(p))
            out[label] = float(obj.lon)
        except Exception:
            pass
    return out

def positions_raw_meta(chart):
    """חדש: {label: {lon: float, retro: bool, label: str}}"""
    out = {}
    for p in PLANETS:
        try:
            obj = chart.get(p)
            label = names.get(p, str(p))
            out[label] = {
                "lon": float(obj.lon),
                "retro": bool(obj.isRetrograde()),
                "label": label
            }
        except Exception:
            pass
    return out

natal_positions       = positions_dict(natal_chart)
transit_positions     = positions_dict(transit_chart)
natal_positions_raw   = positions_raw(natal_chart)
transit_positions_raw = positions_raw(transit_chart)
natal_raw_meta        = positions_raw_meta(natal_chart)
transit_raw_meta      = positions_raw_meta(transit_chart)

# ===== היבטים טרנזיט → לידה =====
def cyc_dist(a, b):
    return abs((a - b + 180) % 360 - 180)

ASPECT_DEFS = [
    (0,   {"he": "צמידות",   "en": "Conjunction"}, 8),
    (60,  {"he": "סקסטיל",   "en": "Sextile"},     4),
    (90,  {"he": "ריבוע",     "en": "Square"},      6),
    (120, {"he": "טריין",     "en": "Trine"},       6),
    (180, {"he": "אופוזיציה", "en": "Opposition"},  8),
]

def nearest_aspect(delta):
    best = None
    for angleDeg, names_map, orb in ASPECT_DEFS:
        diff = abs(delta - angleDeg)
        if diff <= orb and (best is None or diff < best[1]):
            best = (angleDeg, names_map.get(lang, names_map["he"]), diff, orb)
    return best  # (angle, name, diff, orb)

def aspects_transit_to_natal(chart_tr, chart_nat):
    res = []
    for t in PLANETS:
        try:
            tObj = chart_tr.get(t)
        except KeyError:
            continue
        tName = names.get(t, str(t))
        for n in PLANETS:
            try:
                nObj = chart_nat.get(n)
            except KeyError:
                continue
            nName = names.get(n, str(n))
            delta = cyc_dist(tObj.lon, nObj.lon)
            asp = nearest_aspect(delta)
            if asp:
                angleDeg, aspName, orbActual, _ = asp
                res.append({
                    "tPlanet": tName,
                    "nPlanet": nName,
                    "aspect": aspName,
                    "angle": angleDeg,
                    "orb": round(float(orbActual), 2),
                    "tPos": fmt_degmin(tObj.lon, tObj.sign),
                    "nPos": fmt_degmin(nObj.lon, nObj.sign),
                    "tRetro": bool(tObj.isRetrograde()),
                    "nRetro": bool(nObj.isRetrograde()),
                })
    return res

aspects_list = aspects_transit_to_natal(transit_chart, natal_chart)

# ===== עזר: Retrogrades ליום נתון =====
def retrogrades_for_date(date_str, tzid, location):
    """date_str בפורמט YYYY/MM/DD"""
    base_naive = datetime.strptime(date_str, "%Y/%m/%d")  # naive
    dt = Datetime(date_str, '12:00', tz_offset_str(base_naive, tzid))
    ch = Chart(dt, location, IDs=OBJECTS)
    out = []
    for p in PLANETS:
        try:
            obj = ch.get(p)
            if obj.isRetrograde():
                out.append(names.get(p, str(p)) + " ℞")
        except Exception:
            pass
    return out

# ===== Placidus: קוספים + ASC/MC =====
def houses_raw(chart):
    """1..12 cusps (longitudes 0..360)"""
    out = {}
    try:
        for i in range(1, 13):
            cusp = chart.houses.get(i)
            out[str(i)] = float(cusp.lon)
    except Exception:
        pass
    return out

def asc_mc(chart):
    asc = None
    mc = None
    try:
        asc = float(chart.get(const.ASC).lon)
    except Exception:
        pass
    try:
        mc = float(chart.get(const.MC).lon)
    except Exception:
        pass
    return asc, mc

natal_houses_raw   = houses_raw(natal_chart)
transit_houses_raw = houses_raw(transit_chart)
natal_asc_deg, natal_mc_deg     = asc_mc(natal_chart)
transit_asc_deg, transit_mc_deg = asc_mc(transit_chart)

# ===== בלוקים של "שעות מזל" =====
START_HOUR = 5
END_HOUR   = 23
STEP_MIN   = 60

def score_from_aspects(aspects):
    score = 0
    for a in aspects:
        ang = a.get("angle")
        if ang in (0, 60, 120, 180):
            score += 2
        elif ang == 90:
            score += 1
    return score

def chart_at_local(dt_loc_naive):
    """dt_loc_naive: datetime נאיבי (ללא tzinfo)"""
    off = tz_offset_str(dt_loc_naive, tzid)
    fdt = Datetime(dt_loc_naive.strftime('%Y/%m/%d'), dt_loc_naive.strftime('%H:%M'), off)
    return Chart(fdt, LOCATION, IDs=OBJECTS)

def lucky_blocks_for_day(center_dt_local_aware, natal_chart, tzid, location):
    base = center_dt_local_aware.replace(hour=START_HOUR, minute=0, second=0, microsecond=0)
    end  = center_dt_local_aware.replace(hour=END_HOUR,   minute=0, second=0, microsecond=0)

    blocks = []
    cur = base
    while cur <= end:
        cur_naive = cur.replace(tzinfo=None)
        ch = chart_at_local(cur_naive)
        aspects = aspects_transit_to_natal(ch, natal_chart)

        money_aspects = []
        for a in aspects:
            lbl = a["nPlanet"]
            if any(k in lbl for k in ["ונוס", "Venus", "צדק", "Jupiter", "ירח", "Moon"]):
                money_aspects.append(a)

        if money_aspects:
            sc = score_from_aspects(money_aspects)
            label_score = f"פוטנציאל: {min(sc * 10, 100)}%"
            blocks.append({
                "time": cur.strftime("%H:%M"),
                "score": label_score,
                "aspects": money_aspects
            })

        cur += timedelta(minutes=STEP_MIN)
    return blocks

def lucky_blocks_for_multiple_days(start_local_dt_aware, natal_chart, tzid, location, days=3):
    days_map = {}
    for i in range(days):
        cur = start_local_dt_aware + timedelta(days=i)
        date_key = cur.strftime('%Y-%m-%d')
        blocks = lucky_blocks_for_day(cur, natal_chart, tzid, location)

        def _pct(s):
            try:
                return int(s.split('%')[0].split()[-1])
            except Exception:
                return 0

        best_time = (max(blocks, key=lambda b: _pct(b["score"]))["time"] if blocks else None)
        days_map[date_key] = {
            "lucky_blocks": blocks,
            "best_time": best_time,
            "retrogrades": retrogrades_for_date(cur.strftime('%Y/%m/%d'), tzid, location),
        }
    return days_map

# ---- תאימות אחורה: lucky_hours (2 חלונות) ----
def find_lucky_windows(now_naive, count=2):
    tz = pytz.timezone(tzid)
    start_aware = tz.localize(now_naive).replace(minute=0, second=0, microsecond=0)
    windows = []
    step = 10
    horizon_minutes = 16 * 60
    checked = 0
    cur = start_aware

    while checked <= horizon_minutes and len(windows) < count:
        cur_naive = cur.replace(tzinfo=None)
        cur_off = tz_offset_str(cur_naive, tzid)
        cur_dt = Datetime(cur_naive.strftime('%Y/%m/%d'), cur_naive.strftime('%H:%M'), cur_off)
        cur_chart = Chart(cur_dt, LOCATION, IDs=OBJECTS)

        moon_tr = cur_chart.get(const.MOON).lon
        venus_nat = natal_chart.get(const.VENUS).lon
        jup_nat = natal_chart.get(const.JUPITER).lon

        for target in (venus_nat, jup_nat):
            d = cyc_dist(moon_tr, target)
            if any(abs(d - k) <= 2 for k in (60, 120)):
                start_str = (cur - timedelta(minutes=15)).strftime("%H:%M")
                end_str   = (cur + timedelta(minutes=15)).strftime("%H:%M")
                win = {"from": start_str, "to": end_str}
                if not windows or windows[-1] != win:
                    windows.append(win)
                break

        cur += timedelta(minutes=step)
        checked += step

    if not windows:
        windows = [{"from": "08:15", "to": "09:00"}, {"from": "16:40", "to": "17:10"}]
    return windows

# ===== הפקה ל-JSON =====
lucky_hours = find_lucky_windows(now_local_naive, count=2)
lucky_blocks_today = lucky_blocks_for_day(now_local, natal_chart, tzid, LOCATION)
daily_3days = lucky_blocks_for_multiple_days(now_local, natal_chart, tzid, LOCATION, days=3)

comments = {
    "he": "כולל היבטי טרנזיט→לידה + חלונות מזל. PRO מקבל גם 3 ימים קדימה 🎯",
    "en": "Includes transit→natal aspects + lucky windows. PRO also gets 3-day outlook 🎯",
}

response = {
    "date": now_local_naive.strftime('%Y-%m-%d'),
    "city": city_name,
    "lat": lat,
    "lon": lon,
    "tzid": tzid,
    "lang": lang,
    "app": "LOTTOLUCK",

    # מיקומי כוכבים (טקסט עם ℞)
    "natal": natal_positions,
    "transit": transit_positions,

    # תאימות לאחור: מיקומים 0..360
    "natal_raw": natal_positions_raw,
    "transit_raw": transit_positions_raw,

    # חדש: גולמי + מטא (כולל retro) – לציור גלגל
    "natal_raw_meta": natal_raw_meta,
    "transit_raw_meta": transit_raw_meta,

    # היבטי טרנזיט ללידה
    "aspects": aspects_list,

    # חלונות מזל
    "lucky_hours": lucky_hours,
    "lucky_blocks": lucky_blocks_today,

    # PRO: 3 ימים קדימה
    "daily_3days": daily_3days,

    "comment": comments.get(lang, comments["he"]),
}

# הוספת Placidus + ASC/MC ל-response
response.update({
    "natal_houses_raw":   natal_houses_raw,
    "transit_houses_raw": transit_houses_raw,
    "natal_asc_deg":      natal_asc_deg,
    "natal_mc_deg":       natal_mc_deg,
    "transit_asc_deg":    transit_asc_deg,
    "transit_mc_deg":     transit_mc_deg,
})

print(json.dumps(response, ensure_ascii=False), flush=True)
