from flask import Flask, request, jsonify
import os
import datetime
import pytz
from flatlib.chart import Chart
from flatlib.datetime import Datetime
from flatlib import angle, const
from flatlib.geopos import GeoPos
from math import fabs

app = Flask(__name__)

PLANETS = [
    const.SUN, const.MOON, const.MERCURY, const.VENUS, const.MARS,
    const.JUPITER, const.SATURN, const.URANUS, const.NEPTUNE, const.PLUTO
]
SIGNS = [
    'ARIES', 'TAURUS', 'GEMINI', 'CANCER', 'LEO', 'VIRGO',
    'LIBRA', 'SCORPIO', 'SAGITTARIUS', 'CAPRICORN', 'AQUARIUS', 'PISCES'
]
HARMONIC_ANGLES = [0, 60, 120, 180]
CHALLENGING_ANGLES = [90, 150]

def create_chart(date_str, time_str, tz, location):
    dt = Datetime(date_str, time_str, tz)
    return Chart(dt, location, IDs=PLANETS)

def get_sign(lon):
    index = int((lon % 360) / 30)
    return SIGNS[index]

def calc_angle(pos1, pos2):
    diff = fabs(pos1 - pos2) % 360
    return min(diff, 360 - diff)

def calculate_part_of_fortune(chart):
    asc = chart.get(const.ASC).lon
    moon = chart.get(const.MOON).lon
    sun = chart.get(const.SUN).lon
    return angle.norm(asc + moon - sun)

@app.route('/forecast', methods=['POST'])
def forecast():
    try:
        data = request.json
        birth_date = data['birth_date']     # פורמט: '1970/11/22'
        birth_time = data['birth_time']     # פורמט: '06:00'
        tz_offset = data.get('timezone', '+02:00')
        lat = data.get('latitude', '32n5')
        lon = data.get('longitude', '34e53')
        location = GeoPos(lat, lon)

        now = datetime.datetime.now(pytz.timezone("Asia/Jerusalem"))
        today_str = now.strftime('%Y/%m/%d')

        birth_chart = create_chart(birth_date, birth_time, tz_offset, location)
        transit_chart = create_chart(today_str, '12:00', tz_offset, location)

        aspects_list = []

        for p1 in PLANETS:
            obj1 = birth_chart.get(p1)
            for p2 in PLANETS:
                obj2 = transit_chart.get(p2)
                angle_val = calc_angle(obj1.lon, obj2.lon)
                for target_angle in HARMONIC_ANGLES + CHALLENGING_ANGLES:
                    if abs(angle_val - target_angle) <= 6:
                        aspects_list.append({
                            'planet1': p1,
                            'planet2': p2,
                            'angle': int(angle_val),
                            'type': 'harmonic' if target_angle in HARMONIC_ANGLES else 'challenging'
                        })
                        break

        fortune = calculate_part_of_fortune(birth_chart)
        sign = get_sign(fortune)
        deg = int(fortune % 30)
        minutes = int((fortune % 1) * 60)

        return jsonify({
            'date': today_str,
            'fortune': {
                'sign': sign,
                'deg': deg,
                'min': minutes
            },
            'aspects': aspects_list
        })

    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')
