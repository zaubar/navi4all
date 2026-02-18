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

from fastapi.testclient import TestClient

from main import app
from schemas.coordinates import Coordinates
from schemas.geocoding import GeocodingAutocompleteResponseModel
from schemas.place import Place, PlaceType
import endpoints.geocoding as geocoding_endpoint


class _FakeGeocodingAdaptor:
    def __init__(self):
        self.last_request = None

    async def autocomplete(self, _client, request):
        self.last_request = request
        return GeocodingAutocompleteResponseModel(
            timestamp=request.timestamp,
            results=[
                Place(
                    id="place-1",
                    name="Main Station",
                    type=PlaceType.ADDRESS,
                    address="Main Street 1, City",
                    street="Main Street",
                    locality="City",
                    postcode="12345",
                    coordinates=Coordinates(lat=49.44, lon=7.75),
                )
            ],
        )


def test_geocoding_autocomplete_success(monkeypatch):
    fake_adaptor = _FakeGeocodingAdaptor()
    monkeypatch.setattr(geocoding_endpoint, "adaptor", fake_adaptor)
    client = TestClient(app)

    response = client.get(
        "/v1/geocoding/autocomplete",
        params={
            "timestamp": "2026-02-18T10:30:00",
            "query": "main station",
            "focus_point_lat": 49.44,
            "focus_point_lon": 7.75,
            "limit": 3,
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["results"][0]["name"] == "Main Station"
    assert fake_adaptor.last_request.focus_point == Coordinates(lat=49.44, lon=7.75)
    assert fake_adaptor.last_request.limit == 3


def test_geocoding_autocomplete_without_complete_focus_point(monkeypatch):
    fake_adaptor = _FakeGeocodingAdaptor()
    monkeypatch.setattr(geocoding_endpoint, "adaptor", fake_adaptor)
    client = TestClient(app)

    response = client.get(
        "/v1/geocoding/autocomplete",
        params={
            "timestamp": datetime(2026, 2, 18, 10, 30, 0).isoformat(),
            "query": "main station",
            "focus_point_lat": 49.44,
        },
    )

    assert response.status_code == 200
    assert fake_adaptor.last_request.focus_point is None
