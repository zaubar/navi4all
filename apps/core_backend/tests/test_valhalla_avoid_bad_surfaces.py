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


"""Soft cobblestone avoidance: walk.surface_quality -> avoid_bad_surfaces.

The zaubar/valhalla fork (PR #1) adds the pedestrian costing option
``avoid_bad_surfaces`` (0..1, engine default 0): an edge whose surface is
paved_rough or worse costs 1 + 24 * value times more, and sett files as
paved_rough. The adaptor maps surface_quality >= 0.7 to the SMOOTH setting
(default 0.4), 0.3 < surface_quality < 0.7 to the MEDIUM setting (default
0.15) and sends nothing otherwise. The costing type rule, surface_smoothness,
alternates and destination_only_penalty are unchanged.
"""

import json
from urllib.parse import unquote

import polyline
import pytest
from pydantic import ValidationError

from core.config import settings
from schemas.coordinates import Coordinates
from schemas.routing import (
    GradeCategory,
    Mode,
    RoutingPlanRequestModel,
    WalkOptions,
)
from services.adaptors.valhalla import ValhallaAdaptor
from services.schemas.valhalla import (
    ValhallaPedestrianCostingOptions,
    ValhallaPedestrianCostingOptionsType,
)


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
    points = [(49.01816, 12.089419), (49.0190, 12.0912), (49.019975, 12.093253)]
    shape = polyline.encode(points, precision=6)
    return {
        "legs": [
            {
                "shape": shape,
                "summary": {"time": 300.0, "length": 0.41},
                "maneuvers": [
                    {
                        "type": 1,
                        "instruction": "Walk east.",
                        "street_names": ["Gesandtenstrasse"],
                        "travel_mode": "pedestrian",
                        "time": 300.0,
                        "length": 0.41,
                        "begin_shape_index": 0,
                        "end_shape_index": len(points) - 1,
                    }
                ],
            }
        ],
        "summary": {"time": 300.0, "length": 0.41},
    }


def _request(
    surface_quality: float | None = None, **overrides
) -> RoutingPlanRequestModel:
    fields = dict(
        origin=Coordinates(lat=49.01816, lon=12.089419),
        destination=Coordinates(lat=49.019975, lon=12.093253),
        date="2026-09-13",
        time="12:00:00",
        transport_modes=[Mode.walk],
        walk=WalkOptions(speed=2.5, avoid=False, surface_quality=surface_quality),
    )
    fields.update(overrides)
    return RoutingPlanRequestModel(**fields)


def _adaptor() -> ValhallaAdaptor:
    adaptor = ValhallaAdaptor(url="http://valhalla.example")
    adaptor.redis_client = _FakeRedis()
    return adaptor


async def _sent_pedestrian(request: RoutingPlanRequestModel) -> dict:
    client = _FakeAsyncClient({"trip": _trip()})
    await _adaptor().make_plan_request(client, request)
    request_json = json.loads(client.requested_urls[0].split("json=", 1)[1])
    return request_json["costing_options"]["pedestrian"]


@pytest.mark.parametrize("surface_quality", [1.0, 0.7])
async def test_smooth_band_sends_smooth_setting_and_keeps_the_type_from_accessible(
    surface_quality: float,
) -> None:
    # The surface level never picks the costing type: the type follows accessible.
    pedestrian = await _sent_pedestrian(_request(surface_quality))
    assert pedestrian["avoid_bad_surfaces"] == 0.4
    assert pedestrian["avoid_very_rough_surfaces"] == 1.0
    assert pedestrian["type"] == "foot"
    pedestrian = await _sent_pedestrian(_request(surface_quality, accessible=True))
    assert pedestrian["avoid_bad_surfaces"] == 0.4
    assert pedestrian["avoid_very_rough_surfaces"] == 1.0
    assert pedestrian["type"] == "wheelchair"


@pytest.mark.parametrize("surface_quality", [0.69, 0.5, 0.31])
async def test_medium_band_sends_medium_setting_and_keeps_foot(
    surface_quality: float,
) -> None:
    # The medium band softens the factor only; an accessible user keeps the
    # wheelchair type (stairs refused by access), a plain walker stays foot.
    pedestrian = await _sent_pedestrian(_request(surface_quality))
    assert pedestrian["avoid_bad_surfaces"] == 0.08
    assert pedestrian["avoid_very_rough_surfaces"] == 0.8
    assert pedestrian["type"] == "foot"
    pedestrian = await _sent_pedestrian(_request(surface_quality, accessible=True))
    assert pedestrian["avoid_bad_surfaces"] == 0.08
    assert pedestrian["avoid_very_rough_surfaces"] == 0.8
    assert pedestrian["type"] == "wheelchair"


