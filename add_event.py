import yaml
import os
import sys
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow

# Load credentials
SCOPES = ["https://www.googleapis.com/auth/calendar"]


def authenticate_google():
    creds = None
    # The file token.json stores the user's access and refresh tokens, and is
    # created automatically when the authorization flow completes for the first time.
    if os.path.exists("C:/Users/coates/token.json"):
        creds = Credentials.from_authorized_user_file(
            "C:/Users/coates/token.json", SCOPES
        )
    # If there are no (valid) credentials available, let the user log in.
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                "C:/Users/coates/credentials.json", SCOPES
            )
            creds = flow.run_local_server(port=0)
        # Save the credentials for the next run
        with open("C:/Users/coates/token.json", "w") as token:
            token.write(creds.to_json())
    return creds


def add_event_to_google(event_data):
    creds = authenticate_google()
    service = build("calendar", "v3", credentials=creds)

    event = {
        "summary": event_data["summary"],
        "location": event_data.get("location", ""),
        "description": event_data.get("description", ""),
        "start": {
            "dateTime": event_data["start"],
            "timeZone": event_data.get("timezone", "UTC"),
        },
        "end": {
            "dateTime": event_data["end"],
            "timeZone": event_data.get("timezone", "UTC"),
        },
        "colorId": event_data.get("color", None),
    }

    event_result = service.events().insert(calendarId="primary", body=event).execute()
    print(f"Event created: {event_result.get('htmlLink')}")


def load_yaml_from_file(file_path):
    with open(file_path, "r") as file:
        documents = yaml.safe_load_all(file)
        for doc in documents:
            # Assuming we want to extract the 'event' document from multiple docs
            if "event" in doc:
                return doc["event"]
    raise ValueError("No 'event' block found in the YAML content.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python add_event.py <markdown_file>")
        sys.exit(1)

    # Accept the file path from command-line argument
    file_path = sys.argv[1]

    yaml_event = load_yaml_from_file(file_path)
    add_event_to_google(yaml_event)
