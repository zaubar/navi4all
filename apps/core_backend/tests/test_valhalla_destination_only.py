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

"""Valhalla destination-only penalty: pedestrians are not bound by "Anlieger frei".

Valhalla adds ``destination_only_penalty`` (600 s by default) when a route enters
an edge tagged ``access=destination`` / ``motor_vehicle=destination`` -- for
pedestrians too. Nearly every Altstadt living street carries that vehicle rule,
so walking routes circled the old town (Haus der Musik to Thon-Dittmer-Palais:
1087 m with the default, 587 m with 0 s, OTP 402 m). These tests pin that every
pedestrian request sends the configured penalty and that bicycle requests do not.
"""

import json
from urllib.parse import unquote

import polyline
import pytest

from core.config import settings
from schemas.coordinates import Coordinates
from schemas.routing import (
    GradeCategory,
    Mode,
    RoutingPlanRequestModel,
    WalkOptions,
)
from services.adaptors.valhalla import ValhallaAdaptor


class _FakeRedis:
    def hset(self, name: str, mapping: dict) -> None:  # noqa: ARG002
        pass

    def expire(self, name: str, seconds: int) -> None:  # noqa: ARG002
        pass


class _FakeResponse:
    def __init__(self, payload: dict) -> None:
        self._payload = payload

    def raise_for_status(self) -> None:
        pass

    def json(self) -> dict:
        return self._payload


class _FakeAsyncClient:
    def __init__(self, payload: dict) -> None:
        self._payload = payload
        self.requested_urls: list[str] = []

    async def get(self, url: str) -> _FakeResponse:
        self.requested_urls.append(unquote(url))
        return _FakeResponse(self._payload)


def _trip() -> dict:
    points = [(49.0201, 12.0958), (49.0206, 12.0958), (49.0212, 12.0954)]
    shape = polyline.encode(points, precision=6)
    return {
        "legs": [
            {
                "shape": shape,
                "summary": {"time": 120.0, "length": 0.17},
                "maneuvers": [
                    {
                        "type": 1,
                        "instruction": "Walk east.",
                        "street_names": ["Gesandtenstraße"],
                        "travel_mode": "pedestrian",
                        "time": 120.0,
                        "length": 0.17,
                        "begin_shape_index": 0,
                        "end_shape_index": len(points) - 1,
                    }
                ],
            }
        ],
        "summary": {"time": 120.0, "length": 0.17},
    }


def _request(**overrides) -> RoutingPlanRequestModel:
    fields = dict(
        origin=Coordinates(lat=49.0201, lon=12.0958),
        destination=Coordinates(lat=49.0212, lon=12.0954),
        date="2026-09-11",
        time="12:00:00",
        transport_modes=[Mode.walk],
        walk=WalkOptions(speed=5.0, avoid=False),
    )
    fields.update(overrides)
    return RoutingPlanRequestModel(**fields)


def _adaptor() -> ValhallaAdaptor:
    adaptor = ValhallaAdaptor(url="http://valhalla.example")
    adaptor.redis_client = _FakeRedis()
    return adaptor


async def _sent_costing_options(request: RoutingPlanRequestModel) -> dict:
    client = _FakeAsyncClient({"trip": _trip()})
    await _adaptor().make_plan_request(client, request)
    request_json = json.loads(client.requested_urls[0].split("json=", 1)[1])
    return request_json.get("costing_options", {})


@pytest.mark.asyncio
async def test_plain_walk_sends_zero_destination_only_penalty() -> None:
    options = await _sent_costing_options(_request())
    assert options["pedestrian"]["destination_only_penalty"] == 0
    assert options["pedestrian"]["type"] == "foot"


@pytest.mark.asyncio
async def test_accessible_walk_keeps_wheelchair_type_and_sends_penalty() -> None:
    options = await _sent_costing_options(_request(accessible=True))
    assert options["pedestrian"]["type"] == "wheelchair"
    assert options["pedestrian"]["destination_only_penalty"] == 0


@pytest.mark.asyncio
async def test_gentle_walk_sends_penalty_next_to_use_hills() -> None:
    options = await _sent_costing_options(_request(grade_category=GradeCategory.gentle))
    assert options["pedestrian"]["use_hills"] == 0
    assert options["pedestrian"]["destination_only_penalty"] == 0


@pytest.mark.asyncio
async def test_penalty_follows_the_setting(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "VALHALLA_PEDESTRIAN_DESTINATION_ONLY_PENALTY", 42.5)
    options = await _sent_costing_options(_request())
    assert options["pedestrian"]["destination_only_penalty"] == 42.5


@pytest.mark.asyncio
async def test_bicycle_request_does_not_carry_the_pedestrian_option() -> None:
    options = await _sent_costing_options(_request(transport_modes=[Mode.bicycle]))
    pedestrian = options.get("pedestrian") or {}
    assert "destination_only_penalty" not in pedestrian
