from flask import Blueprint, jsonify, request, send_from_directory, session
import requests
from datetime import datetime
import random
import mysql.connector
import os
from dotenv import load_dotenv


dashboard_bp = Blueprint('dashboard', __name__)
load_dotenv()

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

@dashboard_bp.route('/subjects', methods=['GET', 'POST'])
def handle_subjects():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Handle Creating a New Folder (POST)
        if request.method == 'POST':
            data = request.get_json()
            folder_name = data.get('name')
            user_id = data.get('user_id')  # <-- get it from Flutter request

            if not folder_name or not user_id:
                return jsonify({'message': 'Folder name and user_id are required'}), 400

            # Generate random code
            clean_name = folder_name.replace(" ", "")[:3].upper()
            if len(clean_name) < 3:
                clean_name = "SUB"
            random_num = random.randint(1000, 9999)
            generated_code = f"{clean_name}-{random_num}"

            # Insert into database
            query = """
                INSERT INTO subjects (name, code, lecturer_id, created_at) 
                VALUES (%s, %s, %s, NOW())
            """
            cursor.execute(query, (folder_name, generated_code, user_id))
            conn.commit()

            subject_id = cursor.lastrowid
            cursor.execute("SELECT username FROM users WHERE id = %s", (user_id,))
            user_row = cursor.fetchone()
            user_name = user_row['username'] if user_row else f"User ID {user_id}"

            # Insert log
            insert_log(
                conn=conn,
                user_id=user_id,
                action_type="CREATE",
                target_entity="subjects",
                target_id=subject_id,
                description=f"{user_name} created subject '{folder_name}'"
            )

            return jsonify({'message': 'Folder created successfully', 'id': subject_id}), 201


        cursor.execute("SELECT id, name, created_at FROM subjects ORDER BY name ASC")
        subjects = cursor.fetchall()

        for subject in subjects:
            subject['created_at'] = subject['created_at'].strftime('%d/%m/%Y')
            print(f"Subject: {subject}") 

        return jsonify(subjects), 200

    except mysql.connector.Error as err:
        print(f"Database Error: {err}")
        return jsonify({'message': 'Database error occurred while fetching subjects'}), 500

    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return jsonify({'message': 'An internal server error occurred'}), 500

    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()

@dashboard_bp.route('/subjects/<int:subject_id>/files', methods=['GET', 'POST'])
def handle_subject_files(subject_id):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Handle Creating a New File (POST)
        if request.method == 'POST':
            # Get user_id from query parameters
            user_id = request.args.get('user_id', type=int)

            data = request.get_json()
            file_name = data.get('name') 
            
            if not file_name:
                return jsonify({'message': 'File name is required'}), 400
            if not user_id:
                return jsonify({'message': 'User ID is required'}), 400

            # Insert file
            query = """
                INSERT INTO classes (subject_id, schedule, created_at) 
                VALUES (%s, %s, NOW())
            """
            cursor.execute(query, (subject_id, file_name))
            conn.commit()
            class_id = cursor.lastrowid

            cursor.execute("SELECT username FROM users WHERE id = %s", (user_id,))
            user_row = cursor.fetchone()
            user_name = user_row['username'] if user_row else f"User ID {user_id}"

            # Insert log
            insert_log(
                conn=conn,
                user_id=user_id,
                action_type="CREATE",
                target_entity="classes",
                target_id=class_id,
                description=f"{user_name} created class '{file_name}' in subject ID {subject_id}"
            )

            return jsonify({'message': 'File created successfully', 'id': class_id}), 201

        cursor.execute("""
            SELECT id, schedule, created_at 
            FROM classes
            WHERE subject_id = %s
            ORDER BY schedule ASC
        """, (subject_id,))
        files = cursor.fetchall()

        for file in files:
            file['created_at'] = file['created_at'].strftime('%d/%m/%Y')
            print(f"File: {file}")

        return jsonify(files), 200

    except mysql.connector.Error as err:
        print(f"Database Error: {err}")
        return jsonify({'message': 'Database error occurred while fetching files'}), 500

    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return jsonify({'message': 'An internal server error occurred'}), 500

    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()


# UPDATE FOLDER (SUBJECT)
@dashboard_bp.route('/subjects/<int:subject_id>', methods=['PUT'])
def update_subject(subject_id):
    conn = None
    try:
        print(f"Received UPDATE request for Subject ID: {subject_id}")  # ⭐ DEBUG PRINT
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        data = request.get_json()
        new_name = data.get('name')
        user_id = data.get('user_id')  # <-- pass this from Flutter app just like in createFolder

        if not new_name or not user_id:
            return jsonify({'message': 'Name and user_id are required'}), 400

        # Fetch current name for logging
        cursor.execute("SELECT name FROM subjects WHERE id = %s", (subject_id,))
        old_subject = cursor.fetchone()
        if not old_subject:
            return jsonify({'message': 'Folder not found'}), 404

        old_name = old_subject['name']

        # Update the name in the database
        cursor.execute("UPDATE subjects SET name = %s WHERE id = %s", (new_name, subject_id))
        conn.commit()

        print(f"Rows affected: {cursor.rowcount}")  # DEBUG PRINT
        cursor.execute("SELECT username FROM users WHERE id = %s", (user_id,))
        user_row = cursor.fetchone()
        user_name = user_row['username'] if user_row else f"User ID {user_id}"

        # Insert log for update
        insert_log(
            conn=conn,
            user_id=user_id,
            action_type="UPDATE",
            target_entity="subjects",
            target_id=subject_id,
            description=f"{user_name} updated subject name from '{old_name}' to '{new_name}'"
        )

        return jsonify({'message': 'Folder updated successfully'}), 200

    except mysql.connector.Error as err:
        print(f"Database Error: {err}")
        return jsonify({'message': f'Database error: {err}'}), 500
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()

