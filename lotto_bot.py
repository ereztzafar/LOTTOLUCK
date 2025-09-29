import json

def save_forecast_json(lucky_hours):
    forecast = []
    for hour, score in lucky_hours:
        start = f"{hour:02d}:00"
        end = f"{min(hour+2, END_HOUR):02d}:00"
        forecast.append({
            "time": f"{start}–{end}",
            "message": f"שעת מזל עם {score} זוויות חיוביות 🟢"
        })
    with open("forecast.json", "w", encoding="utf-8") as f:
        json.dump(forecast, f, ensure_ascii=False, indent=2)
