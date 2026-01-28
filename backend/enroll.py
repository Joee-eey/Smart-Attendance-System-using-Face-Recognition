from flask import Blueprint, request, jsonify
import mysql.connector
import requests
import os
import time
from dotenv import load_dotenv
from concurrent.futures import ThreadPoolExecutor, as_completed
from PIL import Image

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

def insert_log(conn, user_id, action_type, target_entity, target_id=None, description=None):
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO logs (user_id, action_type, target_entity, target_id, description)
        VALUES (%s, %s, %s, %s, %s)
    """, (user_id, action_type, target_entity, target_id, description))
    conn.commit()
    cursor.close()


@enroll_bp.route("/enroll", methods=["POST"])
def enroll():
    name = request.form.get("name")
    student_card_id = request.form.get("student_card_id")
    course = request.form.get("course")
    user_id = request.form.get("user_id", type=int)
    images = request.files.getlist("images")
    primary_index = int(request.form.get("primary_index", 0))

    if not all([name, student_card_id, course]) or not images:
        return jsonify({"error": "Missing required fields"}), 400

    try:
        os.makedirs("uploads", exist_ok=True)

        # Retry helper
        def retry_request(func, retries=3, delay=2, *args, **kwargs):
            for attempt in range(1, retries + 1):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    print(f"[WARN] Attempt {attempt} failed: {e}")
                    if attempt < retries:
                        time.sleep(delay)
                    else:
                        return None

        # Function to process a single image
        def process_image(index, image_file):
            image_path = f"uploads/{student_card_id}_{index}.jpg"
            image_file.save(image_path)

            # Resize/compress image to reduce size and avoid timeout
            try:
                img = Image.open(image_path)
                img.thumbnail((1024, 1024))  # Max width/height = 1024px
                img.save(image_path, "JPEG", quality=85)
            except Exception as e:
                print(f"[ERROR] Failed to resize {image_path}: {e}")
                return None

            # 1️⃣ Detect face
            def detect_face():
                with open(image_path, "rb") as img_file:
                    resp = requests.post(
                        DETECT_URL,
                        data={"api_key": FACEPP_API_KEY, "api_secret": FACEPP_API_SECRET},
                        files={"image_file": img_file},
                        timeout=(10, 120)  # 10s connect, 120s read
                    )
                data = resp.json()
                if resp.status_code != 200 or "faces" not in data or not data["faces"]:
                    raise Exception(f"No faces detected: {data}")
                return data["faces"][0]["face_token"]

            face_token = retry_request(detect_face, retries=3, delay=2)
            if not face_token:
                print(f"[ERROR] Face detection failed for {image_path}")
                return None

            # 2️⃣ Add face to FaceSet
            def add_face():
                resp = requests.post(
                    "https://api-us.faceplusplus.com/facepp/v3/faceset/addface",
                    data={
                        "api_key": FACEPP_API_KEY,
                        "api_secret": FACEPP_API_SECRET,
                        "faceset_token": FACESET_TOKEN,
                        "face_tokens": face_token,
                    },
                    timeout=10
                )
                data = resp.json()
                if resp.status_code != 200 or data.get("error_message"):
                    raise Exception(f"Face++ addface failed: {data}")
                return True

            added = retry_request(add_face, retries=3, delay=2)
            if not added:
                print(f"[ERROR] Failed to add face to FaceSet for {image_path}")
                return None

            return {"index": index, "image_path": image_path, "face_token": face_token}

        # 3️⃣ Process all images in parallel
        results = []
        with ThreadPoolExecutor(max_workers=min(4, len(images))) as executor:
            futures = [executor.submit(process_image, idx, img) for idx, img in enumerate(images)]
            for future in as_completed(futures):
                res = future.result()
                if res:
                    results.append(res)

        # Fail if any image failed
        if len(results) != len(images):
            return jsonify({"error": "Face detection/addface failed for one or more images"}), 400

        # 4️⃣ Insert student + faces in a transaction
        conn = get_db_connection()
        cursor = conn.cursor(buffered=True)

        cursor.execute("""
            INSERT INTO students (name, student_card_id, course)
            VALUES (%s, %s, %s)
        """, (name, student_card_id, course))
        student_id = cursor.lastrowid
        print(f"[INFO] Inserted student_id: {student_id}")

        primary_image_url = None
        for res in results:
            is_primary_int = 1 if res["index"] == primary_index else 0
            cursor.execute("""
                INSERT INTO student_faces (student_id, face_token, face_image_url, is_primary)
                VALUES (%s, %s, %s, %s)
            """, (student_id, res["face_token"], res["image_path"], is_primary_int))
            print(f"[INFO] Inserted student_face for {res['image_path']}")
            if res["index"] == primary_index:
                primary_image_url = res["image_path"]

        if primary_image_url:
            cursor.execute("""
                UPDATE students SET face_image_url = %s WHERE id = %s
            """, (primary_image_url, student_id))

        insert_log(
            conn=conn,
            user_id=user_id,
            action_type="ENROLL",
            target_entity="students",
            target_id=student_id,
            description=f"Enrolled student '{name}' with student ID {student_card_id}"
        )

        conn.commit()
        return jsonify({"message": "Student enrolled successfully"}), 201

    except Exception as e:
        if 'conn' in locals():
            conn.rollback()
        print(f"[ERROR] Enrollment failed: {e}")
        return jsonify({"error": str(e)}), 500

    finally:
        if 'cursor' in locals() and cursor:
            cursor.close()
        if 'conn' in locals() and conn:
            conn.close()
