import os
import json
from flask import Blueprint, request, jsonify
# other imports...

# Load Google API credentials and token
with open(os.getenv("GOOGLE_CREDENTIALS_PATH")) as f:
    credentials = json.load(f)

with open(os.getenv("GOOGLE_TOKEN_PATH")) as f:
    token = json.load(f)

"""
Forgot password flow for regular admin users.

POST /forgot-password
    → Generate OTP and send email using Gmail API

POST /reset-password
    → Verify OTP and update password
"""

from flask import Blueprint, request, jsonify
from flask_bcrypt import Bcrypt
import mysql.connector
import secrets
import time
import os
import re
from dotenv import load_dotenv

# Gmail sender
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
    """Validate password strength."""
    if len(password) < 8:
        return False
    if not re.search(r"[0-9]", password):
        return False
    if not re.search(r"[a-z]", password):
        return False
    if not re.search(r"[A-Z]", password):
        return False
    if not re.search(r"[^A-Za-z0-9]", password):
        return False
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

        # Store OTP (10 minutes expiry)
        _reset_codes[email.lower()] = {
            "code": code,
            "expiry": time.time() + 600
        }

        # Email content
        email_body = f"""
Hello,

You requested a password reset.

Your verification code is:

{code}

This code will expire in 10 minutes.

If you did not request this, please ignore this email.

Smart Attendance System
"""

        try:
            send_email(
                email,
                "Password Reset Verification Code",
                email_body
            )
        except Exception as mail_error:
            print("Email sending error:", mail_error)
            return jsonify({'message': 'Failed to send verification email'}), 500

        return jsonify({
            "message": "Verification code sent to your email"
        }), 200

    except mysql.connector.Error as db_error:
        print("Database error:", db_error)
        return jsonify({'message': 'Database error'}), 500

    finally:
        if conn and conn.is_connected():
            if cursor:
                cursor.close()
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
        return jsonify({
            'message': 'Password must contain upper, lower, number and symbol'
        }), 400

    entry = _reset_codes.get(email)

    if not entry:
        return jsonify({'message': 'No reset request found'}), 404

    if entry['code'] != code:
        return jsonify({'message': 'Invalid verification code'}), 400

    if time.time() > entry['expiry']:
        del _reset_codes[email]
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

        return jsonify({
            "message": "Password reset successful"
        }), 200

    except Exception as e:
        print("Reset error:", e)
        return jsonify({'message': 'Failed to update password'}), 500

    finally:
        if conn:
            conn.close()
"""
Forgot password flow for regular admin users.
POST /forgot-password: Request verification code (email must be registered as admin).
Sends verification code via email (Gmail or Microsoft Outlook).
"""
from flask import Blueprint, request, jsonify, current_app
from flask_mail import Message
from flask_bcrypt import Bcrypt
import mysql.connector
import secrets
import time
import os
from dotenv import load_dotenv

forgot_password_bp = Blueprint('forgot_password', __name__)
load_dotenv()
bcrypt = Bcrypt()

# In-memory store for verification codes (email -> {code, expiry})
# For production, use Redis or a database table
_reset_codes = {}


def get_db_connection():
    return mysql.connector.connect(
        host=os.getenv('DB_HOST'),
        port=int(os.getenv('DB_PORT', 3306)),
        user=os.getenv('DB_USERNAME'),
        password=os.getenv('DB_PASSWORD'),
        database=os.getenv('DB_DATABASE'),
    )


@forgot_password_bp.route('/forgot-password', methods=['POST'])
def forgot_password():
    """Request a verification code for password reset. Email must be registered as admin."""
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

        # Find user by email (any role)
        cursor.execute(
            "SELECT id, email, auth_provider, role FROM users WHERE email = %s",
            (email,),
        )
        user = cursor.fetchone()

        if not user:
            return jsonify({'message': 'Email not found. Please sign up first.'}), 404

        # Users who signed up with Google/Microsoft cannot use forgot password
        #auth_provider = (user.get('auth_provider') or '').strip().lower()
        #if auth_provider in ('google', 'microsoft'):
            #return jsonify({
                #'message': f'This account uses {auth_provider.capitalize()} Sign-In. Please log in with {auth_provider.capitalize()}.',
            #}), 403

        # Generate 6-digit verification code
        code = ''.join(secrets.choice('0123456789') for _ in range(6))

        # Store code (expires in 10 minutes)
        _reset_codes[email.lower()] = {
            'code': code,
            'expiry': time.time() + 600,
        }

        # Send verification code via email
        mail = current_app.extensions.get('mail')
        if not mail:
            return jsonify({'message': 'Email service not configured. Contact support.'}), 503

        mail_username = current_app.config.get('MAIL_USERNAME')
        if not mail_username or not current_app.config.get('MAIL_PASSWORD'):
            return jsonify({'message': 'Email service not configured. Contact support.'}), 503

        try:
            msg = Message(
                subject='Your Password Reset Verification Code',
                recipients=[email],
                body=f"""Hello,

You requested a password reset. Your verification code is:

  {code}

This code expires in 10 minutes. If you did not request this, please ignore this email.

Best regards,
Your App Team""",
            )
            mail.send(msg)
        except Exception as mail_err:
            print(f"Failed to send email: {mail_err}")
            return jsonify({
                'message': 'Failed to send email. Please check your email address and try again later.',
            }), 500

        return jsonify({
            'message': 'Verification code sent to your email. Please check your inbox.',
        }), 200

    except mysql.connector.Error as err:
        print(f"Database Error: {err}")
        return jsonify({'message': 'Database error. Please try again.'}), 500
    except Exception as e:
        print(f"Error: {e}")
        return jsonify({'message': 'An error occurred. Please try again.'}), 500
    finally:
        if conn and conn.is_connected():
            if cursor:
                cursor.close()
            conn.close()

@forgot_password_bp.route('/reset-password', methods=['POST'])
def reset_password():
    data = request.get_json()
    email = data.get('email', '').lower().strip()
    code = data.get('code', '').strip()
    new_password = data.get('new_password', '')

    # 1. Validate input
    if not email or not code or not new_password:
        return jsonify({'message': 'Missing email, code, or password'}), 400

    # 2. Check if code exists and is correct
    entry = _reset_codes.get(email)
    if not entry:
        return jsonify({'message': 'No reset request found for this email'}), 404

    if entry['code'] != code:
        return jsonify({'message': 'Invalid verification code'}), 400

    if time.time() > entry['expiry']:
        del _reset_codes[email] # Cleanup expired
        return jsonify({'message': 'Code has expired'}), 400

    # 3. Update Database
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

        # 4. Remove code from memory after success
        if email in _reset_codes:
            del _reset_codes[email]

        return jsonify({'message': 'Password reset successful!'}), 200

    except Exception as e:
        print(f"Reset Error: {e}")
        return jsonify({'message': 'Failed to update password'}), 500
    finally:
        if conn: conn.close()