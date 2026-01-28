from flask import Blueprint, request, jsonify
import mysql.connector
from flask_bcrypt import Bcrypt
import os
from dotenv import load_dotenv

sa_login_bp = Blueprint('sa_login', __name__)
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

def insert_log(conn, user_id, action_type, target_entity, target_id=None, description=None):
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO logs (user_id, action_type, target_entity, target_id, description)
        VALUES (%s, %s, %s, %s, %s)
    """, (user_id, action_type, target_entity, target_id, description))
    conn.commit()
    cursor.close()
    

@sa_login_bp.route('/sa/login', methods=['POST'])
def superadmin_login():
    data = request.get_json()

    if not data:
        return jsonify({'message': 'No data provided'}), 400

    email = data.get('email')
    password = data.get('password')

    if not email or not password:
        return jsonify({'message': 'Missing email or password'}), 400

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            "SELECT * FROM users WHERE email = %s AND role = 'superadmin'",
            (email,)
        )
        user = cursor.fetchone()

        if not user:
            return jsonify({
                'message': 'Super Admin account not found'
            }), 404

        if bcrypt.check_password_hash(user['password'], password):

            insert_log(
                conn=conn,
                user_id=user['id'],
                action_type="LOGIN",
                target_entity="users",
                target_id=user['id'],
                description=f"{user['username']} logged in to Cheese!"
            )

            return jsonify({
                'message': 'Super Admin login successful',
                'user': {
                    'id': user['id'],
                    'email': user['email'],
                    'role': user['role']
                }
            }), 200
        else:
            return jsonify({'message': 'Incorrect password'}), 401

    except mysql.connector.Error as err:
        print(f"Database Error: {err}")
        return jsonify({'message': 'Database error occurred'}), 500

    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()
