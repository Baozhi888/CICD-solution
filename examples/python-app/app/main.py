from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello():
    return {'message': 'Hello, CI/CD World!', 'version': '1.0.0'}

@app.route('/health')
def health():
    return {'status': 'OK', 'timestamp': os.get_current_time()}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 5000)))