@pytest.mark.parametrize("surface_quality", [0.3, 0.0])
async def test_low_band_does_not_send_the_option(surface_quality: float) -> None:
    pedestrian = await _sent_pedestrian(_request(surface_quality))
    assert "avoid_bad_surfaces" not in pedestrian
    assert "avoid_very_rough_surfaces" not in pedestrian
    assert pedestrian["type"] == "foot"


async def test_accessible_without_surface_quality_does_not_send_the_option() -> None:
    pedestrian = await _sent_pedestrian(_request(None, accessible=True))
    assert "avoid_bad_surfaces" not in pedestrian
    assert pedestrian["type"] == "wheelchair"


async def test_plain_walk_without_surface_quality_does_not_send_the_option() -> None:
    pedestrian = await _sent_pedestrian(_request(None))
    assert "avoid_bad_surfaces" not in pedestrian
    assert pedestrian["type"] == "foot"


async def test_no_walk_options_does_not_send_the_option() -> None:
    pedestrian = await _sent_pedestrian(_request(walk=None))
    assert "avoid_bad_surfaces" not in pedestrian


async def test_gentle_early_return_branch_carries_the_option() -> None:
    pedestrian = await _sent_pedestrian(
        _request(1.0, grade_category=GradeCategory.gentle)
    )
    assert pedestrian["avoid_bad_surfaces"] == 0.4
    assert pedestrian["avoid_very_rough_surfaces"] == 1.0
    assert pedestrian["use_hills"] == 0.0
    assert pedestrian["surface_smoothness"] == 1.0
    assert pedestrian["type"] == "wheelchair"


async def test_gentle_medium_band_carries_the_medium_setting() -> None:
    pedestrian = await _sent_pedestrian(
        _request(0.5, grade_category=GradeCategory.gentle)
    )
    assert pedestrian["avoid_bad_surfaces"] == 0.08
    assert pedestrian["use_hills"] == 0.0


async def test_explicit_pedestrian_profile_keeps_the_option() -> None:
    # A caller pinning type=foot with smooth-only surface still avoids cobbles.
    pedestrian = await _sent_pedestrian(
        _request(1.0, pedestrian_profile=ValhallaPedestrianCostingOptionsType.foot)
    )
    assert pedestrian["type"] == "foot"
    assert pedestrian["avoid_bad_surfaces"] == 0.4


async def test_existing_options_are_untouched() -> None:
    pedestrian = await _sent_pedestrian(_request(1.0))
    assert pedestrian["surface_smoothness"] == 1.0
    assert pedestrian["walking_speed"] == 2.5
    assert pedestrian["destination_only_penalty"] == 0


async def test_values_follow_the_settings(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "VALHALLA_AVOID_BAD_SURFACES_SMOOTH", 0.8)
    monkeypatch.setattr(settings, "VALHALLA_AVOID_BAD_SURFACES_MEDIUM", 0.2)
    monkeypatch.setattr(settings, "VALHALLA_AVOID_VERY_ROUGH_SURFACES_SMOOTH", 0.9)
    monkeypatch.setattr(settings, "VALHALLA_AVOID_VERY_ROUGH_SURFACES_MEDIUM", 0.3)
    smooth = await _sent_pedestrian(_request(0.9))
    assert (smooth["avoid_bad_surfaces"], smooth["avoid_very_rough_surfaces"]) == (0.8, 0.9)
    medium = await _sent_pedestrian(_request(0.5))
    assert (medium["avoid_bad_surfaces"], medium["avoid_very_rough_surfaces"]) == (0.2, 0.3)


@pytest.mark.parametrize("value", [1.5, -0.1])
def test_schema_rejects_out_of_range_values(value: float) -> None:
    with pytest.raises(ValidationError):
        ValhallaPedestrianCostingOptions(avoid_bad_surfaces=value)
    with pytest.raises(ValidationError):
        ValhallaPedestrianCostingOptions(avoid_very_rough_surfaces=value)