# UPDATE FILE (CLASS)
@dashboard_bp.route('/classes/<int:class_id>', methods=['PUT'])
def update_class(class_id):
    conn = None
    try:
        user_id = request.args.get('user_id', type=int)
        data = request.get_json()
        new_name = data.get('name')

        if not new_name:
            return jsonify({'message': 'Name is required'}), 400

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Get old name for logging
        cursor.execute("SELECT schedule FROM classes WHERE id = %s", (class_id,))
        file = cursor.fetchone()
        if not file:
            return jsonify({'message': 'File not found'}), 404

        old_name = file['schedule']

        # Update file name
        cursor.execute("UPDATE classes SET schedule = %s WHERE id = %s", (new_name, class_id))
        conn.commit()

        cursor.execute("SELECT username FROM users WHERE id = %s", (user_id,))
        user_row = cursor.fetchone()
        user_name = user_row['username'] if user_row else f"User ID {user_id}"

        # Insert log
        insert_log(
            conn=conn,
            user_id=user_id,
            action_type="UPDATE",
            target_entity="classes",
            target_id=class_id,
            description=f"{user_name} renamed class from '{old_name}' to '{new_name}'"
        )

        return jsonify({'message': 'File updated successfully'}), 200

    except Exception as e:
        print(f"Error updating file: {e}")
        return jsonify({'message': str(e)}), 500
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()


# DELETE FOLDER (DELETE)
@dashboard_bp.route('/subjects/<int:subject_id>', methods=['DELETE'])
def delete_subject(subject_id):
    conn = None
    try:
        user_id = request.args.get('user_id', type=int)
        print(f"Received DELETE request for Subject ID: {subject_id} by User ID: {user_id}")

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Get folder info for logging
        cursor.execute("SELECT name FROM subjects WHERE id = %s", (subject_id,))
        folder = cursor.fetchone()
        if not folder:
            return jsonify({'message': 'Folder not found'}), 404

        folder_name = folder['name']

        # Delete all files in folder
        cursor.execute("DELETE FROM classes WHERE subject_id = %s", (subject_id,))
        # Delete folder
        cursor.execute("DELETE FROM subjects WHERE id = %s", (subject_id,))
        conn.commit()

        cursor.execute("SELECT username FROM users WHERE id = %s", (user_id,))
        user_row = cursor.fetchone()
        user_name = user_row['username'] if user_row else f"User ID {user_id}"

        # Insert log
        insert_log(
            conn=conn,
            user_id=user_id,
            action_type="DELETE",
            target_entity="subjects",
            target_id=subject_id,
            description=f"{user_name} deleted subject '{folder_name}'"
        )

        return jsonify({'message': 'Folder deleted successfully'}), 200

    except Exception as e:
        print(f"Error deleting subject: {e}")
        return jsonify({'message': str(e)}), 500
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()



# DELETE FILE (DELETE)
@dashboard_bp.route('/classes/<int:class_id>', methods=['DELETE'])
def delete_class(class_id):
    conn = None
    try:
        user_id = request.args.get('user_id', type=int)
        print(f"Received DELETE request for Class ID: {class_id} by User ID: {user_id}")

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Get file info for logging
        cursor.execute("SELECT schedule FROM classes WHERE id = %s", (class_id,))
        file = cursor.fetchone()
        if not file:
            return jsonify({'message': 'File not found'}), 404

        schedule_name = file['schedule']

        # Delete file
        cursor.execute("DELETE FROM classes WHERE id = %s", (class_id,))
        conn.commit()

        cursor.execute("SELECT username FROM users WHERE id = %s", (user_id,))
        user_row = cursor.fetchone()
        user_name = user_row['username'] if user_row else f"User ID {user_id}"

        # Insert log
        insert_log(
            conn=conn,
            user_id=user_id,
            action_type="DELETE",
            target_entity="classes",
            target_id=class_id,
            description=f"{user_name} deleted class '{schedule_name}'"
        )

        return jsonify({'message': 'File deleted successfully'}), 200

    except Exception as e:
        print(f"Error deleting class: {e}")
        return jsonify({'message': str(e)}), 500
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()


