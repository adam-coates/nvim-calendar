import yaml
import os
import sys
import re
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
import dateparser
from pathlib import Path

# Determine platform-specific cache directory
if os.name == "nt":  # For Windows
    base_cache_dir = (
        Path(os.getenv("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
        / "nvim-calendar"
    )
else:  # For Linux/macOS
    base_cache_dir = Path.home() / ".cache" / "nvim-calendar"

SCOPES = ["https://www.googleapis.com/auth/calendar"]


def get_plugin_dir():
    """Returns the dynamic plugin directory, using the path of the script"""
    return os.path.dirname(os.path.abspath(__file__))


def authenticate_google():
    creds = None
    credentials_path = base_cache_dir / "credentials.json"
    token_path = base_cache_dir / "token.json"
    if os.path.exists(token_path):
        creds = Credentials.from_authorized_user_file(token_path, SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(credentials_path, SCOPES)
            creds = flow.run_local_server(port=0)
        with open(token_path, "w") as token:
            token.write(creds.to_json())
    return creds


def parse_date(date_str):
    """Parse human-readable date strings into ISO format."""
    parsed_date = dateparser.parse(date_str, settings={"TIMEZONE": "UTC"})
    if parsed_date:
        return parsed_date.strftime("%Y-%m-%dT%H:%M:%S")
    else:
        raise ValueError(f"Unable to parse date string: {date_str}")


def is_all_day_event(date_str):
    """Check if the date string is an all-day event (i.e., doesn't include a time component)."""
    return not re.search(r"T", date_str)


def add_event_to_google(event_data):
    creds = authenticate_google()
    service = build("calendar", "v3", credentials=creds)

    start_date = parse_date(event_data["start"])
    end_date = parse_date(event_data["end"])

    if is_all_day_event(start_date):
        event = {
            "summary": event_data["summary"],
            "location": event_data.get("location", ""),
            "description": event_data.get("description", ""),
            "start": {"date": start_date},
            "end": {"date": end_date},
            "colorId": event_data.get("color", None),
        }
    else:
        event = {
            "summary": event_data["summary"],
            "location": event_data.get("location", ""),
            "description": event_data.get("description", ""),
            "start": {
                "dateTime": start_date,
                "timeZone": event_data.get("timezone", "UTC"),
            },
            "end": {
                "dateTime": end_date,
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
            if "event" in doc:
                return doc["event"]
    raise ValueError("No 'event' block found in the YAML content.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python add_event.py <yaml_file>")
        sys.exit(1)

    file_path = sys.argv[1]
    yaml_event = load_yaml_from_file(file_path)
    add_event_to_google(yaml_event)
