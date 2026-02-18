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

from fastapi.testclient import TestClient

from main import app
from schemas.user_engagement import UserEngagementEvent
import endpoints.user_engagement as user_engagement_endpoint


class _FakeUserEngagementAdaptor:
    def __init__(self, event=None, error: Exception | None = None):
        self.event = event
        self.error = error

    def get_event(self):
        if self.error:
            raise self.error
        return self.event


def test_user_engagement_event_success(monkeypatch):
    fake_adaptor = _FakeUserEngagementAdaptor(
        event=UserEngagementEvent(
            event_id="ev-1",
            event_title="Title",
            event_description="Description",
        )
    )
    monkeypatch.setattr(user_engagement_endpoint, "adaptor", fake_adaptor)
    client = TestClient(app)

    response = client.get("/v1/user-engagement/event")

    assert response.status_code == 200
    assert response.json()["event_id"] == "ev-1"


def test_user_engagement_event_not_found(monkeypatch):
    fake_adaptor = _FakeUserEngagementAdaptor(error=FileNotFoundError("missing"))
    monkeypatch.setattr(user_engagement_endpoint, "adaptor", fake_adaptor)
    client = TestClient(app)

    response = client.get("/v1/user-engagement/event")

    assert response.status_code == 404
    assert "missing" in response.json()["detail"]
