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

"""Valhalla alternates: request them for gentle walk plans, map every trip.

The grade gate can only drop a too-steep itinerary when a compliant
alternative exists in the response. Valhalla responses used to be
structurally single-itinerary (only ``trip`` was mapped, ``alternates``
never requested), which starved the gate and let an 11% street survive
"avoid gradients". These tests pin the two halves of the fix.
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
from services.schemas.valhalla import ValhallaRouteResponseModel


class _FakeRedis:
    def __init__(self) -> None:
        self.hset_calls: list[str] = []

    def hset(self, name: str, mapping: dict) -> None:
        self.hset_calls.append(name)

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


def _trip(duration_seconds: float, points: list[tuple[float, float]]) -> dict:
    shape = polyline.encode(points, precision=6)
    length_km = duration_seconds / 3600 * 5.0
    return {
        "legs": [
            {
                "shape": shape,
                "summary": {"time": duration_seconds, "length": length_km},
                "maneuvers": [
                    {
                        "type": 1,
                        "instruction": "Walk east.",
                        "street_names": ["Teststraße"],
                        "travel_mode": "pedestrian",
                        "time": duration_seconds,
                        "length": length_km,
                        "begin_shape_index": 0,
                        "end_shape_index": len(points) - 1,
                    }
                ],
            }
        ],
        "summary": {"time": duration_seconds, "length": length_km},
    }


_PRIMARY = _trip(120.0, [(49.0201, 12.0958), (49.0206, 12.0958), (49.0212, 12.0954)])
_ALT_A = _trip(150.0, [(49.0201, 12.0958), (49.0206, 12.0968), (49.0212, 12.0954)])
_ALT_B = _trip(180.0, [(49.0201, 12.0958), (49.0201, 12.0975), (49.0212, 12.0954)])


def _request(grade_category=None, modes=None) -> RoutingPlanRequestModel:
    return RoutingPlanRequestModel(
        origin=Coordinates(lat=49.0201, lon=12.0958),
        destination=Coordinates(lat=49.0212, lon=12.0954),
        date="2026-08-20",
        time="12:00:00",
        transport_modes=modes or [Mode.walk],
        walk=WalkOptions(speed=5.0, avoid=False),
        grade_category=grade_category,
    )


def _adaptor() -> tuple[ValhallaAdaptor, _FakeRedis]:
    adaptor = ValhallaAdaptor(url="http://valhalla.example")
    fake_redis = _FakeRedis()
    adaptor.redis_client = fake_redis
    return adaptor, fake_redis


def test_response_model_parses_alternates() -> None:
    parsed = ValhallaRouteResponseModel.model_validate(
        {"trip": _PRIMARY, "alternates": [{"trip": _ALT_A}]}
    )
    assert parsed.alternates is not None
    assert len(parsed.alternates) == 1


def test_response_model_without_alternates_still_parses() -> None:
    parsed = ValhallaRouteResponseModel.model_validate({"trip": _PRIMARY})
    assert parsed.alternates is None


@pytest.mark.asyncio
async def test_gentle_walk_requests_alternates() -> None:
    adaptor, _ = _adaptor()
    client = _FakeAsyncClient({"trip": _PRIMARY})

    await adaptor.make_plan_request(client, _request(GradeCategory.gentle))

    request_json = json.loads(client.requested_urls[0].split("json=", 1)[1])
    assert request_json["alternates"] == 2


@pytest.mark.asyncio
async def test_plain_walk_requests_no_alternates() -> None:
    adaptor, _ = _adaptor()
    client = _FakeAsyncClient({"trip": _PRIMARY})

    await adaptor.make_plan_request(client, _request(grade_category=None))

    request_json = json.loads(client.requested_urls[0].split("json=", 1)[1])
    assert "alternates" not in request_json


@pytest.mark.asyncio
async def test_gentle_bicycle_requests_no_alternates() -> None:
    # Alternates are only valid for the pedestrian costing here; a non-walk
    # mode must not request them even if grade_category is set.
    adaptor, _ = _adaptor()
    client = _FakeAsyncClient({"trip": _PRIMARY})

    await adaptor.make_plan_request(
        client, _request(GradeCategory.gentle, modes=[Mode.bicycle])
    )

    request_json = json.loads(client.requested_urls[0].split("json=", 1)[1])
    assert "alternates" not in request_json


@pytest.mark.asyncio
async def test_alternates_are_mapped_into_itineraries() -> None:
    adaptor, fake_redis = _adaptor()
    client = _FakeAsyncClient(
        {"trip": _PRIMARY, "alternates": [{"trip": _ALT_A}, {"trip": _ALT_B}]}
    )

    response = await adaptor.make_plan_request(client, _request(GradeCategory.gentle))

    assert len(response.itineraries) == 3
    assert [it.duration for it in response.itineraries] == [120, 150, 180]
    # Every itinerary must be cached under its own id so get_itinerary works
    # for whichever one survives downstream filtering (e.g. the grade gate).
    ids = [str(it.itinerary_id) for it in response.itineraries]
    assert len(set(ids)) == 3
    assert set(fake_redis.hset_calls) == set(ids)


@pytest.mark.asyncio
async def test_single_trip_response_maps_one_itinerary() -> None:
    adaptor, _ = _adaptor()
    client = _FakeAsyncClient({"trip": _PRIMARY})

    response = await adaptor.make_plan_request(client, _request(GradeCategory.gentle))

    assert len(response.itineraries) == 1
    assert response.itineraries[0].duration == 120
