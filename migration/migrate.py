import os
import mysql.connector
from dotenv import load_dotenv

# Load environment variables from .env
load_dotenv()

DB_HOST = os.environ.get("DB_HOST", "127.0.0.1")
DB_PORT = int(os.environ.get("DB_PORT", 3306))
DB_DATABASE = os.environ.get("DB_DATABASE", "attendance")
DB_USERNAME = os.environ.get("DB_USERNAME", "root")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")

# Connect to MySQL
db = mysql.connector.connect(
    host=DB_HOST,
    port=DB_PORT,
    user=DB_USERNAME,
    password=DB_PASSWORD
)
cursor = db.cursor()

# Create database
cursor.execute(f"CREATE DATABASE IF NOT EXISTS {DB_DATABASE};")
cursor.execute(f"USE {DB_DATABASE};")

# ----------------------
# USERS TABLE (login for lecturers only)
# ----------------------
cursor.execute("""
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('admin', 'superadmin') NOT NULL DEFAULT 'admin',
    auth_provider ENUM('email', 'google', 'microsoft') NOT NULL DEFAULT 'email',
    profile_image_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
""")

# ----------------------
# SUBJECTS TABLE
# ----------------------
cursor.execute("""
CREATE TABLE IF NOT EXISTS subjects (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    image_url VARCHAR(255),
    lecturer_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (lecturer_id) REFERENCES users(id)
);
""")

# ----------------------
# CLASSES TABLE
# ----------------------
cursor.execute("""
CREATE TABLE IF NOT EXISTS classes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    subject_id INT NOT NULL,
    schedule VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (subject_id) REFERENCES subjects(id)
);
""")

# ----------------------
# STUDENTS TABLE (without subject_id and face_token)
# ----------------------
cursor.execute("""
CREATE TABLE IF NOT EXISTS students (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    student_card_id VARCHAR(50) UNIQUE,
    course VARCHAR(100),
    face_image_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
""")

# ----------------------
# STUDENT_FACES TABLE (for multiple photos per student)
# ----------------------
cursor.execute("""
CREATE TABLE IF NOT EXISTS student_faces (
    id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    face_token VARCHAR(100) UNIQUE NOT NULL,
    face_image_url VARCHAR(255),
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(id)
);
""")


# ----------------------
# ENROLLMENTS TABLE (student-subject many-to-many)
# ----------------------
cursor.execute("""
CREATE TABLE IF NOT EXISTS enrollments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    subject_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (student_id, subject_id),
    FOREIGN KEY (student_id) REFERENCES students(id),
    FOREIGN KEY (subject_id) REFERENCES subjects(id)
);
""")

# ----------------------
# ATTENDANCE TABLE
# ----------------------
cursor.execute("""
CREATE TABLE IF NOT EXISTS attendance (
    id INT AUTO_INCREMENT PRIMARY KEY,
    class_id INT NOT NULL,
    student_id INT NOT NULL,
    date DATE NOT NULL,
    status ENUM('present', 'absent', 'late') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (class_id) REFERENCES classes(id),
    FOREIGN KEY (student_id) REFERENCES students(id)
);
""")


# ----------------------
# LOG TABLE
# ----------------------
cursor.execute("""
CREATE TABLE IF NOT EXISTS logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    target_entity VARCHAR(50),
    target_id INT,
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);
""")

db.commit()
cursor.close()
db.close()

print("Smart Attendance Database created successfully!")
