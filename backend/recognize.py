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

@recognize_bp.route("/recognize", methods=["POST"])
def recognize_face():
    image = request.files.get("image")
    if not image:
        return jsonify({"error": "No image uploaded"}), 400
    
    class_id = request.form.get("class_id")
    if not class_id:
        return jsonify({"error": "No class_id provided"}), 400

    try:
        class_id = int(class_id)  # convert to int
    except ValueError:
        return jsonify({"error": "Invalid class_id"}), 400

    conn = None
    cursor = None
    try:
        # 1: Save image temporarily
        os.makedirs("uploads", exist_ok=True)
        temp_path = "uploads/temp_recognize.jpg"
        image.save(temp_path)
        print(f"[DEBUG] Image received and saved to {temp_path}", flush=True)

        # 1: Resize the image to max 1024x1024
        max_size = (1024, 1024)
        img = Image.open(temp_path)
        img.thumbnail(max_size, Image.Resampling.LANCZOS)
        img.save(temp_path, format="JPEG", quality=85)
        print(f"[DEBUG] Image resized to {img.size}", flush=True)

        # 2: Detect faces
        with open(temp_path, "rb") as img_file:
            detect_res = requests.post(
                DETECT_URL,
                data={"api_key": FACEPP_API_KEY, "api_secret": FACEPP_API_SECRET},
                files={"image_file": img_file},
            )
            print(f"[DEBUG] Face++ status: {detect_res.status_code}, content: {detect_res.text}", flush=True)

            if detect_res.status_code != 200 or not detect_res.text:
                return jsonify({"error": "Face++ API did not return valid response"}), 500

            try:
                detect_data = detect_res.json()
            except ValueError as ve:
                print(f"[ERROR] Invalid JSON: {ve}", flush=True)
                return jsonify({"error": "Face++ API returned invalid JSON"}), 500

        if "faces" not in detect_data or not detect_data["faces"]:
            return jsonify({"error": "No face detected"}), 400

        results_list = []

        # 3: Open DB connection once
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # 4: Loop through all detected faces
        for face in detect_data["faces"]:
            face_token = face["face_token"]
            print(f"[DEBUG] Detected face_token: {face_token}", flush=True)

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
            try:
                search_data = search_res.json()
            except ValueError:
                results_list.append({"error": "Face++ search returned invalid JSON"})
                continue

            print(f"[DEBUG] Face++ Search Response: {search_data}", flush=True)

            if "results" not in search_data or not search_data["results"]:
                results_list.append({"error": "Face not recognized"})
                continue

            result = search_data["results"][0]
            matched_token = result["face_token"]
            confidence = result["confidence"]

            if confidence < 80:
                results_list.append({"error": "Low confidence match"})
                continue

            # Match student in DB
            cursor.execute(
                "SELECT id, name FROM students WHERE face_token = %s",
                (matched_token,)
            )
            student = cursor.fetchone()
            if not student:
                results_list.append({"error": "Student not found"})
                continue

            # Check if attendance already exists today
            cursor.execute("""
                SELECT id FROM attendance 
                WHERE class_id = %s AND student_id = %s AND DATE(date) = %s
            """, (class_id, student["id"], date.today()))
            existing = cursor.fetchone()

            if existing:
                results_list.append({
                    "name": student["name"],
                    "status": "present",
                    "message": "Attendance already recorded",
                    "confidence": confidence
                })
            else:
                # Insert attendance
                cursor.execute("""
                    INSERT INTO attendance (class_id, student_id, date, status)
                    VALUES (%s, %s, %s, %s)
                """, (1, student["id"], date.today(), "present"))
                conn.commit()
                results_list.append({
                    "name": student["name"],
                    "status": "present",
                    "confidence": confidence
                })

        return jsonify(results_list), 200

    except mysql.connector.Error as db_err:
        print(f"[ERROR] Database Error: {db_err}", flush=True)
        return jsonify({"error": str(db_err)}), 500

    except requests.RequestException as req_err:
        print(f"[ERROR] Face++ API Error: {req_err}", flush=True)
        return jsonify({"error": "Face++ API error occurred"}), 500

    except Exception as e:
        print(f"[ERROR] General Error: {e}", flush=True)
        return jsonify({"error": str(e)}), 500

    finally:
        if cursor:
            cursor.close()
        if conn and conn.is_connected():
            conn.close()
            print("[DEBUG] DB connection closed", flush=True)