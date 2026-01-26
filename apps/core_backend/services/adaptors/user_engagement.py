import json
from pathlib import Path
from core.config import settings
from schemas.user_engagement import UserEngagementEvent


class UserEngagementAdaptor:
    def __init__(self, event_file: str | None = None):
        self.event_file = event_file or settings.USER_ENGAGEMENT_EVENT_FILE

    def _load_event_payload(self) -> dict:
        if not self.event_file:
            raise ValueError("USER_ENGAGEMENT_EVENT_FILE is not configured.")

        path = Path(self.event_file)
        if not path.exists():
            raise FileNotFoundError(f"User engagement file not found: {path}")

        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)

    def get_event(self) -> UserEngagementEvent:
        payload = self._load_event_payload()
        return UserEngagementEvent.model_validate(payload)
