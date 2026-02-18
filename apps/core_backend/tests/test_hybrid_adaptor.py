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

from datetime import datetime, timedelta
import json
import uuid

import pytest

from schemas.coordinates import Coordinates
from schemas.routing import (
    GuidanceLanguage,
    ItineraryDetailed,
    ItineraryResponseModel,
    LegDetailed,
    Mode,
    Place,
    PlaceType,
    RelativeDirection,
    RoutingPlanDetailedResponseModel,
    RoutingPlanRequestModel,
    Step,
)
from services.adaptors.hybrid import HybridAdaptor


class _FakeRedis:
    def __init__(self, data: dict[bytes, bytes] | None = None):
        self._data = data or {}
        self.hset_calls: list[dict] = []
        self.expire_calls: list[tuple[str, int]] = []

    def hgetall(self, _: str) -> dict[bytes, bytes]:
        return self._data

    def hset(self, name: str, mapping: dict):
        self.hset_calls.append({"name": name, "mapping": mapping})

    def expire(self, name: str, ttl: int):
        self.expire_calls.append((name, ttl))


class _FakeOtpAdaptor:
    def __init__(self, response: RoutingPlanDetailedResponseModel):
        self.response = response

    async def make_plan_request(self, *_args, **_kwargs) -> RoutingPlanDetailedResponseModel:
        return self.response


class _FakeValhallaAdaptor:
    async def make_plan_request(self, *_args, **_kwargs):
        return RoutingPlanDetailedResponseModel(itineraries=[])


def _itinerary_cache_bytes() -> dict[bytes, bytes]:
    now = datetime(2026, 2, 18, 12, 0, 0)
    itinerary = ItineraryResponseModel(
        itinerary_id=uuid.uuid4(),
        duration=180,
        start_time=now,
        end_time=now + timedelta(minutes=3),
        origin=Coordinates(lat=49.44, lon=7.75),
        destination=Coordinates(lat=49.46, lon=7.77),
        legs=[
            LegDetailed(
                mode=Mode.bus,
                duration=180,
                distance=1000,
                geometry="shape",
                start_time=now,
                end_time=now + timedelta(minutes=3),
                start_place=Place(
                    id="stop-a",
                    name="Stop A",
                    type=PlaceType.stop,
                    coordinates=Coordinates(lat=49.44, lon=7.75),
                ),
                end_place=Place(
                    id="stop-b",
                    name="Stop B",
                    type=PlaceType.stop,
                    coordinates=Coordinates(lat=49.46, lon=7.77),
                ),
                steps=[
                    Step(
                        distance=1000,
                        lon=7.75,
                        lat=49.44,
                        relative_direction=RelativeDirection.transit_ride,
                        street_name="1 stop",
                        bogus_name=False,
                    )
                ],
            )
        ],
    )
    serialized = itinerary.model_dump(mode="json", exclude_none=True)
    return {
        key.encode(): (
            json.dumps(value).encode()
            if isinstance(value, (list, dict))
            else str(value).encode()
        )
        for key, value in serialized.items()
    }


def _transit_leg(now: datetime) -> LegDetailed:
    return LegDetailed(
        mode=Mode.bus,
        duration=300,
        distance=2200,
        geometry="shape",
        start_time=now,
        end_time=now + timedelta(minutes=5),
        start_place=Place(
            id="start",
            name="Central Stop",
            type=PlaceType.stop,
            coordinates=Coordinates(lat=49.44, lon=7.75),
        ),
        end_place=Place(
            id="end",
            name="North Stop",
            type=PlaceType.stop,
            coordinates=Coordinates(lat=49.46, lon=7.77),
        ),
        steps=[],
        intermediate_stops=[
            Place(
                id="mid-1",
                name="Mid 1",
                type=PlaceType.stop,
                coordinates=Coordinates(lat=49.45, lon=7.76),
            )
        ],
    )


@pytest.mark.asyncio
async def test_get_itinerary_deserializes_cached_payload() -> None:
    adaptor = HybridAdaptor(_FakeOtpAdaptor(RoutingPlanDetailedResponseModel(itineraries=[])), _FakeValhallaAdaptor())
    adaptor.redis_client = _FakeRedis(_itinerary_cache_bytes())

    itinerary = await adaptor.get_itinerary("any-id")

    assert itinerary.duration == 180
    assert itinerary.legs[0].mode == Mode.bus


@pytest.mark.asyncio
async def test_make_plan_request_adds_transit_steps_for_transit_legs() -> None:
    now = datetime.now()
    itinerary = ItineraryDetailed(
        itinerary_id=uuid.uuid4(),
        duration=300,
        start_time=now,
        end_time=now + timedelta(minutes=5),
        origin=Coordinates(lat=49.44, lon=7.75),
        destination=Coordinates(lat=49.46, lon=7.77),
        legs=[_transit_leg(now)],
    )
    otp_response = RoutingPlanDetailedResponseModel(itineraries=[itinerary])
    adaptor = HybridAdaptor(_FakeOtpAdaptor(otp_response), _FakeValhallaAdaptor())
    adaptor.redis_client = _FakeRedis()

    request = RoutingPlanRequestModel(
        origin=Coordinates(lat=49.44, lon=7.75),
        destination=Coordinates(lat=49.46, lon=7.77),
        date="2026-02-18",
        time="10:00:00",
        transport_modes=[Mode.transit],
        guidance_language=GuidanceLanguage.en,
    )

    response = await adaptor.make_plan_request(async_client=None, request=request, summarized=False)

    assert len(response.itineraries) == 1
    steps = response.itineraries[0].legs[0].steps
    assert len(steps) == 3
    assert steps[0].relative_direction == RelativeDirection.transit_board
    assert steps[1].relative_direction == RelativeDirection.transit_ride
    assert steps[2].relative_direction == RelativeDirection.transit_alight