import os
from flask import Flask, jsonify
from redis import Redis

app = Flask(__name__)
redis_host = os.environ.get('REDIS_HOST', 'localhost')

db = Redis(host=redis_host, port=6379, decode_responses=True)

@app.route('/')
def home():
    current_hits = db.incr('hits')
    return f'Hello from Toronto! This page has been viewed {current_hits} times.'

@app.route('/health')
def health():
    return jsonify({"status": "healthy"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)