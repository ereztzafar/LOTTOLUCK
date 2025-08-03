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
    try:
        asc = chart.get(const.ASC).lon
        moon = chart.get(const.MOON).lon
        sun = chart.get(const.SUN).lon
        return angle.norm(asc + moon - sun)
    except Exception as e:
        print(f"⚠️ שגיאה בחישוב פורטונה: {e}")
        return 0.0

def create_chart(date_str, time_str, timezone, location):
    try:
        dt = Datetime(date_str, time_str, timezone)
        print(f"🎯 יוצרת תרשים עבור {date_str} {time_str} באזור זמן {timezone}")
        return Chart(dt, location)
    except Exception as e:
        print(f"❌ שגיאה ביצירת התרשים עבור {date_str} {time_str}: {e}")
        raise

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

    try:
        birth_chart = create_chart(birth_date, birth_time, timezone, location)
    except Exception:
        print("🚫 לא ניתן ליצור תרשים לידה. בדוק את הקלט.")
        return

    fortune_birth = calculate_part_of_fortune(birth_chart)

    output = []
    output.append(f"📅 תחזית אסטרולוגית: {today}")
    output.append(f"🧬 תאריך לידה: {birth_date} {birth_time}")

    for hour in range(5, 24):
        time_str = f"{hour:02d}:00"
        try:
            transit_chart = create_chart(today, time_str, timezone, location)
        except Exception:
            output.append(f"{time_str} — שגיאה ביצירת תרשים טרנזיט")
            continue

        fortune_now = calculate_part_of_fortune(transit_chart)

        score = 0
        # הכנה של נקודות לידה (כולל פורטונה)
        birth_points = []
        for p in const.LIST_OBJECTS:
            try:
                birth_points.append((p, birth_chart.get(p).lon))
            except Exception as e:
                print(f"⚠️ שגיאה בקואורדינטות של {p} בלידה: {e}")
        birth_points.append(('FORTUNE', fortune_birth))

        # הכנה של נקודות טרנזיט (כולל פורטונה)
        transit_points = []
        for p in const.LIST_OBJECTS:
            try:
                transit_points.append((p, transit_chart.get(p).lon))
            except Exception as e:
                print(f"⚠️ שגיאה בקואורדינטות של {p} בטרנזיט: {e}")
        transit_points.append(('FORTUNE', fortune_now))

        # חישוב זוויות
        for name1, pos1 in birth_points:
            for name2, pos2 in transit_points:
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
