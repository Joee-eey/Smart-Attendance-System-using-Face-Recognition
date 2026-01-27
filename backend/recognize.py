from flask import Blueprint, request, jsonify
import mysql.connector
import requests
import os
from dotenv import load_dotenv
from datetime import date
from PIL import Image

recognize_bp = Blueprint('recognize', __name__)
load_dotenv()

# Face++ credentials
FACEPP_API_KEY = os.getenv("FACEPP_API_KEY")
FACEPP_API_SECRET = os.getenv("FACEPP_API_SECRET")
DETECT_URL = os.getenv("DETECT_URL")
SEARCH_URL = os.getenv("SEARCH_URL")
FACESET_TOKEN = os.getenv("FACESET_TOKEN")

# Database config
db_config = {
    'host': os.getenv('DB_HOST'),
    'port': int(os.getenv('DB_PORT')),
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

@recognize_bp.route("/recognize", methods=["POST"])
def recognize_face():
    image = request.files.get("image")
    if not image:
        return jsonify({"error": "No image uploaded"}), 400
    
    class_id = request.form.get("class_id")
    if not class_id:
        return jsonify({"error": "No class_id provided"}), 400

    try:
        class_id = int(class_id)
    except ValueError:
        return jsonify({"error": "Invalid class_id"}), 400

    conn = None
    cursor = None
    try:
        # Save temp image
        os.makedirs("uploads", exist_ok=True)
        temp_path = "uploads/temp_recognize.jpg"
        image.save(temp_path)

        # Resize image to max 1024x1024
        img = Image.open(temp_path)
        img.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
        img.save(temp_path, format="JPEG", quality=85)

        # Detect faces
        with open(temp_path, "rb") as img_file:
            detect_res = requests.post(
                DETECT_URL,
                data={"api_key": FACEPP_API_KEY, "api_secret": FACEPP_API_SECRET},
                files={"image_file": img_file}
            )
            detect_data = detect_res.json()

        print("===== FACE++ DETECT RESPONSE =====")
        print(detect_data)
        print("=================================")

        if "faces" not in detect_data or not detect_data["faces"]:
            return jsonify({"error": "No face detected"}), 400

        results_list = []

        # DB connection
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        for face in detect_data["faces"]:
            face_token = face["face_token"]

            # Search in faceset
            search_res = requests.post(
                SEARCH_URL,
                data={
                    "api_key": FACEPP_API_KEY,
                    "api_secret": FACEPP_API_SECRET,
                    "faceset_token": FACESET_TOKEN,
                    "face_token": face_token
                }
            )
            search_data = search_res.json()

            print("===== FACE++ SEARCH RESPONSE =====")
            print(search_data)
            print("=================================")

            if "results" not in search_data or not search_data["results"]:
                print("[WARN] Face not recognized")
                results_list.append({"error": "Face not recognized"})
                continue

            match = search_data["results"][0]
            matched_token = match["face_token"]
            confidence = match["confidence"]

            if confidence < 70:
                results_list.append({"error": "Low confidence match"})
                continue

            # Find student enrolled in this class
            cursor.execute("""
                SELECT s.id, s.name, s.course
                FROM students s
                JOIN student_faces sf ON s.id = sf.student_id
                JOIN enrollments e ON s.id = e.student_id
                JOIN classes c ON e.subject_id = c.subject_id
                WHERE sf.face_token = %s
                AND c.id = %s
            """, (matched_token, class_id))

            student = cursor.fetchone()
            if not student:
                results_list.append({"error": "Student not found"})
                continue

            # Check if attendance exists today
            cursor.execute("""
                SELECT id FROM attendance
                WHERE class_id = %s AND student_id = %s AND DATE(date) = %s
            """, (class_id, student["id"], date.today()))
            existing = cursor.fetchone()

            if existing:
                results_list.append({
                    "id": student["id"],
                    "name": student["name"],
                    "course": student["course"],
                    "status": "present",
                    "message": "Attendance already recorded",
                    "confidence": confidence
                })
            else:
                # Insert attendance
                cursor.execute("""
                    INSERT INTO attendance (class_id, student_id, date, status)
                    VALUES (%s, %s, %s, 'present')
                """, (class_id, student["id"], date.today()))
                conn.commit()

                results_list.append({
                    "id": student["id"],
                    "name": student["name"],
                    "course": student["course"],
                    "status": "present",
                    "confidence": confidence
                })

        return jsonify(results_list), 200

    except mysql.connector.Error as db_err:
        return jsonify({"error": str(db_err)}), 500

    except requests.RequestException as req_err:
        return jsonify({"error": "Face++ API error occurred"}), 500

    except Exception as e:
        return jsonify({"error": str(e)}), 500

    finally:
        if cursor:
            cursor.close()
        if conn and conn.is_connected():
            conn.close()
