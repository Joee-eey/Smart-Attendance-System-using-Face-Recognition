from flask import Blueprint, jsonify
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

@dashboard_bp.route('/subjects', methods=['GET'])
def get_subjects():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

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


@dashboard_bp.route('/subjects/<int:subject_id>/files', methods=['GET'])
def get_subject_files(subject_id):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

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
