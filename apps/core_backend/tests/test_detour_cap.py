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

from datetime import datetime
from uuid import uuid4

import pytest

from core.config import settings
from schemas.coordinates import Coordinates
from schemas.routing import (
    ItinerarySummary,
    LegSummary,
    Mode,
    RoutingPlanRequestModel,
    RoutingPlanSummaryResponseModel,
    WalkOptions,
)
from services.detour_cap import apply_detour_cap, pick_order


def _request(surface_quality=1.0, modes=None) -> RoutingPlanRequestModel:
    return RoutingPlanRequestModel(
        origin=Coordinates(lat=49.02025, lon=12.0946),
        destination=Coordinates(lat=49.02007, lon=12.096554),
        date="2026-09-19",
        time="12:00:00",
        transport_modes=modes or [Mode.walk],
        walk=WalkOptions(speed=3.0, avoid=False, surface_quality=surface_quality),
        accessible=True,
    )


def _plan(*lengths: int) -> RoutingPlanSummaryResponseModel:
    now = datetime(2026, 9, 19, 12, 0, 0)
    return RoutingPlanSummaryResponseModel(
        itineraries=[
            ItinerarySummary(
                itinerary_id=uuid4(),
                duration=length,
                start_time=now,
                end_time=now,
                origin=Coordinates(lat=49.02025, lon=12.0946),
                destination=Coordinates(lat=49.02007, lon=12.096554),
                legs=[LegSummary(mode=Mode.walk, duration=length, distance=length, geometry="_p~iF~ps|U")],
            )
            for length in lengths
        ]
    )


def _lengths(plan) -> list[int]:
    return [sum(leg.distance for leg in itinerary.legs) for itinerary in plan.itineraries]


class _FakeAdaptor:
    """Stands in for ValhallaAdaptor; answers the unpenalised reference request."""

    def __init__(self, reference_m=173, error=None, empty=False):
        self._reference_m = reference_m
        self._error = error
        self._empty = empty
        self.requests = []

    async def make_plan_request(self, client, request, summarized=True):
        self.requests.append(request)
        if self._error:
            raise self._error
        return _plan() if self._empty else _plan(self._reference_m)


# --- pick_order -----------------------------------------------------------


def test_the_first_itinerary_within_the_cap_leads():
    # Rathausplatz -> Goliathhaus, "smooth only", prod 2026-09-19.
    assert pick_order([328, 219, 598], reference=173, max_ratio=1.5) == [1, 0, 2]


def test_a_leader_within_the_cap_keeps_its_place():
    assert pick_order([209, 243], reference=196, max_ratio=1.5) == [0, 1]


def test_engine_order_decides_between_two_within_the_cap():
    assert pick_order([400, 250, 240], reference=173, max_ratio=1.5) == [1, 0, 2]


def test_the_shortest_leads_when_none_is_within_the_cap():
    assert pick_order([1280, 1100, 1190], reference=600, max_ratio=1.5) == [1, 0, 2]


def test_no_itineraries_is_no_order():
    assert pick_order([], reference=173, max_ratio=1.5) == []


# --- apply_detour_cap -----------------------------------------------------


async def test_reorders_a_surface_avoiding_plan():
    adaptor = _FakeAdaptor(reference_m=173)
    request = _request(surface_quality=1.0)
    plan = _plan(328, 219, 598)
    ids = [itinerary.itinerary_id for itinerary in plan.itineraries]

    capped = await apply_detour_cap(None, adaptor, request, plan)

    assert _lengths(capped) == [219, 328, 598]
    # Nothing is dropped, only reordered.
    assert sorted(map(str, ids)) == sorted(str(i.itinerary_id) for i in capped.itineraries)


async def test_the_reference_request_carries_no_surface_penalty_and_the_original_is_untouched():
    adaptor = _FakeAdaptor()
    request = _request(surface_quality=0.5)

    await apply_detour_cap(None, adaptor, request, _plan(282, 173, 216))

    assert len(adaptor.requests) == 1
    assert adaptor.requests[0].walk.surface_quality is None
    assert adaptor.requests[0].num_itineraries == 1
    assert adaptor.requests[0].accessible is True
    assert request.walk.surface_quality == 0.5


async def test_both_accessible_surface_steps_are_capped():
    for surface_quality in (0.5, 1.0):
        capped = await apply_detour_cap(None, _FakeAdaptor(), _request(surface_quality), _plan(328, 219))
        assert _lengths(capped) == [219, 328]


@pytest.mark.parametrize("surface_quality", [None, 0.0, 0.3])
async def test_plans_without_a_surface_penalty_are_left_alone(surface_quality):
    adaptor = _FakeAdaptor()

    capped = await apply_detour_cap(None, adaptor, _request(surface_quality), _plan(328, 219))

    assert _lengths(capped) == [328, 219]
    assert adaptor.requests == []


async def test_a_single_itinerary_needs_no_reference_request():
    adaptor = _FakeAdaptor()

    capped = await apply_detour_cap(None, adaptor, _request(), _plan(328))

    assert _lengths(capped) == [328]
    assert adaptor.requests == []


async def test_a_leader_that_is_already_the_shortest_needs_no_reference_request():
    adaptor = _FakeAdaptor()

    capped = await apply_detour_cap(None, adaptor, _request(), _plan(209, 243, 260))

    assert _lengths(capped) == [209, 243, 260]
    assert adaptor.requests == []


async def test_non_walk_plans_are_left_alone():
    adaptor = _FakeAdaptor()

    capped = await apply_detour_cap(None, adaptor, _request(modes=[Mode.bicycle]), _plan(328, 219))

    assert _lengths(capped) == [328, 219]
    assert adaptor.requests == []


async def test_a_ratio_of_zero_disables_the_cap(monkeypatch):
    monkeypatch.setattr(settings, "VALHALLA_SURFACE_DETOUR_MAX_RATIO", 0.0)
    adaptor = _FakeAdaptor()

    capped = await apply_detour_cap(None, adaptor, _request(), _plan(328, 219))

    assert _lengths(capped) == [328, 219]
    assert adaptor.requests == []


async def test_fails_open_when_the_reference_request_fails():
    capped = await apply_detour_cap(None, _FakeAdaptor(error=RuntimeError("engine down")), _request(), _plan(328, 219))

    assert _lengths(capped) == [328, 219]


async def test_fails_open_when_the_reference_plan_is_empty():
    capped = await apply_detour_cap(None, _FakeAdaptor(empty=True), _request(), _plan(328, 219))

    assert _lengths(capped) == [328, 219]
