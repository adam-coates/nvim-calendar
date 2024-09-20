import os
import sys
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from datetime import datetime, timedelta
from pathlib import Path

# Paths and scopes
SCOPES = ["https://www.googleapis.com/auth/calendar"]
base_cache_dir = Path.home() / ".cache" / "nvim-calendar-add"
credentials_path = base_cache_dir / "credentials.json"
token_path = base_cache_dir / "token.json"


def authenticate_google():
    creds = None
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


def fetch_events_for_day(day):
    creds = authenticate_google()
    service = build("calendar", "v3", credentials=creds)

    # Create the time range for the selected day
    start_of_day = datetime.strptime(day, "%Y-%m-%d").isoformat() + "Z"
    end_of_day = (
        datetime.strptime(day, "%Y-%m-%d") + timedelta(days=1)
    ).isoformat() + "Z"

    events_result = (
        service.events()
        .list(
            calendarId="primary",
            timeMin=start_of_day,
            timeMax=end_of_day,
            singleEvents=True,
            orderBy="startTime",
        )
        .execute()
    )
    events = events_result.get("items", [])

    if not events:
        print("No events found.")
    else:
        for event in events:
            start = event["start"].get("dateTime", event["start"].get("date"))
            print(f"{start} - {event['summary']}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python get_events.py <YYYY-MM-DD>")
        sys.exit(1)
    day = sys.argv[1]
    fetch_events_for_day(day)
