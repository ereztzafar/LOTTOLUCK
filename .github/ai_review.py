import os
import glob
import json
import requests
from pathlib import Path
from openai import OpenAI

# -------------------------------------------------
# קובץ בקרה חיצוני (מאפשר שינוי הגדרות בלי לגעת בקוד)
# -------------------------------------------------
CONTROL_FILE = Path(".github/ai_control.json")

def load_control_config():
    """טוען את קובץ הבקרה במידת האפשר"""
    if CONTROL_FILE.exists():
        try:
            return json.loads(CONTROL_FILE.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}

def send_telegram_message(text: str, chat_id: str):
    """שליחת הודעה לטלגרם עם בקרה על טוקן"""
    token = os.getenv("TELEGRAM_TOKEN")
    if not token or not chat_id:
        print("⚠️ אין טוקן או chat_id - לא נשלחה הודעה לטלגרם.")
        return
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    data = {"chat_id": chat_id, "text": text, "parse_mode": "HTML"}
    try:
        requests.post(url, data=data, timeout=10)
        print("📨 נשלחה הודעה לטלגרם.")
    except Exception as e:
        print(f"⚠️ שגיאה בשליחת הודעה לטלגרם: {e}")

# -------------------------------------------------
# פונקציית הסקירה הראשית
# -------------------------------------------------
def main():
    control = load_control_config()
    ask_before_fix = control.get("ask_before_fix", True)
    telegram_notify = control.get("telegram_notify", True)
    telegram_chat_id = control.get("telegram_chat_id", "")

    client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY", ""))

    # שלב 1: איסוף קבצים
    files = []
    for pattern in ["lib/**/*.dart", "pubspec.yaml"]:
        for p in glob.glob(pattern, recursive=True):
            if os.path.getsize(p) < 200_000:
                with open(p, "r", encoding="utf-8", errors="ignore") as f:
                    files.append({"path": p, "content": f.read()})

    if not files:
        print("❌ לא נמצאו קבצים לבדיקה.")
        return

    # שלב 2: יצירת prompt
    prompt = """אתה משמש כבודק Flutter.
בדוק קבצי קוד לאפליקציה אסטרולוגית לוטו:
- האם מסך הפתיחה (Splash) מכסה את כל המסך.
- האם יש טעינות מיותרות או עיכובים בבוט.
- האם יש שימוש יעיל ב-Widgets.
- האם קובץ pubspec.yaml תקין.
- הצע שיפורים מדויקים ובצורה תמציתית.
כתוב בעברית וצרף דוגמאות קוד.
"""

    parts = [f"# {f['path']}\n{f['content']}" for f in files]
    content = prompt + "\n\n" + "\n\n".join(parts)

    # שלב 3: קריאה למודל OpenAI
    print("🤖 שולח את הקבצים לניתוח AI...")
    resp = client.chat.completions.create(
        model="gpt-5",
        messages=[{"role": "user", "content": content}],
        temperature=0.2
    )

    result = resp.choices[0].message.content

    # שלב 4: הצגת דו"ח
    print("\n=== דו\"ח סקירה ===\n")
    print(result)

    # שלב 5: התראה לטלגרם לפני תיקון
    if telegram_notify:
        send_telegram_message("🧠 דו\"ח סקירה חדש נוצר. האם לאשר תיקון? (כן/לא)", telegram_chat_id)

    if ask_before_fix:
        print("\n⏸️ ממתין לאישור שלך לפני תיקון הקוד (ראה טלגרם).")
        return

    print("\n✅ מצב אוטומטי: מתקן קוד ללא אישור ידני.")

if __name__ == "__main__":
    main()
