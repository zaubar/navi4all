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

import pytest
from fastapi import HTTPException, testclient

from schemas.coordinates import Coordinates
from schemas.geocoding import (
    GeocodingReverseRequestModel,
    SupportedGeocodingProviders,
)
from schemas.place import PlaceType
from services.adaptors.geocoding import GeocodingAdaptor


class _FakeResponse:
    def __init__(self, status_code: int, payload: dict):
        self.status_code = status_code
        self._payload = payload

    def json(self) -> dict:
        return self._payload


class _FakeAsyncClient:
    def __init__(self, response: _FakeResponse):
        self.response = response
        self.last_url = None
        self.last_params = None

    async def get(self, url: str, params: dict):
        self.last_url = url
        self.last_params = params
        return self.response


def _pelias_reverse_payload() -> dict:
    return {
        "features": [
            {
                "properties": {
                    "id": "addr-1",
                    "name": "Main Station",
                    "label": "Main Station, Bahnhofplatz 1, City, 12345",
                    "layer": "address",
                    "street": "Bahnhofplatz",
                    "locality": "City",
                    "postalcode": "12345",
                },
                "geometry": {"coordinates": [7.75, 49.44]},
            },
            {
                "properties": {
                    "id": "street-1",
                    "name": "Bahnhofstraße",
                    "label": "Bahnhofstraße, City",
                    "layer": "street",
                },
                "geometry": {"coordinates": [7.76, 49.45]},
            },
        ]
    }


def test_build_request_pelias_reverse() -> None:
    adaptor = GeocodingAdaptor(
        provider=SupportedGeocodingProviders.PELIAS,
        api_url="https://pelias.example/",
        api_key="secret",
    )
    request = GeocodingReverseRequestModel(
        lat=49.44,
        lon=7.75,
        timestamp=datetime(2026, 2, 18, 10, 0, 0),
    )

    url, params = adaptor._build_request_pelias_reverse(request)

    assert url == "https://pelias.example/v1/reverse"
    assert params["api_key"] == "secret"
    assert params["point.lat"] == 49.44
    assert params["point.lon"] == 7.75
    assert "layers" in params


def test_process_response_pelias_reverse() -> None:
    adaptor = GeocodingAdaptor(
        provider=SupportedGeocodingProviders.PELIAS,
        api_url="https://pelias.example/",
        api_key="secret",
    )
    response = _FakeResponse(status_code=200, payload=_pelias_reverse_payload())

    places = adaptor._process_response_pelias_reverse(response)

    assert len(places) == 2
    assert places[0].name == "Main Station"
    assert places[0].type == PlaceType.ADDRESS
    assert places[0].coordinates.lat == 49.44
    assert places[0].coordinates.lon == 7.75
    assert places[1].type == PlaceType.STREET


def test_process_response_pelias_reverse_defaults_missing_fields() -> None:
    adaptor = GeocodingAdaptor(
        provider=SupportedGeocodingProviders.PELIAS,
        api_url="https://pelias.example/",
        api_key="secret",
    )
    response = _FakeResponse(
        status_code=200,
        payload={
            "features": [
                {
                    "properties": {
                        "id": "poi-1",
                        "name": "Dom",
                        "label": "Dom, Regensburg",
                        "layer": "venue",
                    },
                    "geometry": {"coordinates": [12.1, 49.02]},
                }
            ]
        },
    )

    places = adaptor._process_response_pelias_reverse(response)

    assert len(places) == 1
    assert places[0].type == PlaceType.ADDRESS
    assert places[0].street is None
    assert places[0].locality is None
    assert places[0].postcode is None


@pytest.mark.asyncio
async def test_reverse_returns_limited_results() -> None:
    adaptor = GeocodingAdaptor(
        provider=SupportedGeocodingProviders.PELIAS,
        api_url="https://pelias.example/",
        api_key="secret",
    )
    request = GeocodingReverseRequestModel(
        lat=49.44,
        lon=7.75,
        timestamp=datetime(2026, 2, 18, 10, 0, 0),
        limit=1,
    )
    client = _FakeAsyncClient(_FakeResponse(status_code=200, payload=_pelias_reverse_payload()))

    response = await adaptor.reverse(client, request)

    assert response.timestamp == request.timestamp
    assert len(response.results) == 1
    assert client.last_url == "https://pelias.example/v1/reverse"


@pytest.mark.asyncio
async def test_reverse_raises_for_non_200() -> None:
    adaptor = GeocodingAdaptor(
        provider=SupportedGeocodingProviders.PELIAS,
        api_url="https://pelias.example/",
        api_key="secret",
    )
    request = GeocodingReverseRequestModel(
        lat=49.44,
        lon=7.75,
        timestamp=datetime(2026, 2, 18, 10, 0, 0),
    )
    client = _FakeAsyncClient(_FakeResponse(status_code=503, payload={"features": []}))

    with pytest.raises(HTTPException) as exc_info:
        await adaptor.reverse(client, request)

    assert exc_info.value.status_code == 503


@pytest.mark.asyncio
async def test_reverse_raises_for_unsupported_provider() -> None:
    adaptor = GeocodingAdaptor(
        provider=SupportedGeocodingProviders.NONE,
        api_url="https://pelias.example/",
        api_key="secret",
    )
    request = GeocodingReverseRequestModel(
        lat=49.44,
        lon=7.75,
        timestamp=datetime(2026, 2, 18, 10, 0, 0),
    )
    client = _FakeAsyncClient(_FakeResponse(status_code=200, payload={"features": []}))

    with pytest.raises(HTTPException) as exc_info:
        await adaptor.reverse(client, request)

    assert exc_info.value.status_code == 400
