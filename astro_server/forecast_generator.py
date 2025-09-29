# forecast_generator.py
from flatlib.chart import Chart
from flatlib.datetime import Datetime
from flatlib.geopos import GeoPos
from flatlib import const, angle
from datetime import datetime as dt
import pytz

PLANETS = [const.SUN, const.MOON, const.MERCURY, const.VENUS, const.MARS,
           const.JUPITER, const.SATURN, const.URANUS, const.NEPTUNE, const.PLUTO]
HARMONIC_ANGLES = [0, 60, 120, 180]

def calculate_part_of_fortune(chart):
    asc = chart.get(const.ASC).lon
    moon = chart.get(const.MOON).lon
    sun = chart.get(const.SUN).lon
    return angle.norm(asc + moon - sun)

def get_forecast(date, time, latitude, longitude):
    tz = pytz.timezone("Asia/Jerusalem")
    dt_now = dt.now(tz)
    results = []

    birth_dt = Datetime(date, time, '+02:00')
    pos = GeoPos(str(latitude), str(longitude))
    chart = Chart(birth_dt, pos, IDs=PLANETS)

    fortune = calculate_part_of_fortune(chart)
    results.append({'label': 'פורטונה', 'value': f'{fortune:.2f}'})

    for p1 in PLANETS:
        for p2 in PLANETS:
            if p1 == p2:
                continue
            obj1 = chart.get(p1)
            obj2 = chart.get(p2)
            ang = abs(obj1.lon - obj2.lon)
            ang = min(ang, 360 - ang)
            for target in HARMONIC_ANGLES:
                if abs(ang - target) <= 6:
                    results.append({
                        'between': f"{p1} ↔ {p2}",
                        'angle': f"{ang:.0f}°",
                        'type': 'harmonic'
                    })
    return results
