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

from pathlib import Path

import pytest

from schemas.user_engagement import UserEngagementEvent
from services.adaptors.user_engagement import UserEngagementAdaptor


def test_load_event_payload_raises_without_configured_file() -> None:
    adaptor = UserEngagementAdaptor(event_file=None)

    with pytest.raises(ValueError):
        adaptor._load_event_payload()


def test_load_event_payload_raises_for_missing_file(tmp_path: Path) -> None:
    missing_file = tmp_path / "event.json"
    adaptor = UserEngagementAdaptor(event_file=str(missing_file))

    with pytest.raises(FileNotFoundError):
        adaptor._load_event_payload()


def test_get_event_loads_and_validates_payload(tmp_path: Path) -> None:
    event_file = tmp_path / "event.json"
    event_file.write_text(
        '{"event_id":"ev-1","event_title":"Title","event_description":"Desc"}',
        encoding="utf-8",
    )
    adaptor = UserEngagementAdaptor(event_file=str(event_file))

    event = adaptor.get_event()

    assert isinstance(event, UserEngagementEvent)
    assert event.event_id == "ev-1"
    assert event.accept_button_text == "Continue"