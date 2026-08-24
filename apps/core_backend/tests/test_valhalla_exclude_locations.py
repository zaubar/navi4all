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

"""Valhalla exclude_locations + pedestrian_profile passthrough.

exclude_locations powers re-routing around reported obstacles: the caller
sends the obstacle coordinates and Valhalla hard-avoids the matching edges.
pedestrian_profile lets a caller pin the costing type explicitly, overriding
the type otherwise derived from surface_quality / accessible / grade_category.
"""

import json
from urllib.parse import unquote

import polyline
import pytest

from schemas.coordinates import Coordinates
from schemas.routing import (
    Mode,
    PedestrianProfile,
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
                        "street_names": ["Teststraße"],
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


def _request(
    exclude_locations=None,
    pedestrian_profile=None,
    accessible=False,
) -> RoutingPlanRequestModel:
    return RoutingPlanRequestModel(
        origin=Coordinates(lat=49.0201, lon=12.0958),
        destination=Coordinates(lat=49.0212, lon=12.0954),
        date="2026-08-20",
        time="12:00:00",
        transport_modes=[Mode.walk],
        walk=WalkOptions(speed=5.0, avoid=False),
        accessible=accessible,
        exclude_locations=exclude_locations,
        pedestrian_profile=pedestrian_profile,
    )


def _adaptor() -> ValhallaAdaptor:
    adaptor = ValhallaAdaptor(url="http://valhalla.example")
    adaptor.redis_client = _FakeRedis()
    return adaptor


def _sent_request(client: _FakeAsyncClient) -> dict:
    return json.loads(client.requested_urls[0].split("json=", 1)[1])


@pytest.mark.asyncio
async def test_exclude_locations_forwarded_to_valhalla() -> None:
    adaptor = _adaptor()
    client = _FakeAsyncClient({"trip": _trip()})

    await adaptor.make_plan_request(
        client,
        _request(exclude_locations=[Coordinates(lat=49.0205, lon=12.0957)]),
    )

    request_json = _sent_request(client)
    assert request_json["exclude_locations"] == [{"lat": 49.0205, "lon": 12.0957}]


@pytest.mark.asyncio
async def test_no_exclude_locations_key_when_unset() -> None:
    adaptor = _adaptor()
    client = _FakeAsyncClient({"trip": _trip()})

    await adaptor.make_plan_request(client, _request())

    assert "exclude_locations" not in _sent_request(client)


@pytest.mark.asyncio
async def test_pedestrian_profile_overrides_derived_type() -> None:
    # accessible=False would derive "foot"; the explicit profile must win.
    adaptor = _adaptor()
    client = _FakeAsyncClient({"trip": _trip()})

    await adaptor.make_plan_request(
        client, _request(pedestrian_profile=PedestrianProfile.wheelchair)
    )

    request_json = _sent_request(client)
    assert request_json["costing_options"]["pedestrian"]["type"] == "wheelchair"


@pytest.mark.asyncio
async def test_derived_type_kept_without_profile() -> None:
    adaptor = _adaptor()
    client = _FakeAsyncClient({"trip": _trip()})

    await adaptor.make_plan_request(client, _request(accessible=True))

    request_json = _sent_request(client)
    assert request_json["costing_options"]["pedestrian"]["type"] == "wheelchair"
