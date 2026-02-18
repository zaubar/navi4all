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
    ItineraryResponseModel,
    LegDetailed,
    Mode,
    Place,
    PlaceType,
    RelativeDirection,
    Step,
)
from services.adaptors.valhalla import ValhallaAdaptor


class _FakeRedis:
    def __init__(self, data: dict[bytes, bytes]):
        self._data = data

    def hgetall(self, _: str) -> dict[bytes, bytes]:
        return self._data


def _itinerary_cache_bytes() -> dict[bytes, bytes]:
    now = datetime(2026, 2, 18, 12, 0, 0)
    itinerary = ItineraryResponseModel(
        itinerary_id=uuid.uuid4(),
        duration=90,
        start_time=now,
        end_time=now + timedelta(seconds=90),
        origin=Coordinates(lat=49.44, lon=7.75),
        destination=Coordinates(lat=49.45, lon=7.76),
        legs=[
            LegDetailed(
                mode=Mode.walk,
                duration=90,
                distance=110,
                geometry="xyz",
                start_time=now,
                end_time=now + timedelta(seconds=90),
                start_place=Place(
                    id="a",
                    name="A",
                    type=PlaceType.address,
                    coordinates=Coordinates(lat=49.44, lon=7.75),
                ),
                end_place=Place(
                    id="b",
                    name="B",
                    type=PlaceType.address,
                    coordinates=Coordinates(lat=49.45, lon=7.76),
                ),
                steps=[
                    Step(
                        distance=110,
                        lon=7.75,
                        lat=49.44,
                        relative_direction=RelativeDirection.continue_,
                        street_name="Walk",
                        bogus_name=True,
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


@pytest.mark.asyncio
async def test_get_itinerary_deserializes_cached_payload() -> None:
    adaptor = ValhallaAdaptor(url="https://valhalla.example")
    adaptor.redis_client = _FakeRedis(_itinerary_cache_bytes())

    itinerary = await adaptor.get_itinerary("any-id")

    assert itinerary.duration == 90
    assert itinerary.legs[0].distance == 110
    assert itinerary.legs[0].steps[0].relative_direction == RelativeDirection.continue_