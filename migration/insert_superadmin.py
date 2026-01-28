import os
import mysql.connector
from dotenv import load_dotenv
from flask_bcrypt import Bcrypt

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
    password=DB_PASSWORD,
    database=DB_DATABASE
)
cursor = db.cursor()

bcrypt = Bcrypt()

# Superadmin details
superadmin_username = "superadmin1"
superadmin_email = "superadmin@gmail.com"
superadmin_password = bcrypt.generate_password_hash("123qwe").decode('utf-8')

# Check if superadmin already exists
cursor.execute("""
SELECT id FROM users WHERE username = %s
""", (superadmin_username,))

existing = cursor.fetchone()

if not existing:
    cursor.execute("""
    INSERT INTO users (username, email, password, role)
    VALUES (%s, %s, %s, %s)
    """, (
        superadmin_username,
        superadmin_email,
        superadmin_password,
        "superadmin"
    ))
    db.commit()
    print("Superadmin user created successfully.")
else:
    print("Superadmin already exists.")

cursor.close()
db.close()
