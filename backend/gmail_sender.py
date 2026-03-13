import base64
import os
from email.mime.text import MIMEText
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

SCOPES = ['https://www.googleapis.com/auth/gmail.send']

def send_email(to_email, subject, body):
    creds = None
    
    base_dir = os.path.dirname(os.path.abspath(__file__))
    token_path = os.path.join(base_dir, 'token.json')
    creds_path = os.path.join(base_dir, 'credentials.json')

    if os.path.exists(token_path):
        creds = Credentials.from_authorized_user_file(token_path, SCOPES)

    # If there are no (valid) credentials available, let the user log in.
    if not creds or not creds.valid:
        if not os.path.exists(creds_path):
            raise FileNotFoundError(f"Missing credentials.json at {creds_path}")
            
        flow = InstalledAppFlow.from_client_secrets_file(creds_path, SCOPES)
        creds = flow.run_local_server(port=0)
        # Save the credentials for the next run
        with open(token_path, 'w') as token:
            token.write(creds.to_json())

    service = build('gmail', 'v1', credentials=creds)

    message = MIMEText(body)
    message['to'] = to_email
    message['subject'] = subject

    raw = base64.urlsafe_b64encode(message.as_bytes()).decode()
    message_body = {'raw': raw}

    service.users().messages().send(
        userId='me',
        body=message_body
    ).execute()