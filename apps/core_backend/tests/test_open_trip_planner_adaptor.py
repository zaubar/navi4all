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
from pathlib import Path
import json
import uuid

import pytest

from core.config import settings
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
from services.adaptors.open_trip_planner import OpenTripPlannerAdaptor


class _FakeRedis:
    def __init__(self, data: dict[bytes, bytes]):
        self._data = data

    def hgetall(self, _: str) -> dict[bytes, bytes]:
        return self._data


class _FakeStop:
    def __init__(self, name: str):
        self.name = name


class _FakeTrip:
    def __init__(self, trip_headsign: str | None, stops: list[_FakeStop]):
        self.trip_headsign = trip_headsign
        self.stops = stops


class _FakeLeg:
    def __init__(self, headsign: str | None, trip: _FakeTrip | None):
        self.headsign = headsign
        self.trip = trip


def _itinerary_cache_bytes() -> dict[bytes, bytes]:
    now = datetime(2026, 2, 18, 12, 0, 0)
    itinerary = ItineraryResponseModel(
        itinerary_id=uuid.uuid4(),
        duration=120,
        start_time=now,
        end_time=now + timedelta(minutes=2),
        origin=Coordinates(lat=49.44, lon=7.75),
        destination=Coordinates(lat=49.45, lon=7.76),
        legs=[
            LegDetailed(
                mode=Mode.walk,
                duration=120,
                distance=150,
                geometry="abcd",
                start_time=now,
                end_time=now + timedelta(minutes=2),
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
                        distance=150,
                        lon=7.75,
                        lat=49.44,
                        relative_direction=RelativeDirection.depart,
                        street_name="Main St",
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


def test_load_graphql_template_reads_existing_file(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    template = tmp_path / "plan.graphql"
    template.write_text("query Plan { plan { date } }", encoding="utf-8")
    monkeypatch.setattr(settings, "TEMPLATES_DIR", str(tmp_path))

    adaptor = OpenTripPlannerAdaptor(url="https://otp.example/graphql")

    content = adaptor._load_graphql_template("plan.graphql")

    assert "query Plan" in content


def test_load_graphql_template_raises_if_missing(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setattr(settings, "TEMPLATES_DIR", str(tmp_path))
    adaptor = OpenTripPlannerAdaptor(url="https://otp.example/graphql")

    with pytest.raises(FileNotFoundError):
        adaptor._load_graphql_template("missing.graphql")


def test_get_leg_headsign_uses_fallback_order() -> None:
    adaptor = OpenTripPlannerAdaptor(url="https://otp.example/graphql")

    assert adaptor._get_leg_headsign(_FakeLeg(headsign="H1", trip=None)) == "H1"
    assert (
        adaptor._get_leg_headsign(
            _FakeLeg(headsign=None, trip=_FakeTrip(trip_headsign="H2", stops=[]))
        )
        == "H2"
    )
    assert (
        adaptor._get_leg_headsign(
            _FakeLeg(
                headsign=None,
                trip=_FakeTrip(trip_headsign=None, stops=[_FakeStop("Last Stop")]),
            )
        )
        == "Last Stop"
    )
    assert adaptor._get_leg_headsign(_FakeLeg(headsign=None, trip=None)) == ""


class _FakeOTPStep:
    """Minimal OTP step stub for _build_steps testing."""
    def __init__(self, lat: float, lon: float, distance: float = 10.0,
                 street_name: str = "", bogus_name: bool = False):
        self.lat = lat
        self.lon = lon
        self.distance = distance
        self.street_name = street_name
        self.bogus_name = bogus_name


class TestBuildSteps:
    """Verify _build_steps computes correct turn directions.

    The method pre-computes segment bearings so every step (except the
    last) compares its incoming segment with its outgoing segment.

    Coordinate reference (Regensburg Domplatz area):
      lat ~49.019, lon ~12.098
    """

    def _fake_step(self, lat: float, lon: float) -> _FakeOTPStep:
        return _FakeOTPStep(lat=lat, lon=lon)

    def test_depart_only(self) -> None:
        """Single step → depart."""
        adaptor = OpenTripPlannerAdaptor(url="https://otp.example/graphql")
        steps = adaptor._build_steps([self._fake_step(49.019, 12.098)])
        assert len(steps) == 1
        assert steps[0].relative_direction == RelativeDirection.depart

    def test_two_steps_continues(self) -> None:
        """Two steps on the same bearing → step 1 continues, no turn angle to compute."""
        adaptor = OpenTripPlannerAdaptor(url="https://otp.example/graphql")
        steps = adaptor._build_steps([
            self._fake_step(49.0190, 12.0980),
            self._fake_step(49.0195, 12.0980),  # directly north
        ])
        assert len(steps) == 2
        assert steps[0].relative_direction == RelativeDirection.depart
        assert steps[1].relative_direction == RelativeDirection.continue_

    def test_three_steps_right_turn(self) -> None:
        """Three steps forming a right-angle → step 1 is right, step 2 continues / last."""
        adaptor = OpenTripPlannerAdaptor(url="https://otp.example/graphql")
        # Step 0→1: northward; Step 1→2: eastward  → right turn at step 1
        steps = adaptor._build_steps([
            self._fake_step(49.0190, 12.0980),  # 0: depart
            self._fake_step(49.0195, 12.0980),  # 1: 90° right (north → east)
            self._fake_step(49.0195, 12.0985),  # 2: last, no outgoing segment
        ])
        assert len(steps) == 3
        assert steps[0].relative_direction == RelativeDirection.depart
        assert steps[1].relative_direction == RelativeDirection.right
        assert steps[2].relative_direction == RelativeDirection.continue_

    def test_three_steps_left_turn(self) -> None:
        """Three steps forming a left-turn angle → step 1 is left."""
        adaptor = OpenTripPlannerAdaptor(url="https://otp.example/graphql")
        # Step 0→1: eastward; Step 1→2: northward → left turn at step 1
        steps = adaptor._build_steps([
            self._fake_step(49.0190, 12.0980),  # 0: depart
            self._fake_step(49.0190, 12.0985),  # 1: 90° left (east → north)
            self._fake_step(49.0195, 12.0985),  # 2: last
        ])
        assert len(steps) == 3
        assert steps[0].relative_direction == RelativeDirection.depart
        assert steps[1].relative_direction == RelativeDirection.left
        assert steps[2].relative_direction == RelativeDirection.continue_

    def test_four_steps_straight_then_right(self) -> None:
        """Four steps: depart, continue (straight), right, last."""
        adaptor = OpenTripPlannerAdaptor(url="https://otp.example/graphql")
        # Step 0→1→2→3: straight, then right
        steps = adaptor._build_steps([
            self._fake_step(49.0190, 12.0980),
            self._fake_step(49.0195, 12.0980),  # straight
            self._fake_step(49.0200, 12.0980),  # straight → continue_
            self._fake_step(49.0200, 12.0985),  # right → last (continue_)
        ])
        assert len(steps) == 4
        assert steps[0].relative_direction == RelativeDirection.depart
        assert steps[1].relative_direction == RelativeDirection.continue_
        assert steps[2].relative_direction == RelativeDirection.right
        assert steps[3].relative_direction == RelativeDirection.continue_

@pytest.mark.asyncio
async def test_get_itinerary_deserializes_cached_payload() -> None:
    adaptor = OpenTripPlannerAdaptor(url="https://otp.example/graphql")
    adaptor.redis_client = _FakeRedis(_itinerary_cache_bytes())

    itinerary = await adaptor.get_itinerary("any-id")

    assert itinerary.duration == 120
    assert itinerary.legs[0].mode == Mode.walk
    assert itinerary.legs[0].steps[0].relative_direction == RelativeDirection.depart