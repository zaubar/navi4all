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

"""Valhalla alternates on every pedestrian plan, sized by num_itineraries.

Before 2026-09-11 alternates were requested only for ``grade_category=gentle``,
so every other Valhalla plan came back as exactly one itinerary although the
app asked for 3 or 5. These tests pin: the count follows ``num_itineraries``
(capped at Valhalla's 2), "gentle" always gets 2 so the grade gate has
candidates, non-pedestrian costings get none, and every leg of a multi-leg trip
carries its own start and end coordinates taken from the trip locations.
"""

import json
from urllib.parse import unquote

import polyline
import pytest

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


def _leg(points: list[tuple[float, float]], seconds: float = 120.0) -> dict:
    return {
        "shape": polyline.encode(points, precision=6),
        "summary": {"time": seconds, "length": 0.17},
        "maneuvers": [
            {
                "type": 1,
                "instruction": "Walk east.",
                "street_names": ["Gesandtenstraße"],
                "travel_mode": "pedestrian",
                "time": seconds,
                "length": 0.17,
                "begin_shape_index": 0,
                "end_shape_index": len(points) - 1,
            }
        ],
    }


A = (49.0201, 12.0958)
B = (49.0206, 12.0968)
C = (49.0212, 12.0954)


def _trip(*legs: dict, locations: list[tuple[float, float]] | None = None) -> dict:
    trip = {
        "legs": list(legs),
        "summary": {"time": 120.0 * len(legs), "length": 0.17 * len(legs)},
    }
    if locations is not None:
        trip["locations"] = [{"lat": lat, "lon": lon} for lat, lon in locations]
    return trip


def _request(**overrides) -> RoutingPlanRequestModel:
    fields = dict(
        origin=Coordinates(lat=A[0], lon=A[1]),
        destination=Coordinates(lat=C[0], lon=C[1]),
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


async def _sent(request: RoutingPlanRequestModel, payload: dict | None = None):
    client = _FakeAsyncClient(payload or {"trip": _trip(_leg([A, C]))})
    response = await _adaptor().make_plan_request(client, request, summarized=False)
    request_json = json.loads(client.requested_urls[0].split("json=", 1)[1])
    return request_json, response


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("num_itineraries", "expected"),
    [(1, None), (2, 1), (3, 2), (5, 2)],
)
async def test_plain_walk_alternates_follow_num_itineraries(num_itineraries, expected) -> None:
    request_json, _ = await _sent(_request(num_itineraries=num_itineraries))
    assert request_json.get("alternates") == expected


@pytest.mark.asyncio
async def test_gentle_walk_keeps_two_alternates_even_for_a_single_itinerary() -> None:
    request_json, _ = await _sent(_request(num_itineraries=1, grade_category=GradeCategory.gentle))
    assert request_json["alternates"] == 2


@pytest.mark.asyncio
async def test_accessible_walk_requests_alternates_too() -> None:
    request_json, _ = await _sent(_request(num_itineraries=3, accessible=True))
    assert request_json["alternates"] == 2
    assert request_json["costing_options"]["pedestrian"]["type"] == "wheelchair"


@pytest.mark.asyncio
async def test_bicycle_request_asks_for_no_alternates() -> None:
    request_json, _ = await _sent(_request(num_itineraries=5, transport_modes=[Mode.bicycle]))
    assert "alternates" not in request_json


@pytest.mark.asyncio
async def test_multi_leg_trip_carries_per_leg_places() -> None:
    payload = {"trip": _trip(_leg([A, B]), _leg([B, C]), locations=[A, B, C])}
    _, response = await _sent(_request(), payload)
    legs = response.itineraries[0].legs
    assert len(legs) == 2
    assert (legs[0].start_place.coordinates.lat, legs[0].start_place.coordinates.lon) == A
    assert (legs[0].end_place.coordinates.lat, legs[0].end_place.coordinates.lon) == B
    assert (legs[1].start_place.coordinates.lat, legs[1].start_place.coordinates.lon) == B
    assert (legs[1].end_place.coordinates.lat, legs[1].end_place.coordinates.lon) == C


@pytest.mark.asyncio
async def test_trip_without_locations_falls_back_to_the_request_endpoints() -> None:
    _, response = await _sent(_request(), {"trip": _trip(_leg([A, C]))})
    leg = response.itineraries[0].legs[0]
    assert (leg.start_place.coordinates.lat, leg.start_place.coordinates.lon) == A
    assert (leg.end_place.coordinates.lat, leg.end_place.coordinates.lon) == C
