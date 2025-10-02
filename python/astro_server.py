# FILE: python/astro_server.py
# שרת Flask קטן שעוטף סקריפטי פייתון כך שאפליקציית Flutter תוכל לקרוא אליהם ב-HTTP

import os
import sys
import json
import subprocess
from pathlib import Path
from flask import Flask, request, Response
from flask_cors import CORS  # NEW

app = Flask(__name__)

# --- JSON / UTF-8 ---
app.config["JSON_AS_ASCII"] = False
app.config["JSONIFY_MIMETYPE"] = "application/json; charset=utf-8"
# (לא מזיק) המנע ממיון מפתחות אוטומטי
app.config["JSON_SORT_KEYS"] = False

# --- CORS (לפרונט ברנדר) ---
# בפרודקשן מומלץ להחליף origins לכתובת של הפרונט שלך במקום "*"
CORS(app, resources={r"/*": {"origins": "*"}}, supports_credentials=False)

HERE = Path(__file__).resolve().parent
FORECAST_SCRIPT = HERE / "astrology_forecast.py"  # המסך הרגיל
PRO_SCRIPT      = HERE / "astro_calc_api.py"      # מסך PRO (3 ימים/טרנזיטים)


# ---------- Utilities ----------

def _json_response(pyobj: dict | list, status: int = 200) -> Response:
    """החזרת JSON עם קידוד מלא (UTF-8) ו-Content-Type נכון."""
    payload = json.dumps(pyobj, ensure_ascii=False)
    return Response(payload, status=status, mimetype="application/json; charset=utf-8")


def _run_subprocess(args, cwd, timeout_sec: int = 25):
    """
    מריץ תת-תהליך (פייתון פנימי), מחזיר dict מפוענח מ-stdout (JSON).
    מגדיר PYTHONIOENCODING=utf-8 כדי לתמוך ביוניקוד מלא.
    """
    env = os.environ.copy()
    env["PYTHONIOENCODING"] = "utf-8"

    proc = subprocess.run(
        args,
        cwd=str(cwd),
        env=env,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=timeout_sec,
    )

    if proc.returncode != 0:
        raise RuntimeError(
            "subprocess failed\n"
            f"exit={proc.returncode}\n"
            f"stdout:\n{proc.stdout}\n"
            f"stderr:\n{proc.stderr}"
        )

    try:
        return json.loads(proc.stdout)
    except Exception as e:
        raise RuntimeError(f"Bad JSON from subprocess: {e}\nstdout:\n{proc.stdout}") from e


def run_forecast_cli(date: str, time: str, city: str, lat, lon,
                     lang: str, tz_id: str, house_system: str, timeout_sec: int = 22):
    """מריץ את astrology_forecast.py (מסך רגיל) עם כל הפרמטרים שהקליינט שולח."""
    if not FORECAST_SCRIPT.exists():
        raise FileNotFoundError(f"astrology_forecast.py not found at: {FORECAST_SCRIPT}")
    args = [
        sys.executable,
        str(FORECAST_SCRIPT),
        str(date),
        str(time),
        str(city),
        str(lat),
        str(lon),
        str(lang),
        str(tz_id),
        str(house_system),
    ]
    return _run_subprocess(args, HERE, timeout_sec)


def run_pro_cli(transit_date: str, birth_date: str, birth_time: str, tz: str,
                lat, lon, lang: str, timeout_sec: int = 25):
    """
    מריץ את astro_calc_api.py למסך PRO.
    צפוי לקבל את הפרמטרים: transit_date, birth_date, birth_time, tz, lat, lon, lang
    """
    if not PRO_SCRIPT.exists():
        raise FileNotFoundError(f"astro_calc_api.py not found at: {PRO_SCRIPT}")
    args = [
        sys.executable,
        str(PRO_SCRIPT),
        "--date", birth_date,
        "--time", birth_time,
        "--lat", str(lat),
        "--lon", str(lon),
        "--tz", tz,
        "--lang", lang,
        "--transit-date", transit_date,
    ]
    return _run_subprocess(args, HERE, timeout_sec)


# ---------- Health / Diagnostics ----------

@app.get("/health")
def health():
    """בריאות סטנדרטית ל-Render/קוברנטיס."""
    return _json_response({"status": "ok", "service": "astro_server"})

