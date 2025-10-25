from flask import Blueprint, request, jsonify
import mysql.connector
from flask_bcrypt import Bcrypt
import os
from dotenv import load_dotenv

signup_bp = Blueprint('signup', __name__)
load_dotenv()
bcrypt = Bcrypt()

db_config = {
    'host': os.getenv('DB_HOST'),
    'port': os.getenv('DB_PORT'),
    'user': os.getenv('DB_USERNAME'),
    'password': os.getenv('DB_PASSWORD'),
    'database': os.getenv('DB_DATABASE')
}

def get_db_connection():
    return mysql.connector.connect(
        host=db_config['host'],
        port=int(db_config['port']),
        user=db_config['user'],
        password=db_config['password'],
        database=db_config['database']
    )

@signup_bp.route('/signup', methods=['POST'])
def signup():
    data = request.get_json()

    if not data:
        return jsonify({'message': 'No data provided'}), 400

    username = data.get('username')
    email = data.get('email')
    password = data.get('password')

    if not all([username, email, password]):
        return jsonify({'message': 'Missing username, email, or password'}), 400

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM users WHERE username = %s OR email = %s", (username, email))
        existing_user = cursor.fetchone()

        if existing_user:
            return jsonify({'message': 'Username or email already exists'}), 409

        hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')

        sql = "INSERT INTO users (username, email, password) VALUES (%s, %s, %s)"
        cursor.execute(sql, (username, email, hashed_password))
        conn.commit()

        return jsonify({'message': 'User registered successfully'}), 201

    except mysql.connector.Error as err:
        print(f"Database Error: {err}")
        return jsonify({'message': 'Database error occurred during registration'}), 500

    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return jsonify({'message': 'An internal server error occurred'}), 500

    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()
