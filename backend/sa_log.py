from flask import Blueprint, request, jsonify
import mysql.connector
from flask_bcrypt import Bcrypt
import os
from dotenv import load_dotenv

sa_log_bp = Blueprint('sa_log', __name__)
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

@sa_log_bp.route("/sa/logs", methods=["GET"])
def get_logs():
    search_query = request.args.get("search", "").strip()
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        if search_query:
            like_param = f"%{search_query}%"
            sql = """
                SELECT 
                    l.log_id,
                    l.action_type,
                    l.description,
                    l.created_at
                FROM logs l
                WHERE l.action_type LIKE %s OR l.description LIKE %s
                ORDER BY l.created_at DESC
            """
            cursor.execute(sql, (like_param, like_param))
        else:
            sql = """
                SELECT 
                    l.log_id,
                    l.action_type,
                    l.description,
                    l.created_at
                FROM logs l
                ORDER BY l.created_at DESC
            """
            cursor.execute(sql)

        logs = cursor.fetchall()
        return jsonify(logs), 200

    except Exception as e:
        print("[ERROR] Fetch logs failed:", e)
        return jsonify({"message": "Failed to fetch logs"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

@sa_log_bp.route("/sa/logs/purge", methods=["POST"])
def purge_logs():
    """
    Handles:
    - Auto-purge config changes (manual = false, enable_auto may be true/false)
    - Manual purge trigger (manual = true)
    Deletes logs older than `retention_days` when:
      - manual = true, OR
      - manual = false AND enable_auto = true
    """
    payload = request.get_json() or {}
    manual = bool(payload.get("manual", False))
    enable_auto = bool(payload.get("enable_auto", False))
    retention_days = payload.get("retention_days", 30)

    try:
        retention_days = int(retention_days)
    except (TypeError, ValueError):
        retention_days = 30

    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        if manual:
            # MANUAL PURGE: Delete every single log
            delete_sql = "DELETE FROM logs"
            cursor.execute(delete_sql)
        else:
            # AUTO-PURGE: Only delete if enabled and older than X days
            if not enable_auto:
                return jsonify({
                    "message": "Settings updated. Auto-purge is OFF.",
                    "deleted": 0
                }), 200
            
            delete_sql = "DELETE FROM logs WHERE created_at < (NOW() - INTERVAL %s DAY)"
            cursor.execute(delete_sql, (retention_days,))

        deleted_count = cursor.rowcount or 0
        conn.commit()

        return jsonify({
            "message": "Logs purged successfully." if manual else "Auto-purge applied.",
            "deleted": int(deleted_count),
            "retention_days": retention_days,
        }), 200

    except Exception as e:
        print("[ERROR] Purge logs failed:", e)
        if conn:
            conn.rollback()
        return jsonify({"message": "Failed to purge logs"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()