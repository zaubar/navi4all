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

import asyncio
from datetime import datetime
from uuid import uuid4

import polyline
import pytest

from schemas.coordinates import Coordinates
from schemas.routing import (
    GradeCategory,
    ItinerarySummary,
    LegSummary,
    Mode,
    RoutingPlanRequestModel,
    RoutingPlanSummaryResponseModel,
    WalkOptions,
)
from services.grade_gate import (
    apply_grade_gate,
    max_sustained_grade_percent,
    pick_itineraries,
    resample_shape,
)


# A straight ~330 m west-to-east line through the Regensburg old town.
_SHAPE = [(49.0203, 12.0944), (49.0203, 12.0989)]


def _request(grade_category=GradeCategory.gentle, modes=None) -> RoutingPlanRequestModel:
    return RoutingPlanRequestModel(
        origin=Coordinates(lat=49.0203, lon=12.0944),
        destination=Coordinates(lat=49.0203, lon=12.0989),
        date="2026-08-19",
        time="12:00:00",
        transport_modes=modes or [Mode.walk],
        walk=WalkOptions(speed=5.0, avoid=False),
        grade_category=grade_category,
    )


def _summary(*geometries: str) -> RoutingPlanSummaryResponseModel:
    now = datetime(2026, 8, 19, 12, 0, 0)
    return RoutingPlanSummaryResponseModel(
        itineraries=[
            ItinerarySummary(
                itinerary_id=uuid4(),
                duration=300,
                start_time=now,
                end_time=now,
                origin=Coordinates(lat=49.0203, lon=12.0944),
                destination=Coordinates(lat=49.0203, lon=12.0989),
                legs=[
                    LegSummary(mode=Mode.walk, duration=300, distance=330, geometry=geom)
                ],
            )
            for geom in geometries
        ]
    )


class _FakeHeightResponse:
    def __init__(self, range_height):
        self._range_height = range_height

    def raise_for_status(self):
        return None

    def json(self):
        return {"range_height": self._range_height}


class _FakeHeightClient:
    """Stands in for httpx.AsyncClient; serves queued /height responses."""

    def __init__(self, responses=None, error=None):
        self._responses = list(responses or [])
        self._error = error
        self.calls = []

    async def post(self, url, json=None, timeout=None):
        self.calls.append({"url": url, "json": json})
        if self._error:
            raise self._error
        return _FakeHeightResponse(self._responses.pop(0))


def _flat_profile(length_m=330, step=15):
    return [[d, 340] for d in range(0, length_m + 1, step)]


def _steep_profile(length_m=330, step=15, grade=0.10):
    return [[d, 340 + d * grade] for d in range(0, length_m + 1, step)]


class TestResampleShape:
    def test_inserts_intermediate_points_on_long_segments(self):
        resampled = resample_shape(_SHAPE, step_m=15.0)
        assert len(resampled) > 20
        assert resampled[0] == _SHAPE[0]
        assert resampled[-1] == _SHAPE[-1]

    def test_short_segments_untouched(self):
        pts = [(49.0203, 12.0944), (49.02031, 12.09441)]
        assert resample_shape(pts, step_m=15.0) == pts


class TestMaxSustainedGrade:
    def test_flat_is_zero(self):
        assert max_sustained_grade_percent(_flat_profile()) == 0.0

    def test_detects_sustained_ten_percent(self):
        grade = max_sustained_grade_percent(_steep_profile(grade=0.10))
        assert grade == pytest.approx(10.0, abs=0.5)

    def test_single_sample_spike_is_smoothed_by_window(self):
        profile = _flat_profile()
        profile[10][1] += 3  # one 3 m DEM glitch on flat ground
        grade = max_sustained_grade_percent(profile, window_m=20.0)
        assert grade < 6.0

    def test_no_coverage_returns_none(self):
        assert max_sustained_grade_percent([[0, None], [15, None]]) is None


class TestPickItineraries:
    def test_drops_steep_when_compliant_exists(self):
        assert pick_itineraries([2.0, 9.0, 4.0], 6.0) == [0, 2]

    def test_keeps_least_steep_when_none_comply(self):
        assert pick_itineraries([9.0, 7.5, 12.0], 6.0) == [1]

    def test_unknown_grades_count_as_compliant(self):
        assert pick_itineraries([None, 9.0], 6.0) == [0]


class TestApplyGradeGate:
    def test_noop_without_gentle_grade_category(self):
        response = _summary(polyline.encode(_SHAPE))
        client = _FakeHeightClient()
        result = asyncio.run(
            apply_grade_gate(client, _request(grade_category=None), response)
        )
        assert len(result.itineraries) == 1
        assert client.calls == []

    def test_drops_steep_itinerary_when_flat_alternative_exists(self):
        response = _summary(polyline.encode(_SHAPE), polyline.encode(_SHAPE))
        kept_id = response.itineraries[0].itinerary_id
        client = _FakeHeightClient(responses=[_flat_profile(), _steep_profile()])
        result = asyncio.run(apply_grade_gate(client, _request(), response))
        assert [i.itinerary_id for i in result.itineraries] == [kept_id]

    def test_keeps_least_steep_when_all_exceed_threshold(self):
        response = _summary(polyline.encode(_SHAPE), polyline.encode(_SHAPE))
        least_steep_id = response.itineraries[1].itinerary_id
        client = _FakeHeightClient(
            responses=[_steep_profile(grade=0.12), _steep_profile(grade=0.08)]
        )
        result = asyncio.run(apply_grade_gate(client, _request(), response))
        assert [i.itinerary_id for i in result.itineraries] == [least_steep_id]

    def test_fails_open_on_height_error(self):
        response = _summary(polyline.encode(_SHAPE), polyline.encode(_SHAPE))
        client = _FakeHeightClient(error=RuntimeError("valhalla down"))
        result = asyncio.run(apply_grade_gate(client, _request(), response))
        assert len(result.itineraries) == 2

    def test_skips_non_walk_legs(self):
        response = _summary(polyline.encode(_SHAPE))
        response.itineraries[0].legs[0].mode = Mode.bus
        client = _FakeHeightClient()
        result = asyncio.run(apply_grade_gate(client, _request(), response))
        assert len(result.itineraries) == 1
        assert client.calls == []