@app.get("/ping")
def ping():
    return _json_response({"ok": True, "msg": "pong"})

@app.get("/_routes")
def routes():
    return _json_response({"routes": [r.rule for r in app.url_map.iter_rules()]})

@app.get("/diag")
def diag():
    return _json_response({
        "ok": True,
        "cwd": str(HERE),
        "forecast_exists": FORECAST_SCRIPT.exists(),
        "pro_exists": PRO_SCRIPT.exists(),
        "forecast_path": str(FORECAST_SCRIPT),
        "pro_path": str(PRO_SCRIPT),
    })


# ---------- Connection header fix ----------

@app.after_request
def add_conn_close(resp: Response):
    """
    סוגר keep-alive כדי למנוע בעיות "Connection closed while receiving data" בצד הלקוח.
    אם תראה שאין צורך – אפשר להסיר.
    """
    resp.headers["Connection"] = "close"
    resp.headers["Cache-Control"] = "no-store"
    return resp


# ---------- API ----------

@app.post("/forecast")
def forecast():
    try:
        data = request.get_json(force=True) or {}
    except Exception:
        return _json_response({"ok": False, "error": "Invalid JSON body"}, 400)

    date = (data.get("date") or "").strip()
    time = (data.get("time") or "").strip()
    city = (data.get("city") or "").strip()
    lat  = data.get("lat", "")
    lon  = data.get("lon", "")
    lang = (data.get("lang") or "he").strip()
    tz_id = (data.get("tz") or "UTC").strip()
    house_system = (data.get("house_system") or "placidus").strip()
    timeout_sec = int(data.get("timeout", 22))

    missing = [k for k, v in [("date", date), ("time", time), ("city", city), ("lat", lat), ("lon", lon)] if not v]
    if missing:
        return _json_response({"ok": False, "error": f"Missing required fields: {', '.join(missing)}"}, 400)

    try:
        result = run_forecast_cli(
            date, time, city, lat, lon, lang, tz_id, house_system,
            timeout_sec=timeout_sec
        )
        return _json_response(result, 200)
    except subprocess.TimeoutExpired:
        return _json_response({"ok": False, "error": f"Computation timed out after {timeout_sec}s"}, 504)
    except FileNotFoundError as e:
        return _json_response({"ok": False, "error": str(e)}, 500)
    except RuntimeError as e:
        return _json_response({"ok": False, "error": str(e)}, 500)
    except Exception as e:
        return _json_response({"ok": False, "error": f"Unexpected error: {e}"}, 500)


@app.post("/pro_forecast")
def pro_forecast():
    try:
        data = request.get_json(force=True) or {}
    except Exception:
        return _json_response({"ok": False, "error": "Invalid JSON body"}, 400)

    transit_date = (data.get("transit_date") or "").strip()
    birth_date   = (data.get("birth_date") or "").strip()
    birth_time   = (data.get("birth_time") or "").strip()
    tz           = (data.get("tz") or "").strip()
    lat          = data.get("lat", "")
    lon          = data.get("lon", "")
    lang         = (data.get("lang") or "he").strip()
    timeout_sec  = int(data.get("timeout", 25))

    missing = [k for k, v in [
        ("transit_date", transit_date),
        ("birth_date",   birth_date),
        ("birth_time",   birth_time),
        ("tz",           tz),
        ("lat",          lat),
        ("lon",          lon),
    ] if not v]
    if missing:
        return _json_response({"ok": False, "error": f"Missing required fields: {', '.join(missing)}"}, 400)

    try:
        result = run_pro_cli(transit_date, birth_date, birth_time, tz, lat, lon, lang, timeout_sec=timeout_sec)
        return _json_response(result, 200)
    except subprocess.TimeoutExpired:
        return _json_response({"ok": False, "error": f"Computation timed out after {timeout_sec}s"}, 504)
    except FileNotFoundError as e:
        return _json_response({"ok": False, "error": str(e)}, 500)
    except RuntimeError as e:
        return _json_response({"ok": False, "error": str(e)}, 500)
    except Exception as e:
        return _json_response({"ok": False, "error": f"Unexpected error: {e}"}, 500)


# ---------- Main (dev only) ----------

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    app.run(host="0.0.0.0", port=port, debug=False, use_reloader=False, threaded=True)
