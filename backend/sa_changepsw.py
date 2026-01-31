from flask import Blueprint, request, jsonify
import mysql.connector
import hashlib
from flask_bcrypt import Bcrypt
import os
from dotenv import load_dotenv
from flask import request, jsonify
from flask_bcrypt import Bcrypt

sa_changepsw_bp = Blueprint('sa_changepsw', __name__)
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

@sa_changepsw_bp.route('/sa/users/change-password', methods=['POST'])
def change_password():
    data = request.json
    user_id = data.get("user_id")
    current_password = data.get("current_password")
    new_password = data.get("new_password")

    if not user_id or not current_password or not new_password:
        return jsonify({"message": "Missing fields"}), 400

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    try:
        # Get user by ID
        cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        if not user:
            return jsonify({"message": "User not found"}), 404

        # Compare current password
        if not bcrypt.check_password_hash(user['password'], current_password):
            return jsonify({"message": "Current password is incorrect"}), 400

        # Hash new password
        hashed_new_password = bcrypt.generate_password_hash(new_password).decode('utf-8')

        # Update password in database
        cursor.execute(
            "UPDATE users SET password = %s WHERE id = %s",
            (hashed_new_password, user_id)
        )
        db.commit()

        return jsonify({"message": "Password updated successfully"}), 200

    except Exception as e:
        print("Error:", e)
        return jsonify({"message": "Failed to update password"}), 500

    finally:
        cursor.close()
        db.close()
