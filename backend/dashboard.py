from flask import Blueprint, jsonify, request
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

            if not folder_name:
                return jsonify({'message': 'Folder name is required'}), 400
            
            # Generate Random Code
            clean_name = folder_name.replace(" ", "")[:3].upper()
            if len(clean_name) < 3: clean_name = "SUB"
            random_num = random.randint(1000, 9999)
            generated_code = f"{clean_name}-{random_num}"

            # Set Default Lecturer ID
            default_lecturer_id = 1

            # Insert name, code, AND lecturer_id
            query = """
                INSERT INTO subjects (name, code, lecturer_id, created_at) 
                VALUES (%s, %s, %s, NOW())
            """
            cursor.execute(query, (folder_name, generated_code, default_lecturer_id))
            conn.commit()

            return jsonify({'message': 'Folder created successfully', 'id': cursor.lastrowid}), 201


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
            data = request.get_json()
            file_name = data.get('name') 
            
            if not file_name:
                return jsonify({'message': 'File name is required'}), 400

            query = """
                INSERT INTO classes (subject_id, schedule, created_at) 
                VALUES (%s, %s, NOW())
            """
            cursor.execute(query, (subject_id, file_name))
            conn.commit()

            return jsonify({'message': 'File created successfully', 'id': cursor.lastrowid}), 201


        # Fetch files for the given subject_id
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
        print(f"Received UPDATE request for Subject ID: {subject_id}") # ⭐ DEBUG PRINT
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        data = request.get_json()
        new_name = data.get('name')

        if not new_name:
            return jsonify({'message': 'Name is required'}), 400

        # Update the name in the database
        cursor.execute("UPDATE subjects SET name = %s WHERE id = %s", (new_name, subject_id))
        conn.commit()

        print(f"Rows affected: {cursor.rowcount}") # DEBUG PRINT

        if cursor.rowcount == 0:
            return jsonify({'message': 'Folder not found'}), 404

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
        print(f"Received UPDATE request for Class ID: {class_id}") # DEBUG PRINT
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        data = request.get_json()
        new_name = data.get('name')

        if not new_name:
            return jsonify({'message': 'Name is required'}), 400

        # Update the schedule (which acts as the file name) in the database
        cursor.execute("UPDATE classes SET schedule = %s WHERE id = %s", (new_name, class_id))
        conn.commit()

        if cursor.rowcount == 0:
            return jsonify({'message': 'File not found'}), 404

        return jsonify({'message': 'File updated successfully'}), 200

    except mysql.connector.Error as err:
        print(f"Database Error: {err}")
        return jsonify({'message': f'Database error: {err}'}), 500
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()


# DELETE FOLDER (DELETE)
@dashboard_bp.route('/subjects/<int:subject_id>', methods=['DELETE'])
def delete_subject(subject_id):
    conn = None
    try:
        print(f"Received DELETE request for Subject ID: {subject_id}")
        conn = get_db_connection()
        cursor = conn.cursor()

        # Delete all files inside this folder first (to prevent errors)
        cursor.execute("DELETE FROM classes WHERE subject_id = %s", (subject_id,))
        
        # Delete the folder itself
        cursor.execute("DELETE FROM subjects WHERE id = %s", (subject_id,))
        conn.commit()

        if cursor.rowcount == 0:
            return jsonify({'message': 'Folder not found or already deleted'}), 404

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
        print(f"Received DELETE request for Class ID: {class_id}")
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("DELETE FROM classes WHERE id = %s", (class_id,))
        conn.commit()

        if cursor.rowcount == 0:
            return jsonify({'message': 'File not found or already deleted'}), 404

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