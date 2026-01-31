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

# @sa_log_bp.route("/sa/logs", methods=["GET"])
# def get_logs():
#     try:
#         conn = get_db_connection()
#         cursor = conn.cursor(dictionary=True)

#         cursor.execute("""
#             SELECT 
#                 l.log_id,
#                 l.action_type,
#                 l.description,
#                 DATE_FORMAT(l.created_at, '%d %b %Y, %h:%i:%s %p') AS created_at
#             FROM logs l
#             ORDER BY l.created_at DESC
#         """)

#         logs = cursor.fetchall()

#         return jsonify(logs), 200

#     except Exception as e:
#         print("[ERROR] Fetch logs failed:", e)
#         return jsonify({"message": "Failed to fetch logs"}), 500
#     finally:
#         if cursor:
#             cursor.close()
#         if conn:
#             conn.close()


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
