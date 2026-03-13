import os
import re
import time
import secrets
import mysql.connector
from flask import Blueprint, request, jsonify
from flask_bcrypt import Bcrypt
from dotenv import load_dotenv
from gmail_sender import send_email

forgot_password_bp = Blueprint('forgot_password', __name__)
load_dotenv()
bcrypt = Bcrypt()

# Temporary store for OTP codes
_reset_codes = {}

def get_db_connection():
    return mysql.connector.connect(
        host=os.getenv('DB_HOST'),
        port=int(os.getenv('DB_PORT', 3306)),
        user=os.getenv('DB_USERNAME'),
        password=os.getenv('DB_PASSWORD'),
        database=os.getenv('DB_DATABASE'),
    )

def is_strong_password(password: str) -> bool:
    """Validate 5 requirements: 8+ chars, digit, lowercase, uppercase, symbol."""
    if len(password) < 8: return False
    if not re.search(r"[0-9]", password): return False
    if not re.search(r"[a-z]", password): return False
    if not re.search(r"[A-Z]", password): return False
    if not re.search(r"[^A-Za-z0-9]", password): return False
    return True

@forgot_password_bp.route('/forgot-password', methods=['POST'])
def forgot_password():
    data = request.get_json()
    if not data:
        return jsonify({'message': 'No data provided'}), 400

    email = (data.get('email') or '').strip()
    if not email:
        return jsonify({'message': 'Please enter your email address'}), 400

    conn = None
    cursor = None

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            "SELECT id, email FROM users WHERE email = %s",
            (email,)
        )
        user = cursor.fetchone()

        if not user:
            return jsonify({'message': 'Email not found'}), 404

        # Generate 6 digit OTP
        code = ''.join(secrets.choice('0123456789') for _ in range(6))

        # Store OTP (300 seconds = 5 minutes expiry)
        _reset_codes[email.lower()] = {
            "code": code,
            "expiry": time.time() + 300
        }

        # Email content
        email_body = f"""
Hello,

You requested a password reset. Your verification code is:

{code}

This code will expire in 5 minutes. If you did not request this, please ignore this email.

Best regards,
Smart Attendance System"""

        try:
            send_email(
                email,
                "Password Reset Verification Code",
                email_body
            )
        except Exception as mail_error:
            print("Email sending error:", mail_error)
            return jsonify({'message': 'Failed to send verification email'}), 500

        return jsonify({"message": "Verification code sent to your email"}), 200

    except mysql.connector.Error as db_error:
        print("Database error:", db_error)
        return jsonify({'message': 'Database error'}), 500
    finally:
        if conn and conn.is_connected():
            if cursor: cursor.close()
            conn.close()

@forgot_password_bp.route('/reset-password', methods=['POST'])
def reset_password():
    data = request.get_json() or {}
    email = (data.get('email') or '').lower().strip()
    code = (data.get('code') or '').strip()
    new_password = data.get('new_password') or ''

    if not email or not code or not new_password:
        return jsonify({'message': 'Missing email, code or password'}), 400

    if not is_strong_password(new_password):
        return jsonify({'message': 'Password must contain 8 characters, uppercase, lowercase, number and symbol'}), 400

    entry = _reset_codes.get(email)

    if not entry:
        return jsonify({'message': 'No reset request found'}), 404

    if entry['code'] != code:
        return jsonify({'message': 'Invalid verification code'}), 400

    if time.time() > entry['expiry']:
        if email in _reset_codes: del _reset_codes[email]
        return jsonify({'message': 'Verification code expired'}), 400

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        hashed_password = bcrypt.generate_password_hash(new_password).decode('utf-8')

        cursor.execute(
            "UPDATE users SET password = %s WHERE email = %s",
            (hashed_password, email)
        )
        conn.commit()

        if email in _reset_codes:
            del _reset_codes[email]

        return jsonify({"message": "Password reset successful"}), 200

    except Exception as e:
        print("Reset error:", e)
        return jsonify({'message': 'Failed to update password'}), 500
    finally:
        if conn: conn.close()