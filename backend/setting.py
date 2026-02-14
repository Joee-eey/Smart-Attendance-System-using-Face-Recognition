from flask import Blueprint, request, jsonify
import mysql.connector
from flask_bcrypt import Bcrypt
import os
from dotenv import load_dotenv

setting_bp = Blueprint('setting', __name__)
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

@setting_bp.route('/users/upload_photo', methods=['POST'])
def upload_photo():
    user_id = request.form.get('user_id')
    file = request.files.get('image')
    
    if not file or not user_id:
        return jsonify({"message": "Missing file or user ID"}), 400

    try:
        # Create the directory if it doesn't exist to avoid FileNotFoundError
        upload_folder = 'static/uploads'
        if not os.path.exists(upload_folder):
            os.makedirs(upload_folder)

        # Get original extension (Exp: .png, .jpg)
        ext = os.path.splitext(file.filename)[1]
        filename = f"profile_{user_id}{ext}"
        filepath = os.path.join(upload_folder, filename)
        
        # Save the actual file
        file.save(filepath)
        
        # Path to store in the database (relative path)
        db_path = f"static/uploads/{filename}"

        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Ensure your 'users' table has a column named 'profile_image_url'
        cursor.execute("""
            UPDATE users 
            SET profile_image_url = %s 
            WHERE id = %s
        """, (db_path, user_id))
        
        conn.commit()
        return jsonify({"message": "Profile photo updated", "url": db_path}), 200

    except Exception as e:
        print(f"[ERROR] Upload failed: {e}")
        return jsonify({"message": str(e)}), 500
    finally:
        if 'cursor' in locals(): cursor.close()
        if 'conn' in locals(): conn.close()

@setting_bp.route('/lecturer/<int:lecturer_id>/schedule', methods=['GET'])
def get_lecturer_schedule(lecturer_id):
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # JOIN classes and subjects to get the name and time together
        query = """
            SELECT 
                c.id, 
                s.name AS course_name, 
                c.schedule AS start_time 
            FROM classes c
            JOIN subjects s ON c.subject_id = s.id
            WHERE s.lecturer_id = %s
        """
        cursor.execute(query, (lecturer_id,))
        schedule = cursor.fetchall()

        return jsonify(schedule), 200

    except Exception as e:
        print(f"[ERROR] Schedule fetch failed: {e}")
        return jsonify({"message": str(e)}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()
    
@setting_bp.route('/logout', methods=['POST'])
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


@setting_bp.route("/users/<int:user_id>", methods=["GET"])
def get_user(user_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT username, email, profile_image_url FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        if not user:
            return jsonify({"message": "User not found"}), 404
        return jsonify(user), 200
    finally:
        cursor.close()
        conn.close()