# DELETE: Removes from DB AND Face++ Cloud
@dashboard_bp.route('/students/<int:student_id>', methods=['DELETE'])
def delete_student(student_id):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Get the Face Token BEFORE deleting the student
        cursor.execute("SELECT face_token, face_image_url FROM students WHERE id = %s", (student_id,))
        student = cursor.fetchone()

        if not student:
            return jsonify({'message': 'Student not found'}), 404

        face_token = student['face_token']
        image_path = student['face_image_url']

        # Delete from Face++ Cloud (Remove face from FaceSet)
        if face_token:
            print(f"[DEBUG] Removing face {face_token} from Cloud...", flush=True)
            requests.post(
                "https://api-us.faceplusplus.com/facepp/v3/faceset/removeface",
                data={
                    "api_key": os.getenv("FACEPP_API_KEY"),
                    "api_secret": os.getenv("FACEPP_API_SECRET"),
                    "faceset_token": os.getenv("FACESET_TOKEN"),
                    "face_tokens": face_token
                }
            )

        # Delete Local Image File (Optional but good for cleanup)
        if image_path and os.path.exists(image_path):
            os.remove(image_path)
            print(f"[DEBUG] Deleted local file: {image_path}", flush=True)

        # Delete Attendance Records (Foreign Key Constraint)
        cursor.execute("DELETE FROM attendance WHERE student_id = %s", (student_id,))

        # Finally, Delete Student from Database
        cursor.execute("DELETE FROM students WHERE id = %s", (student_id,))
        conn.commit()

        return jsonify({'message': 'Student and Face Data deleted successfully'}), 200

    except Exception as e:
        print(f"[ERROR] Deleting student: {e}", flush=True)
        return jsonify({'message': str(e)}), 500
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()


@dashboard_bp.route("/enrollment/bulk", methods=["POST"])
def bulk_enroll_students():
    data = request.json
    student_ids = data.get("student_ids", [])
    subject_id = data.get("folder_id")

    if not student_ids or not subject_id:
        return jsonify({"error": "Invalid data"}), 400

    conn = get_db_connection()
    cursor = conn.cursor()

    sql = """
        INSERT IGNORE INTO enrollments (student_id, subject_id)
        VALUES (%s, %s)
    """

    values = [(sid, subject_id) for sid in student_ids]
    cursor.executemany(sql, values)
    conn.commit()

    return jsonify({
        "message": f"{cursor.rowcount} students enrolled"
    }), 200


@dashboard_bp.route("/uploads/<filename>")
def uploaded_file(filename):
    uploads_dir = os.path.join(os.getcwd(), "uploads")
    return send_from_directory(uploads_dir, filename)

@dashboard_bp.route("/students", methods=["GET"])
def get_students():
    keyword = request.args.get("search", "").strip()
    subject_id = request.args.get("subject_id", type=int)  # optional filter by subject

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Base SQL to get students with their primary face image
        sql = """
            SELECT s.id, s.name, s.student_card_id, s.course,
                   sf.face_image_url AS face_image_url
            FROM students s
            LEFT JOIN student_faces sf 
                   ON sf.student_id = s.id AND sf.is_primary = TRUE
        """
        params = []

        # Add search filter if keyword provided
        if keyword:
            sql += " WHERE s.name LIKE %s OR s.student_card_id LIKE %s"
            like_keyword = f"%{keyword}%"
            params.extend([like_keyword, like_keyword])

        sql += " ORDER BY s.name ASC LIMIT 50"
        cursor.execute(sql, params)
        students = cursor.fetchall()

        # Convert local file paths to full URLs for Flutter
        for student in students:
            if student['face_image_url']:
                student['face_image_url'] = request.host_url.rstrip("/") + "/uploads/" + os.path.basename(student['face_image_url'])
            else:
                student['face_image_url'] = None

        # If subject_id provided, mark enrolled students
        if subject_id:
            cursor.execute(
                "SELECT student_id FROM enrollments WHERE subject_id = %s", (subject_id,)
            )
            enrolled_ids = {row['student_id'] for row in cursor.fetchall()}

            for student in students:
                student['enrolled'] = student['id'] in enrolled_ids

        return jsonify(students), 200

    except mysql.connector.Error as e:
        return jsonify({"error": str(e)}), 500

    finally:
        if 'conn' in locals() and conn.is_connected():
            cursor.close()
            conn.close()


@dashboard_bp.route("/remove_student", methods=["POST"])
def remove_student():
    student_id = request.json.get("student_id")
    subject_id = request.json.get("subject_id")

    if not student_id or not subject_id:
        return jsonify({"error": "Missing student_id or subject_id"}), 400

    conn = None
    cursor = None

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Delete from enrollments
        cursor.execute("""
            DELETE FROM enrollments
            WHERE student_id = %s AND subject_id = %s
        """, (student_id, subject_id))

        if cursor.rowcount == 0:
            return jsonify({"error": "Enrollment not found"}), 404

        conn.commit()
        return jsonify({"message": "Student removed from subject successfully"}), 200

    except Exception as e:
        if conn:
            conn.rollback()
        print(f"[ERROR] Failed to remove student: {e}")
        return jsonify({"error": str(e)}), 500

    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()