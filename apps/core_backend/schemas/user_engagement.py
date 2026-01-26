from pydantic import BaseModel
from datetime import datetime

class UserEngagementEvent(BaseModel):
    event_id: str
    event_title: str
    event_description: str
    event_url: str | None = None
    event_valid_until: datetime | None = None
    decline_button_text: str = "Cancel"
    accept_button_text: str = "Continue"
