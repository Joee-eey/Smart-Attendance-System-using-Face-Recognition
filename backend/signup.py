from flask import Flask, request, jsonify
import mysql.connector
from werkzeug.security import generate_password_hash

app = Flask(__name__)

# Connect to MySQL
db = mysql.connector.connect(
    host="localhost",
    user="root",
    password="yourpassword",
    database="attendance_system"
)

@app.route('/signup', methods=['POST'])
def signup():
    data = request.get_json()
    username = data.get('username')
    email = data.get('email')
    password = data.get('password')

    if not username or not email or not password:
        return jsonify({"status": "error", "message": "Missing fields"}), 400

    cursor = db.cursor(dictionary=True)

    # Check if email exists
    cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
    if cursor.fetchone():
        return jsonify({"status": "error", "message": "Email already registered"}), 400

    # Hash password and insert
    hashed_password = generate_password_hash(password)
    cursor.execute(
        "INSERT INTO users (username, email, password) VALUES (%s, %s, %s)",
        (username, email, hashed_password)
    )
    db.commit()

    return jsonify({"status": "success", "message": "User registered successfully"}), 201

if __name__ == '__main__':
    app.run(debug=True)
