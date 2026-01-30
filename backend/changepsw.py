from flask import Flask, request, jsonify
from werkzeug.security import check_password_hash, generate_password_hash

app = Flask(__name__)

@app.route('/users/change-password', methods=['POST'])
def change_password():
    data = request.get_json()
    user_id = data.get('user_id')
    current_password = data.get('current_password')
    new_password = data.get('new_password')

    print(f"Received request for user_id: {user_id}")

    user = User.query.get(user_id)
    if not user:
        return jsonify({"message": "User not found"}), 404

    if not check_password_hash(user.password, current_password):
        return jsonify({"message": "Incorrect current password"}), 401

    user.password = generate_password_hash(new_password)
    db.session.commit()

    return jsonify({"message": "Password updated successfully"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)