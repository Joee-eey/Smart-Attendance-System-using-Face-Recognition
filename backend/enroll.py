from flask import Blueprint, request, jsonify
import mysql.connector
import requests
import os
from dotenv import load_dotenv

enroll_bp = Blueprint('enroll', __name__)
load_dotenv()

# Face++ credentials
FACEPP_API_KEY = os.getenv("FACEPP_API_KEY")
FACEPP_API_SECRET = os.getenv("FACEPP_API_SECRET")
DETECT_URL = os.getenv("DETECT_URL")
FACESET_TOKEN = os.getenv("FACESET_TOKEN")

# Database configuration
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

@enroll_bp.route("/enroll", methods=["POST"])
def enroll():
    name = request.form.get("name")
    student_card_id = request.form.get("student_card_id")
    course = request.form.get("course")
    # subject_id = request.form.get("subject_id") 
    image = request.files.get("image")

    # Check required fields
    if not all([name, student_card_id, course, image]):
        return jsonify({"error": "Missing required fields"}), 400

    try:
        # 1: Save image locally
        os.makedirs("uploads", exist_ok=True)
        image_path = f"uploads/{student_card_id}.jpg"
        image.save(image_path)
        print(f"[DEBUG] Image saved at: {image_path}", flush=True)

        # 2: Detect face with Face++
        with open(image_path, "rb") as img_file:
            face_response = requests.post(
                DETECT_URL,
                data={
                    "api_key": FACEPP_API_KEY,
                    "api_secret": FACEPP_API_SECRET,
                },
                files={"image_file": img_file},
            )
        face_data = face_response.json()
        print(f"[DEBUG] Face++ detect response: {face_data}", flush=True)

        if "faces" not in face_data or not face_data["faces"]:
            return jsonify({"error": "No face detected"}), 400

        face_token = face_data["faces"][0]["face_token"]
        print(f"[DEBUG] Detected face_token: {face_token}", flush=True)

        # 3: Add this face_token to your FaceSet
        add_face_response = requests.post(
            "https://api-us.faceplusplus.com/facepp/v3/faceset/addface",
            data={
                "api_key": FACEPP_API_KEY,
                "api_secret": FACEPP_API_SECRET,
                "faceset_token": FACESET_TOKEN,
                "face_tokens": face_token
            },
        )
        add_face_data = add_face_response.json()
        print(f"[DEBUG] Add Face++ response: {add_face_data}", flush=True)

        # Check if adding to faceset failed
        if "face_added" in add_face_data and add_face_data["face_added"] == 0:
            return jsonify({"error": "Failed to add face to FaceSet"}), 400

        # 4: Insert student data into MySQL
        conn = get_db_connection()
        cursor = conn.cursor()
        sql = """
            INSERT INTO students (name, student_card_id, course, face_token, face_image_url)
            VALUES (%s, %s, %s, %s, %s)
        """
        cursor.execute(sql, (name, student_card_id, course, face_token, image_path))
        conn.commit()
        print("[DEBUG] Student inserted successfully into DB", flush=True)

        return jsonify({
            "message": "Student enrolled successfully",
            "face_token": face_token
        }), 201

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
        # Close DB connection safely
        if 'conn' in locals() and conn.is_connected():
            cursor.close()
            conn.close()
            print("[DEBUG] DB connection closed", flush=True)


# @enroll_bp.route("/subjects", methods=["GET"])  
# def get_subjects():
#     try:
#         conn = get_db_connection()
#         cursor = conn.cursor(dictionary=True)
#         cursor.execute("SELECT id, name FROM subjects")
#         subjects = cursor.fetchall()
#         return jsonify(subjects), 200
#     except Exception as e:
#         print(e)
#         return jsonify({"error": "Failed to fetch subjects"}), 500
#     finally:
#         if 'conn' in locals() and conn.is_connected():
#             cursor.close()
#             conn.close()
