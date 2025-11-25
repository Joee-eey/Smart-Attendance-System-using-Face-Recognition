from flask import Blueprint, jsonify, request
import mysql.connector
import os
from dotenv import load_dotenv
from datetime import datetime

attendance_bp = Blueprint('attendance', __name__)
load_dotenv()

db_config = {
    'host': os.getenv('DB_HOST'),
    'port': os.getenv('DB_PORT'),
    'user': os.getenv('DB_USERNAME'),
    'password': os.getenv('DB_PASSWORD'),
    'database': os.getenv('DB_DATABASE')
}

def get_db_connection():
    return mysql.connector.connect(**db_config)


@attendance_bp.route("/attendance", methods=["GET"])
def get_attendance():
    try:
        class_id = request.args.get("class_id", type=int)
        if not class_id:
            return jsonify({"error": "class_id is required"}), 400

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Find the subject for this class
        cursor.execute("SELECT subject_id FROM classes WHERE id = %s", (class_id,))
        class_row = cursor.fetchone()
        if not class_row:
            return jsonify({"error": "Class not found"}), 404
        subject_id = class_row["subject_id"]

        # Fetch students with their attendance (if any) for today
        cursor.execute("""
            SELECT 
                a.id,
                a.id,
                s.name,
                s.student_card_id,
                s.course,
                DATE_FORMAT(a.created_at, '%h:%i %p') AS time,
                a.date,
                COALESCE(a.status, 'Absent') AS status
            FROM students s
            LEFT JOIN attendance a 
                ON s.id = a.student_id 
                AND DATE(a.date) = CURDATE()
            WHERE s.subject_id = %s
            ORDER BY 
                CASE 
                    WHEN COALESCE(a.status, 'Absent') = 'Present' THEN 1
                    ELSE 2
                END,
                s.name ASC
        """, (subject_id,))

        records = cursor.fetchall()

        # Log for debugging
        print(f"[DEBUG] Attendance list for class {class_id}: {records}", flush=True)

        return jsonify(records), 200

    except Exception as e:
        print(f"[ERROR] Fetch attendance failed: {e}", flush=True)
        return jsonify({"error": str(e)}), 500

    finally:
        if 'conn' in locals() and conn.is_connected():
            cursor.close()
            conn.close()



@attendance_bp.route("/attendance/summary", methods=["GET"])
def get_attendance_summary():
    try:
        class_id = request.args.get("class_id", type=int)
        if not class_id:
            return jsonify({"error": "class_id is required"}), 400

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Get subject for this class
        cursor.execute("SELECT subject_id FROM classes WHERE id = %s", (class_id,))
        class_row = cursor.fetchone()
        if not class_row:
            return jsonify({"error": "Class not found"}), 404
        subject_id = class_row["subject_id"]

        # Count how many students are enrolled in this subject
        cursor.execute("SELECT COUNT(*) AS total_students FROM students WHERE subject_id = %s", (subject_id,))
        total_row = cursor.fetchone()
        total_students = total_row["total_students"]

        # Count how many are present today (from attendance)
        cursor.execute("""
            SELECT COUNT(DISTINCT student_id) AS present_count
            FROM attendance
            WHERE LOWER(status) = 'present' 
              AND DATE(date) = CURDATE()
              AND student_id IN (
                  SELECT id FROM students WHERE subject_id = %s
              )
        """, (subject_id,))
        present_row = cursor.fetchone()
        present_count = present_row["present_count"]

        # Absent = total - present
        absent_count = total_students - present_count

        print(f"[DEBUG] Subject {subject_id}: total={total_students}, present={present_count}, absent={absent_count}", flush=True)

        return jsonify({
            "present_count": int(present_count or 0),
            "absent_count": int(absent_count if absent_count >= 0 else 0)
        }), 200

    except Exception as e:
        print(f"[ERROR] Attendance summary: {e}", flush=True)
        return jsonify({"error": "Failed to fetch summary"}), 500

    finally:
        if 'conn' in locals() and conn.is_connected():
            cursor.close()
            conn.close()





# ⭐⭐⭐ NEW ROUTE: DELETE ATTENDANCE RECORD ⭐⭐⭐
@attendance_bp.route('/attendance/<int:attendance_id>', methods=['DELETE'])
def delete_attendance(attendance_id):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Delete the record from the 'attendance' table
        # (Assuming your table is named 'attendance')
        cursor.execute("DELETE FROM attendance WHERE id = %s", (attendance_id,))
        conn.commit()

        if cursor.rowcount == 0:
            return jsonify({'message': 'Record not found'}), 404

        return jsonify({'message': 'Attendance record deleted successfully'}), 200

    except Exception as e:
        print(f"Error deleting attendance: {e}")
        return jsonify({'message': str(e)}), 500
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()