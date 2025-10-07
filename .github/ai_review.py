import os
import glob
import json
import time
import random
import re
from pathlib import Path

import requests
from openai import OpenAI

ROOT = Path(__file__).resolve().parents[1]
REPORT_PATH = ROOT / ".github" / "ai_review_report.md"
CONTROL_FILE = ROOT / ".github" / "ai_control.json"

INCLUDE_GLOBS = ["lib/**/*.dart", "pubspec.yaml"]
MAX_FILE_BYTES = 200_000
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-5")  # אפשר לשנות ל gpt-4o-mini אם תרצה

# ---------- Utils: config, telegram ----------

def load_control():
    if CONTROL_FILE.exists():
        try:
            return json.loads(CONTROL_FILE.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}

def send_telegram(chat_id: str, text: str) -> bool:
    token = os.getenv("TELEGRAM_TOKEN")
    if not token or not chat_id:
        print("⚠️ אין TELEGRAM_TOKEN או chat_id. דילגתי על טלגרם.")
        return False
    try:
        url = f"https://api.telegram.org/bot{token}/sendMessage"
        resp = requests.post(url, data={"chat_id": chat_id, "text": text}, timeout=15)
        return resp.ok
    except Exception as e:
        print(f"⚠️ שגיאת טלגרם: {e}")
        return False

def poll_for_approval(chat_id: str, token_code: str, timeout_sec: int = 900) -> bool:
    """
    מחכה לאישור בטלגרם. עליך להשיב בטלגרם:
    כן <קוד>
    לדוגמה: כן {123456}

    החזרה True אם אושר. אחרת False אחרי טיים אאוט.
    """
    tg_token = os.getenv("TELEGRAM_TOKEN")
    if not tg_token or not chat_id:
        print("⚠️ אין טלגרם מוגדר. מניח שאושר = False.")
        return False

    print("⌛ ממתין לאישור בטלגרם... עד 15 דקות.")
    end = time.time() + timeout_sec
    last_update_id = None
    pattern = re.compile(rf"^\s*כן\s*{re.escape(token_code)}\s*$", re.IGNORECASE)

    while time.time() < end:
        try:
            url = f"https://api.telegram.org/bot{tg_token}/getUpdates"
            params = {"timeout": 25}
            if last_update_id is not None:
                params["offset"] = last_update_id + 1
            r = requests.get(url, params=params, timeout=30)
            if not r.ok:
                time.sleep(3)
                continue
            data = r.json()
            if not data.get("ok"):
                time.sleep(3)
                continue

            for upd in data.get("result", []):
                last_update_id = upd.get("update_id", last_update_id)
                # הודעה רגילה
                msg = upd.get("message")
                if msg and str(msg.get("chat", {}).get("id")) == str(chat_id):
                    text = (msg.get("text") or "").strip()
                    if pattern.match(text):
                        return True
        except requests.Timeout:
            continue
        except Exception as e:
            print(f"⚠️ שגיאה בקריאת getUpdates: {e}")
            time.sleep(3)
    return False

# ---------- Files ----------

def collect_files():
    files = []
    for pattern in INCLUDE_GLOBS:
        for p in glob.glob(pattern, recursive=True):
            try:
                if os.path.getsize(p) <= MAX_FILE_BYTES:
                    with open(p, "r", encoding="utf-8", errors="ignore") as f:
                        files.append({"path": p, "content": f.read()})
            except Exception:
                pass
    return files

# ---------- OpenAI review ----------

def run_review(files):
    prompt = """אתה משמש כבודק Flutter.
בדוק קבצי קוד לאפליקציה אסטרולוגית:
- האם מסך הפתיחה מכסה את כל המסך.
- האם יש טעינות מיותרות או עיכובים.
- האם יש שימוש יעיל ב Widgets.
- האם pubspec.yaml תקין.
- הצע שיפורים מדויקים ותמציתיים.
כתוב בעברית וצרף דוגמאות קוד.
"""
    parts = [f"# {f['path']}\n{f['content']}" for f in files]
    content = prompt + "\n\n" + "\n\n".join(parts)

    api_key = os.getenv("OPENAI_API_KEY", "")
    if not api_key:
        raise SystemExit("Missing OPENAI_API_KEY")
    client = OpenAI(api_key=api_key)

    print("🤖 שולח בקשה ל OpenAI...")
    resp = client.chat.completions.create(
        model=OPENAI_MODEL,
        temperature=0.2,
        messages=[{"role": "user", "content": content}],
    )
    return resp.choices[0].message.content or ""

# ---------- Main ----------

def main():
    control = load_control()
    chat_id = str(control.get("telegram_chat_id", "")).strip()
    ask_before_fix = bool(control.get("ask_before_fix", True))
    telegram_notify = bool(control.get("telegram_notify", True))

    files = collect_files()
    if not files:
        print("❌ לא נמצאו קבצים לבדיקה.")
        return

    report = run_review(files)

    # שמירת הדוח לקובץ
    REPORT_PATH.write_text(report, encoding="utf-8")
    print(f"💾 נשמר דוח ל {REPORT_PATH}")

    # שולח בקשה לאישור בטלגרם
    if ask_before_fix and telegram_notify and chat_id:
        token_code = str(random.randint(100000, 999999))
        txt = (
            "🧠 דו\"ח סקירה חדש נוצר.\n"
            "כדי לאשר תיקונים אוטומטיים, השב כאן:\n"
            f"כן {token_code}\n"
            "(יש לך עד 15 דקות)"
        )
        send_telegram(chat_id, txt)
        approved = poll_for_approval(chat_id, token_code, timeout_sec=900)
        if not approved:
            print("⛔ לא התקבלה הסכמה. אין תיקונים אוטומטיים.")
            return
        print("✅ אושר בטלגרם. ניתן להמשיך לתיקונים כאן אם תרצה ליישם patch.")

    else:
        if ask_before_fix:
            print("⏸️ ask_before_fix פעיל אבל אין טלגרם. נעצר ללא תיקון.")
            return
        else:
            print("✅ מצב אוטומטי ללא אישור ידני פעיל. כאן אפשר ליישם patch אם נוצר.")

    # בשלב זה יש אישור. אם תרצה לייצר patch וליישם אותו, זה המקום.
    # למשל: להריץ מודל נוסף שמחזיר unified diff ולהחיל git apply.
    # כרגע משאירים רק את הדוח. אפשר להוסיף לוגיקת patch בהמשך.

if __name__ == "__main__":
    main()
