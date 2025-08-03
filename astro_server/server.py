from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/forecast', methods=['POST'])
def forecast():
    data = request.get_json()
    name = data.get('name')
    date = data.get('date')
    time = data.get('time')
    city = data.get('city')

    # תחזית מדומה – בהמשך נשלב את Swiss Ephemeris
    response = {
        "forecast": f"שלום {name}, ביום {date} יש לך מזל מצוין 🎯 בעיר {city}"
    }

    return jsonify(response)

if __name__ == '__main__':
    app.run(debug=True)
