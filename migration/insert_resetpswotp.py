import os
import mysql.connector
from dotenv import load_dotenv

load_dotenv()

def create_otp_table():
    conn = mysql.connector.connect(
        host=os.getenv('DB_HOST'),
        port=int(os.getenv('DB_PORT', 3306)),
        user=os.getenv('DB_USERNAME'),
        password=os.getenv('DB_PASSWORD'),
        database=os.getenv('DB_DATABASE'),
    )

    cursor = conn.cursor()

    # Check if table exists
    cursor.execute("""
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = %s
        AND table_name = 'password_reset_codes'
    """, (os.getenv('DB_DATABASE'),))

    exists = cursor.fetchone()[0]

    if not exists:

        cursor.execute("""
        CREATE TABLE password_reset_codes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            email VARCHAR(255) NOT NULL,
            code_hash VARCHAR(255) NOT NULL,
            expires_at DATETIME NOT NULL,
            attempts INT DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX(email)
        )
        """)

        conn.commit()
        print("OTP table created successfully.")

    else:
        print("OTP table already exists.")

    cursor.close()
    conn.close()

if __name__ == "__main__":
    create_otp_table()