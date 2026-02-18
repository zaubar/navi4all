# Navi4All
# Copyright (C) Navi4All contributors
# Maintainer: Plan4Better GmbH
#
# SPDX-License-Identifier: AGPL-3.0-only
#
# Licensed under the GNU Affero General Public License, Version 3 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.gnu.org/licenses/agpl-3.0.en.html
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
