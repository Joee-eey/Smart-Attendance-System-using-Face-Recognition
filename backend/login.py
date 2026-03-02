from flask import Blueprint, request, jsonify
import mysql.connector
from flask_bcrypt import Bcrypt
import os
import secrets
from dotenv import load_dotenv

login_bp = Blueprint('login', __name__)
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

def insert_log(conn, user_id, action_type, target_entity, target_id=None, description=None):
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO logs (user_id, action_type, target_entity, target_id, description)
        VALUES (%s, %s, %s, %s, %s)
    """, (user_id, action_type, target_entity, target_id, description))
    conn.commit()
    cursor.close()
    
def get_unique_username(cursor, preferred_name, email):
    """
    Generate a unique username for social sign-in when creating a new user.
    """
    base_username = (preferred_name or "").strip()
    if not base_username:
        base_username = email.split("@")[0]

    # Keep username within common VARCHAR(100) limit used in this project.
    base_username = base_username[:100]

    cursor.execute("SELECT id FROM users WHERE username = %s", (base_username,))
    if not cursor.fetchone():
        return base_username

    # If taken, append a short random suffix and retry until unique.
    trimmed_base = base_username[:88]
    while True:
        candidate = f"{trimmed_base}_{secrets.randbelow(1000000):06d}"
        cursor.execute("SELECT id FROM users WHERE username = %s", (candidate,))
        if not cursor.fetchone():
            return candidate


@login_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()

    if not data:
        return jsonify({'message': 'No data provided'}), 400

    email = data.get('email')
    password = data.get('password')

    if not email or not password:
        return jsonify({'message': 'Missing email or password'}), 400

    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            "SELECT * FROM users WHERE email = %s AND role = 'admin'",
            (email,)
        )
        user = cursor.fetchone()

        if not user:
            return jsonify({'message': 'Email not registered. Please sign up first.'}), 404

        # Prevent password login for social-auth accounts.
        if (user.get('auth_provider') or '').lower() == 'google':
            return jsonify({'message': 'This account uses Google Sign-In. Please log in with Google.'}), 403

        if bcrypt.check_password_hash(user['password'], password):
            insert_log(
                conn=conn,
                user_id=user['id'],  # admin who logged in
                action_type="LOGIN",
                target_entity="users",
                target_id=user['id'],
                description=f"{user['username']} logged in to Cheese!"
            )

            return jsonify({
                'message': 'Login successful',
                'user': {
                    'id': user['id'],
                    'username': user['username'],
                    'email': user['email']
                }
            }), 200
        else:
            return jsonify({'message': 'Incorrect password'}), 401

    except mysql.connector.Error as err:
        print(f"Database Error: {err}")
        return jsonify({'message': 'Database error occurred during login'}), 500

    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return jsonify({'message': 'An internal server error occurred'}), 500

    finally:
        if conn and conn.is_connected():
            if cursor:
                cursor.close()
            conn.close()


@login_bp.route('/login/google', methods=['POST'])
def google_login():
    """
    Google login flow:
    1) Find user by email.
    2) If exists, log the user in.
    3) If not, create a new user with auth_provider='google' and log in immediately.
    """
    data = request.get_json()

    if not data:
        return jsonify({'message': 'No data provided'}), 400

    email = data.get('email')
    google_name = data.get('name')
    provider_id = data.get('provider_id')

    if not email:
        return jsonify({'message': 'Missing email'}), 400

    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Check if this email is already an admin user.
        cursor.execute(
            "SELECT * FROM users WHERE email = %s",
            (email,)
        )
        user = cursor.fetchone()

        if not user:
            # Create a unique username from Google profile name (or email prefix).
            username = get_unique_username(cursor, google_name, email)

            # Store a random bcrypt hash for password. This keeps schema compatibility
            # even when password is NOT NULL and prevents known-password login.
            random_password = secrets.token_urlsafe(32)
            hashed_password = bcrypt.generate_password_hash(random_password).decode('utf-8')

            cursor.execute(
                """
                INSERT INTO users (username, email, password, auth_provider, provider_id)
                VALUES (%s, %s, %s, 'google', %s)
                """,
                (username, email, hashed_password, provider_id)
            )
            conn.commit()
            new_user_id = cursor.lastrowid

            # Re-query so response payload matches the existing /login flow shape.
            cursor.execute(
                "SELECT * FROM users WHERE id = %s",
                (new_user_id,)
            )
            user = cursor.fetchone()

            insert_log(
                conn=conn,
                user_id=user['id'],
                action_type="NEW_USER",
                target_entity="users",
                target_id=user['id'],
                description=f"{user['username']} joined Cheese via Google Sign-In!"
            )

        insert_log(
            conn=conn,
            user_id=user['id'],
            action_type="LOGIN",
            target_entity="users",
            target_id=user['id'],
            description=f"{user['username']} logged in to Cheese via Google Sign-In!"
        )

        # Keep response compatible with current login success JSON.
        return jsonify({
            'message': 'Login successful',
            'user': {
                'id': user['id'],
                'username': user['username'],
                'email': user['email']
            }
        }), 200

    except mysql.connector.Error as err:
        print(f"Database Error: {err}")
        return jsonify({'message': 'Database error occurred during Google login'}), 500

    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return jsonify({'message': 'An internal server error occurred'}), 500

    finally:
        if conn and conn.is_connected():
            if cursor:
                cursor.close()
            conn.close()


@login_bp.route('/login/microsoft', methods=['POST'])
def microsoft_login():
    """
    Microsoft login flow mirrors Google login with Microsoft-specific provider rules:
    1) Find user by email.
    2) If exists, only allow login when auth_provider='microsoft'.
    3) If not, create a new user with auth_provider='microsoft' and log in immediately.
    """
    data = request.get_json()

    if not data:
        return jsonify({'message': 'No data provided'}), 400

    email = data.get('email')
    microsoft_name = data.get('name')
    provider_id = data.get('provider_id')

    if not email:
        return jsonify({'message': 'Missing email'}), 400

    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Look up user by email first, identical to Google login entry point.
        cursor.execute(
            "SELECT * FROM users WHERE email = %s",
            (email,)
        )
        user = cursor.fetchone()

        if user:
            # Microsoft-specific guard:
            # reject email collision when account belongs to another auth provider.
            if (user.get('auth_provider') or '').lower() != 'microsoft':
                return jsonify({
                    'message': 'This account is registered with a different sign-in provider.'
                }), 403
        else:
            # Create a unique username from Microsoft profile name (or email prefix).
            username = get_unique_username(cursor, microsoft_name, email)

            # Store a random bcrypt hash for password for schema compatibility
            # and to prevent password login unless explicitly supported.
            random_password = secrets.token_urlsafe(32)
            hashed_password = bcrypt.generate_password_hash(random_password).decode('utf-8')

            cursor.execute(
                """
                INSERT INTO users (username, email, password, auth_provider, provider_id)
                VALUES (%s, %s, %s, 'microsoft', %s)
                """,
                (username, email, hashed_password, provider_id)
            )
            conn.commit()
            new_user_id = cursor.lastrowid

            # Re-query so response payload matches the existing /login flow shape.
            cursor.execute(
                "SELECT * FROM users WHERE id = %s",
                (new_user_id,)
            )
            user = cursor.fetchone()

            insert_log(
                conn=conn,
                user_id=user['id'],
                action_type="NEW_USER",
                target_entity="users",
                target_id=user['id'],
                description=f"{user['username']} joined Cheese via Microsoft Sign-In!"
            )

        insert_log(
            conn=conn,
            user_id=user['id'],
            action_type="LOGIN",
            target_entity="users",
            target_id=user['id'],
            description=f"{user['username']} logged in to Cheese via Microsoft Sign-In!"
        )

        return jsonify({
            'message': 'Login successful',
            'user': {
                'id': user['id'],
                'username': user['username'],
                'email': user['email']
            }
        }), 200

    except mysql.connector.Error as err:
        print(f"Database Error: {err}")
        return jsonify({'message': 'Database error occurred during Microsoft login'}), 500

    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return jsonify({'message': 'An internal server error occurred'}), 500

    finally:
        if conn and conn.is_connected():
            if cursor:
                cursor.close()
            conn.close()
