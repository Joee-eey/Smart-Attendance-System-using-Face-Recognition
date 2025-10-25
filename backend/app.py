from flask import Flask
from flask_cors import CORS

# Import Blueprints instead of whole files
from login import login_bp
from signup import signup_bp

app = Flask(__name__)
CORS(app)

# Register routes from other files
app.register_blueprint(login_bp)
app.register_blueprint(signup_bp)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
