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
PATCH_PATH = ROOT / ".github" / "ai_fixes.patch"
CONTROL_FILE = ROOT / ".github" / "ai_control.json"

INCLUDE_GLOBS = ["lib/**/*.dart", "pubspec.yaml"]
MAX_FILE_BYTES = 200_000
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-5")

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

def openai_client() -> OpenAI:
    api_key = os.getenv("OPENAI_API_KEY", "")
    if not api_key:
        raise SystemExit("Missing OPENAI_API_KEY")
    return OpenAI(api_key=api_key)

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
    client = openai_client()
    print("🤖 שולח בקשה ל OpenAI לסקירה...")
    resp = client.chat.completions.create(
        model=OPENAI_MODEL,
        temperature=0.2,
        messages=[{"role": "user", "content": content}],
    )
    return resp.choices[0].message.content or ""

def run_review_with_patch(files):
    # מבקש פורמט דו"ח + בלוק patch אחד
    system = (
        "אתה מבקר קוד. הפק בדיוק שני בלוקים: "
        "1) דו\"ח Markdown קצר שמתחיל בכותרת ### AI Review. "
        "2) בלוק קוד יחיד ```patch עם unified diff שמתחיל ב diff --git. "
        "אם אין תיקונים בטוחים, החזר בלוק patch ריק עם ```patch ואחריו סגירה."
    )
    user = "להלן קבצים רלוונטיים. ספק דו\"ח קצר ואז unified diff יחיד שניתן להחיל עם git apply.\n"
    parts = [f"\n=== FILE: {f['path']} ===\n{f['content']}" for f in files]
    content = user + "".join(parts)
    client = openai_client()
    print("🤖 שולח בקשה ל OpenAI ליצירת דו\"ח ו-patch...")
    resp = client.chat.completions.create(
        model=OPENAI_MODEL,
        temperature=0.2,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": content},
        ],
    )
    return resp.choices[0].message.content or ""

def split_report_and_patch(content: str):
    start = content.rfind("```patch")
    if start == -1:
        return content.strip(), ""
    end = content.find("```", start + 7)
    if end == -1:
        return content.strip(), ""
    report = content[:start].strip()
    patch = content[start + len("```patch"):end].strip()
    return report, patch

def main():
    control = load_control()
    chat_id = str(control.get("telegram_chat_id", "")).strip()
    ask_before_fix = bool(control.get("ask_before_fix", True))
    telegram_notify = bool(control.get("telegram_notify", True))
    gen_patch_after = bool(control.get("generate_patch_after_approval", True))

    files = collect_files()
    if not files:
        print("❌ לא נמצאו קבצים לבדיקה.")
        return

    # שלב א: דו"ח סקירה בסיסי
    report_only = run_review(files)
    REPORT_PATH.write_text(report_only, encoding="utf-8")
    print(f"💾 נשמר דו\"ח ל {REPORT_PATH}")

    # שליחת בקשת אישור
    if ask_before_fix and telegram_notify and chat_id:
        token_code = str(random.randint(100000, 999999))
        msg = (
            "🧠 דו\"ח סקירה חדש נוצר.\n"
            "כדי לאשר יצירת תיקונים, השב כאן:\n"
            f"כן {token_code}\n"
            "(יש לך עד 15 דקות)"
        )
        send_telegram(chat_id, msg)
        approved = poll_for_approval(chat_id, token_code, timeout_sec=900)
        if not approved:
            print("⛔ לא התקבלה הסכמה. מסתיים ללא יצירת Patch.")
            send_telegram(chat_id, "⛔ לא התקבלה הסכמה. לא נוצר Patch.") if telegram_notify else None
            return
        print("✅ אושר בטלגרם.")

    elif ask_before_fix:
        print("⏸️ ask_before_fix פעיל אבל אין טלגרם. נעצר ללא Patch.")
        return

    # שלב ב: יצירת דו\"ח נוסף עם Patch לאחר אישור
    if gen_patch_after:
        content = run_review_with_patch(files)
        report2, patch = split_report_and_patch(content)
        # אם חזר report נוסף, עדכן את הקובץ
        if report2.strip():
            REPORT_PATH.write_text(report2, encoding="utf-8")
        if patch.strip() and patch.lstrip().startswith("diff --git"):
            PATCH_PATH.write_text(patch + "\n", encoding="utf-8")
            print(f"💾 נשמר Patch ל {PATCH_PATH}")
            size = PATCH_PATH.stat().st_size
            if telegram_notify and chat_id:
                send_telegram(chat_id, f"✅ נוצר Patch ונשמר כקובץ.\nמסלול: {PATCH_PATH}\nגודל: {size} bytes")
        else:
            print("ℹ️ לא נוצר Patch תקין. נשמר רק הדו\"ח.")
            if telegram_notify and chat_id:
                send_telegram(chat_id, "ℹ️ לא נוצר Patch תקין. נשמר רק הדו\"ח.")
    else:
        print("ℹ️ דילגתי על יצירת Patch לפי קובץ הבקרה.")
        if telegram_notify and chat_id:
            send_telegram(chat_id, "ℹ️ אושר, אך דילגתי על יצירת Patch לפי קובץ הבקרה.")

if __name__ == "__main__":
    main()
