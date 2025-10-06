import os, glob
from openai import OpenAI

# יוצרים לקוח OpenAI (דורש secret בשם OPENAI_API_KEY ב-GitHub)
client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

# נאגרים קבצי Flutter ודארט לבדיקה
files = []
for pattern in ["lib/**/*.dart", "pubspec.yaml"]:
    for p in glob.glob(pattern, recursive=True):
        if os.path.getsize(p) < 200_000:
            with open(p, "r", encoding="utf-8", errors="ignore") as f:
                files.append({"path": p, "content": f.read()})

prompt = """אתה משמש כבודק Flutter.
בדוק קבצי קוד לאפליקציה אסטרולוגית לוטו:
- האם מסך הפתיחה (Splash) מכסה את כל המסך.
- האם יש טעינות מיותרות או עיכובים בבוט.
- האם יש שימוש יעיל ב-Widgets.
- האם קובץ pubspec.yaml תקין.
- הצע שיפורים מדויקים ובצורה תמציתית.
כתוב בעברית וצרף דוגמאות קוד.
"""

parts = []
for f in files:
    parts.append(f"# {f['path']}\n{f['content']}")

content = prompt + "\n\n" + "\n\n".join(parts)
resp = client.chat.completions.create(
    model="gpt-4o-mini",
    messages=[{"role": "user", "content": content}],
    temperature=0.2
)

print(resp.choices[0].message.content)
