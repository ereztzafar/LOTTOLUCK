import json
import datetime
import pytz
from flatlib.chart import Chart
from flatlib.datetime import Datetime
from flatlib import angle
from flatlib.geopos import GeoPos
from flatlib import const

INPUT_FILE = 'astro_server/birth_input.json'

def load_birth_data():
    with open(INPUT_FILE, encoding='utf-8') as f:
        data = json.load(f)
    return data

def calculate_part_of_fortune(chart):
    asc = chart.get(const.ASC).lon
    moon = chart.get(const.MOON).lon
    sun = chart.get(const.SUN).lon
    return angle.norm(asc + moon - sun)

def create_chart(date_str, time_str, timezone, location):
    dt = Datetime(date_str, time_str, timezone)
    return Chart(dt, location)

def calc_angle(pos1, pos2):
    diff = abs(pos1 - pos2) % 360
    return min(diff, 360 - diff)

def classify_score(score):
    if score >= 25:
        return '🟩 יום חזק'
    elif score >= 15:
        return '🟨 יום בינוני'
    else:
        return '🟥 יום חלש'

def analyze_today():
    birth = load_birth_data()
    birth_date = birth["birth_date"]
    birth_time = birth["birth_time"]
    timezone = birth["timezone"]
    location = GeoPos(birth["location"]["lat"], birth["location"]["lon"])

    tz = pytz.timezone("Asia/Jerusalem")
    now = datetime.datetime.now(tz)
    today = now.strftime('%Y/%m/%d')

    birth_chart = create_chart(birth_date, birth_time, timezone, location)
    fortune_birth = calculate_part_of_fortune(birth_chart)

    output = []
    output.append(f"📅 תחזית אסטרולוגית: {today}")
    output.append(f"🧬 תאריך לידה: {birth_date} {birth_time}")

    for hour in range(5, 24):
        time_str = f"{hour:02d}:00"
        transit_chart = create_chart(today, time_str, timezone, location)
        fortune_now = calculate_part_of_fortune(transit_chart)

        score = 0
        for p1 in const.LIST_OBJECTS + ['FORTUNE']:
            pos1 = birth_chart.get(p1).lon if p1 != 'FORTUNE' else fortune_birth
            for p2 in const.LIST_OBJECTS + ['FORTUNE']:
                pos2 = transit_chart.get(p2).lon if p2 != 'FORTUNE' else fortune_now
                ang_val = calc_angle(pos1, pos2)
                for h_angle in [0, 60, 120, 180]:
                    if abs(ang_val - h_angle) <= 6:
                        score += 1
                        break

        level = classify_score(score)
        output.append(f"{time_str} — {level} ({score} זוויות חיוביות)")

    print("\n".join(output))

if __name__ == '__main__':
    analyze_today()
