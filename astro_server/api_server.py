from flask import Flask
import subprocess

app = Flask(__name__)

@app.route('/forecast', methods=['GET'])
def forecast():
    try:
        # הרצת הקובץ הקיים שמחזיר תחזית אסטרולוגית
        result = subprocess.run(['python', 'astro_server/server.py'], capture_output=True, text=True)
        return result.stdout
    except Exception as e:
        return f"שגיאה: {e}", 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
