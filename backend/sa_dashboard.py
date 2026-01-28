from flask import Blueprint, request, jsonify
import mysql.connector
import hashlib
from flask_bcrypt import Bcrypt
import os
from dotenv import load_dotenv

sa_dashboard_bp = Blueprint('sa_dashboard', __name__)
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

def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()

def insert_log(conn, user_id, action_type, target_entity, target_id=None, description=None):
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO logs (user_id, action_type, target_entity, target_id, description)
        VALUES (%s, %s, %s, %s, %s)
    """, (user_id, action_type, target_entity, target_id, description))
    conn.commit()
    cursor.close()
    
    
@sa_dashboard_bp.route("/sa/add", methods=["POST"])
def add_superadmin():
    data = request.json
    username = data.get("username")
    email = data.get("email")
    password = data.get("password")
    role = data.get("role", "superadmin")
    user_id = data.get("user_id")

    if not username or not email or not password or not user_id:
        return jsonify({"error": "Missing fields"}), 400

    hashed_password = hash_password(password)

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)  # <- dictionary=True here

    try:
        cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
        if cursor.fetchone():
            return jsonify({"error": "Email already exists"}), 409

        cursor.execute("""
            INSERT INTO users (username, email, password, role)
            VALUES (%s, %s, %s, %s)
        """, (username, email, hashed_password, role))
        db.commit()
        new_admin_id = cursor.lastrowid

        # Get admin's name performing this action
        cursor.execute("SELECT username FROM users WHERE id = %s", (user_id,))
        user_row = cursor.fetchone()
        admin_name = user_row['username'] if user_row else f"User ID {user_id}"

        # Insert log
        insert_log(
            conn=db,
            user_id=user_id,
            action_type="CREATE",
            target_entity="users",
            target_id=new_admin_id,
            description=f"{admin_name} added a new Super Admin: {username}"
        )

        return jsonify({"message": "Super Admin added successfully"}), 200
    except Exception as e:
        print(e)
        return jsonify({"error": "Failed to add Super Admin"}), 500
    finally:
        cursor.close()
        db.close()


@sa_dashboard_bp.route("/sa/stats/users", methods=["GET"])
def get_user_stats():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Total users
        cursor.execute("SELECT COUNT(*) AS total FROM users")
        total_users = cursor.fetchone()["total"]

        # Users until yesterday
        cursor.execute("""
            SELECT COUNT(*) AS yesterday_total
            FROM users
            WHERE created_at < CURDATE()
        """)
        yesterday_total = cursor.fetchone()["yesterday_total"]

        # Calculate growth %
        if yesterday_total == 0:
            growth = 100.0 if total_users > 0 else 0.0
        else:
            growth = ((total_users - yesterday_total) / yesterday_total) * 100

        return jsonify({
            "total_users": total_users,
            "growth_percentage": round(growth, 1)
        }), 200

    except Exception as e:
        print("[ERROR] Fetch user stats failed:", e)
        return jsonify({"message": "Failed to fetch user stats"}), 500
    finally:
        cursor.close()
        conn.close()

@sa_dashboard_bp.route("/sa/stats/admins", methods=["GET"])
def get_admin_stats():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Total superadmins
        cursor.execute("""
            SELECT COUNT(*) AS total
            FROM users
            WHERE role = 'superadmin'
        """)
        total_admins = cursor.fetchone()["total"]

        # Superadmins until yesterday
        cursor.execute("""
            SELECT COUNT(*) AS yesterday_total
            FROM users
            WHERE role = 'superadmin' AND created_at < CURDATE()
        """)
        yesterday_total = cursor.fetchone()["yesterday_total"]

        # Calculate growth %
        if yesterday_total == 0:
            growth = 100.0 if total_admins > 0 else 0.0
        else:
            growth = ((total_admins - yesterday_total) / yesterday_total) * 100

        return jsonify({
            "total_admins": total_admins,
            "growth_percentage": round(growth, 1)
        }), 200

    except Exception as e:
        print("[ERROR] Fetch admin stats failed:", e)
        return jsonify({"message": "Failed to fetch admin stats"}), 500
    finally:
        cursor.close()
        conn.close()

@sa_dashboard_bp.route("/sa/stats/students", methods=["GET"])
def get_student_stats():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Total students
        cursor.execute("SELECT COUNT(*) as total FROM students")
        total_students = cursor.fetchone()['total']

        # Students yesterday
        cursor.execute("""
            SELECT COUNT(*) as total_yesterday
            FROM students
            WHERE DATE(created_at) = CURDATE() - INTERVAL 1 DAY
        """)
        total_yesterday = cursor.fetchone()['total_yesterday']

        # Growth %
        growth_percent = 0.0
        if total_yesterday > 0:
            growth_percent = ((total_students - total_yesterday) / total_yesterday) * 100

        return jsonify({
            "total": total_students,
            "growth_percent": growth_percent
        }), 200

    except Exception as e:
        print("[ERROR] Fetch student stats failed:", e)
        return jsonify({"message": "Failed to fetch stats"}), 500
    finally:
        cursor.close()
        conn.close()


@sa_dashboard_bp.route("/sa/user/<int:user_id>", methods=["GET"])
def get_user(user_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("""
            SELECT username, email
            FROM users
            WHERE id = %s
        """, (user_id,))

        user = cursor.fetchone()
        if not user:
            return jsonify({"message": "User not found"}), 404

        return jsonify(user), 200

    except Exception as e:
        print("[ERROR] Fetch user failed:", e)
        return jsonify({"message": "Failed to fetch user"}), 500
    finally:
        cursor.close()
        conn.close()

 
@sa_dashboard_bp.route('/sa/logout', methods=['POST'])
def logout():
    data = request.get_json() or {}
    user_id = data.get("user_id")

    if not user_id:
        return jsonify({"message": "User ID is required"}), 400

    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Get the user's name
        cursor.execute("SELECT username FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        if not user:
            return jsonify({"message": "User not found"}), 404

        username = user['username']

        # Insert log for sign out with username
        insert_log(
            conn=conn,
            user_id=user_id,
            action_type="LOGOUT",
            target_entity="users",
            target_id=user_id,
            description=f"{username} signed out"
        )

        return jsonify({"message": "Sign out logged successfully"}), 200

    except Exception as e:
        print(f"[ERROR] Sign out logging failed: {e}")
        return jsonify({"message": "Failed to log sign out"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn and conn.is_connected():
            conn.close()
