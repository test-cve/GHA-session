import time

from flask import Flask, jsonify

app = Flask(__name__)

start_time = time.time()


@app.route('/hello/<name>', methods=['GET'])
def greet(name):
    return f"Hello, {name}!"


@app.route('/health', methods=['GET'])
def health_check():
    current_time = time.time()
    uptime_seconds = int(current_time - start_time)
    uptime = {
        "days": uptime_seconds // 86400,
        "hours": (uptime_seconds % 86400) // 3600,
        "minutes": (uptime_seconds % 3600) // 60,
        "seconds": uptime_seconds % 60
    }

    health_status = {
        "status": "Healthy",
        "message": "The service is up and running!",
        "uptime": uptime
    }
    return jsonify(health_status), 200


if __name__ == '__main__':
    app.run(debug=False)
