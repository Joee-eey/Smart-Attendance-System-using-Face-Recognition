from flask import Blueprint, request, jsonify
import mysql.connector
from datetime import datetime, timedelta

reports_bp = Blueprint('reports_bp', __name__)

# Database connection helper
def get_db_connection():
    return mysql.connector.connect(
        host="127.0.0.1",
        user="root",
        password="Jlyh_042760", 
        database="attendance"
    )

@reports_bp.route('/api/subjects', methods=['GET'])
def get_subjects():
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)
    try:
        cursor.execute("SELECT id, code, name FROM subjects")
        subjects = cursor.fetchall()
        return jsonify(subjects)
    finally:
        cursor.close()
        db.close()

@reports_bp.route('/api/subjects/<int:subject_id>/files', methods=['GET'])
def get_subject_files(subject_id):
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)
    try:
        # Fetches classes/schedules linked to the selected subject
        cursor.execute("SELECT id, schedule FROM classes WHERE subject_id = %s", (subject_id,))
        files = cursor.fetchall()
        return jsonify(files), 200
    finally:
        cursor.close()
        db.close()

@reports_bp.route('/api/reports', methods=['GET'])
def get_report():
    class_id = request.args.get('class_id')
    selected_date = request.args.get('date') # Format: YYYY-MM-DD

    if not class_id or not selected_date:
        return jsonify({"error": "class_id and date are required"}), 400

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    try:
        # 1. Get the subject_id for this specific class
        cursor.execute("SELECT subject_id FROM classes WHERE id = %s", (class_id,))
        class_row = cursor.fetchone()
        if not class_row:
            return jsonify({"error": "Class not found"}), 404
        subject_id = class_row['subject_id']

        # 2. Get total enrolled students via ENROLLMENTS table (Based on your migrate.py)
        # REMARK: We use the enrollments table to count students linked to this subject
        cursor.execute("""
            SELECT COUNT(*) as total_enrolled 
            FROM enrollments 
            WHERE subject_id = %s
        """, (subject_id,))
        total_enrolled = cursor.fetchone()['total_enrolled'] or 0

        if total_enrolled == 0:
            return jsonify({
                "total_present": 0, "avg_rate": 0, "daily_rate": 0,
                "trends": [], "student_details": []
            })

        # 3. Total Present for the selected day
        cursor.execute("""
            SELECT COUNT(*) as present_count
            FROM attendance
            WHERE class_id = %s AND date = %s AND status = 'present'
        """, (class_id, selected_date))
        total_present = cursor.fetchone()['present_count'] or 0
        daily_rate = round((total_present / total_enrolled) * 100, 1)

        # 4. Average Rate (Historical performance of this specific class)
        cursor.execute("""
            SELECT AVG(daily_present) as avg_present FROM (
                SELECT COUNT(*) as daily_present
                FROM attendance
                WHERE class_id = %s AND status = 'present'
                GROUP BY date
            ) as history
        """, (class_id,))
        avg_data = cursor.fetchone()
        avg_p_val = avg_data['avg_present'] if avg_data['avg_present'] is not None else 0
        avg_rate = round((float(avg_p_val) / total_enrolled) * 100, 1)

        # 5. Trends (Last 7 days)
        trends = []
        base_date = datetime.strptime(selected_date, '%Y-%m-%d')
        for i in range(6, -1, -1):
            target_date = (base_date - timedelta(days=i)).date()
            cursor.execute("""
                SELECT COUNT(*) as present_count
                FROM attendance
                WHERE class_id = %s AND date = %s AND status = 'present'
            """, (class_id, target_date))
            count = cursor.fetchone()['present_count'] or 0
            trends.append({
                "day": target_date.strftime('%a'), 
                "rate": round((count / total_enrolled) * 100, 1)
            })

        # 6. Student Details (Using LEFT JOIN via ENROLLMENTS)
        # REMARK: This query joins Students -> Enrollments -> Attendance
        query_students = """
            SELECT 
                s.name, 
                COALESCE(a.status, 'Absent') as status, 
                DATE_FORMAT(a.created_at, '%%h:%%i %%p') as time_in
            FROM students s
            JOIN enrollments e ON s.id = e.student_id
            LEFT JOIN attendance a ON s.id = a.student_id 
                AND a.class_id = %s 
                AND a.date = %s
            WHERE e.subject_id = %s
            ORDER BY 
                CASE WHEN status = 'Present' THEN 1 ELSE 2 END,
                s.name ASC
        """
        cursor.execute(query_students, (class_id, selected_date, subject_id))
        student_details = cursor.fetchall()

        return jsonify({
            "total_present": total_present,
            "avg_rate": avg_rate,
            "daily_rate": daily_rate,
            "trends": trends,
            "student_details": student_details
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        db.close()