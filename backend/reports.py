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
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({"error": "User ID is required"}), 400
    
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)
    try:
        query = "SELECT id, code, name FROM subjects WHERE lecturer_id = %s"
        cursor.execute(query, (user_id,))
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
    subject_id_arg = request.args.get('subject_id')
    class_id = request.args.get('class_id')
    selected_date_str = request.args.get('date') 

    #if not class_id or not selected_date_str:
        #return jsonify({"error": "class_id and date are required"}), 400

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    try:
        # Get Subject
        if class_id:
            cursor.execute("SELECT subject_id FROM classes WHERE id = %s", (class_id,))
            row = cursor.fetchone()
            subject_id = row['subject_id'] if row else None
        else:
            subject_id = subject_id_arg

        if not subject_id:
            return jsonify({"error": "Subject or Class ID required"}), 400

        # Total Enrolled
        cursor.execute("SELECT COUNT(*) as total FROM enrollments WHERE subject_id = %s", (subject_id,))
        total_enrolled = cursor.fetchone()['total'] or 0

        # Overall Average Rate (Since Start)
        cursor.execute("""
            SELECT 
                COUNT(CASE WHEN a.status = 'present' THEN 1 END) as total_presents,
                COUNT(DISTINCT a.date, a.class_id) as total_sessions
            FROM attendance a
            JOIN classes c ON a.class_id = c.id
            WHERE c.subject_id = %s
        """, (subject_id,))
        overall_stats = cursor.fetchone()
        total_sessions_all_time = overall_stats['total_sessions'] or 0
        total_possible_spots = total_enrolled * total_sessions_all_time
        avg_rate_val = round((overall_stats['total_presents'] / total_possible_spots) * 100, 1) if total_possible_spots > 0 else 0.0

        # Daily Rate (Selected Date)
        # present_today = 0
        # daily_rate = 0.0

        # Daily Rate & Total Present (Selected Date)
        if class_id:
            # Stats for specific session
            cursor.execute("SELECT COUNT(*) as count FROM attendance WHERE class_id = %s AND date = %s AND status = 'present'", (class_id, selected_date_str))
            present_today = cursor.fetchone()['count'] or 0
            daily_rate = round((present_today / total_enrolled) * 100, 1) if total_enrolled > 0 else 0
        else:
            # Stats for ALL sessions on that day (Combined Daily Rate)
            cursor.execute("""
                SELECT COUNT(CASE WHEN a.status='present' THEN 1 END) as p_count,
                       COUNT(DISTINCT class_id) as s_count
                FROM attendance a
                JOIN classes c ON a.class_id = c.id
                WHERE c.subject_id = %s AND a.date = %s
            """, (subject_id, selected_date_str))
            res = cursor.fetchone()
            present_today = res['p_count'] or 0
            s_count = res['s_count'] or 0
            total_possible_today = total_enrolled * s_count
            daily_rate = round((present_today / total_possible_today) * 100, 1) if total_possible_today > 0 else 0

        # Weekly Change Logic (Current Week vs Prev Week)
        target_date_obj = datetime.strptime(selected_date_str, '%Y-%m-%d').date()
        
        def get_week_avg(end_date):
            start_date = end_date - timedelta(days=6)
            cursor.execute("""
                SELECT COUNT(CASE WHEN a.status='present' THEN 1 END) as p,
                       COUNT(DISTINCT a.date, a.class_id) as s
                FROM attendance a
                JOIN classes c ON a.class_id = c.id
                WHERE c.subject_id = %s AND a.date BETWEEN %s AND %s
            """, (subject_id, start_date, end_date))
            r = cursor.fetchone()

            sessions_count = r['s'] or 0
            possible = total_enrolled * sessions_count
            
            # If no sessions happened, return 0.0 instead of crashing
            if possible == 0:
                return 0.0
            return (r['p'] / possible * 100)

        current_week_avg = get_week_avg(target_date_obj)
        previous_week_avg = get_week_avg(target_date_obj - timedelta(days=7))
        
        if previous_week_avg > 0:
            change_val = round(((current_week_avg - previous_week_avg) / previous_week_avg) * 100, 1)
        else:
            change_val = 0.0
            
        change_rate = f"{'+' if change_val >= 0 else ''}{change_val}%"

        # Trends + Sessions
        cursor.execute("""
            SELECT MIN(a.date) as first_date
            FROM attendance a
            JOIN classes c ON a.class_id = c.id
            WHERE c.subject_id = %s
        """, (subject_id,))
        row = cursor.fetchone()

        start_date = row['first_date'] if row and row['first_date'] else selected_date_str
        start_date_obj = datetime.strptime(start_date, '%Y-%m-%d').date() if isinstance(start_date, str) else start_date
        target_date = datetime.strptime(selected_date_str, '%Y-%m-%d').date()

        day_count = max((target_date - start_date_obj).days + 1, 7)

        trends = []

        for i in range(day_count - 1, -1, -1):
            curr_d = target_date - timedelta(days=i)
            curr_d_str = curr_d.strftime('%Y-%m-%d')

            # DAILY TOTAL
            cursor.execute("""
                SELECT COUNT(CASE WHEN a.status='present' THEN 1 END) as present_count,
                       COUNT(DISTINCT a.class_id) as session_count
                FROM attendance a
                JOIN classes c ON a.class_id = c.id
                WHERE c.subject_id = %s AND a.date = %s
            """, (subject_id, curr_d_str))

            res = cursor.fetchone()
            p_count = res['present_count'] or 0
            s_count = res['session_count'] or 0
            rate = round((p_count / (total_enrolled * s_count)) * 100, 1) if s_count > 0 and total_enrolled > 0 else 0

            # Session Breakdown
            cursor.execute("""
                SELECT a.class_id,
                       COUNT(CASE WHEN a.status='present' THEN 1 END) as present
                FROM attendance a
                JOIN classes c ON a.class_id = c.id
                WHERE c.subject_id = %s AND a.date = %s
                GROUP BY a.class_id
                ORDER BY a.class_id
            """, (subject_id, curr_d_str))

            session_rows = cursor.fetchall()

            sessions = []
            for idx, s in enumerate(session_rows, start=1):
                sessions.append({
                    "session_no": idx,
                    "present": s['present'],
                    "total": total_enrolled
                })

            trends.append({
                "day_name": curr_d.strftime('%a'),
                "date": curr_d_str,
                "rate": rate,
                "present_count": p_count,
                "total_students": total_enrolled,
                "sessions": sessions
            })


        # Student Details
        query = """
            SELECT 
                s.name, 
                s.student_card_id as student_formal_id, 
                s.course,
                COALESCE(a.status, 'absent') as status, 
                IFNULL(DATE_FORMAT(a.created_at, '%h:%i %p'), '-') as time_in
            FROM students s
            JOIN enrollments e ON s.id = e.student_id
            LEFT JOIN attendance a ON s.id = a.student_id 
                AND a.class_id = %s 
                AND a.date = %s
            WHERE e.subject_id = %s
        """
        cursor.execute(query, (class_id, selected_date_str, subject_id))

        student_details = cursor.fetchall()
        
        return jsonify({
            "total_present": present_today,
            "avg_rate": avg_rate_val,
            "daily_rate": daily_rate,
            "change_rate": change_rate,
            "trends": trends,
            "student_details": student_details
        })
    finally:
        cursor.close()
        db.close()