# server.py
from flask import Flask, request, jsonify
from forecast_generator import get_forecast

app = Flask(__name__)

@app.route('/forecast', methods=['POST'])
def forecast():
    data = request.json
    name = data.get('name')
    date = data.get('date')  # yyyy-mm-dd
    time = data.get('time')  # HH:MM
    latitude = data['location']['latitude']
    longitude = data['location']['longitude']

    forecast = get_forecast(date, time, latitude, longitude)
    return jsonify({
        'name': name,
        'forecast': forecast
    })

if __name__ == '__main__':
    app.run(debug=True)
