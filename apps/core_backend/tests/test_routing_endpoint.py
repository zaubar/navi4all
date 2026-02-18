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
from uuid import uuid4

import httpx
from fastapi.testclient import TestClient

from main import app
from schemas.coordinates import Coordinates
from schemas.routing import (
    ItineraryDetailed,
    ItineraryResponseModel,
    ItinerarySummary,
    LegDetailed,
    LegSummary,
    Mode,
    Place,
    PlaceType,
    RelativeDirection,
    RoutingEngine,
    RoutingPlanDetailedResponseModel,
    RoutingPlanSummaryResponseModel,
    Step,
)
import endpoints.routing as routing_endpoint


class _FakeRoutingAdaptor:
    def __init__(self, summary_response=None, detailed_response=None, itinerary_response=None, error=None):
        self.summary_response = summary_response
        self.detailed_response = detailed_response
        self.itinerary_response = itinerary_response
        self.error = error
        self.last_call = None

    async def make_plan_request(self, _client, request, summarized=True):
        self.last_call = {"request": request, "summarized": summarized}
        if self.error:
            raise self.error
        return self.summary_response if summarized else self.detailed_response

    async def get_itinerary(self, itinerary_id: str):
        self.last_call = {"itinerary_id": itinerary_id}
        if self.error:
            raise self.error
        return self.itinerary_response


def _summary_response() -> RoutingPlanSummaryResponseModel:
    now = datetime(2026, 2, 18, 10, 0, 0)
    return RoutingPlanSummaryResponseModel(
        itineraries=[
            ItinerarySummary(
                itinerary_id=uuid4(),
                duration=600,
                start_time=now,
                end_time=now + timedelta(minutes=10),
                origin=Coordinates(lat=49.44, lon=7.75),
                destination=Coordinates(lat=49.45, lon=7.76),
                legs=[
                    LegSummary(
                        mode=Mode.walk,
                        duration=600,
                        distance=700,
                        geometry="abcd",
                    )
                ],
            )
        ]
    )


def _detailed_response() -> RoutingPlanDetailedResponseModel:
    now = datetime(2026, 2, 18, 10, 0, 0)
    return RoutingPlanDetailedResponseModel(
        itineraries=[
            ItineraryDetailed(
                itinerary_id=uuid4(),
                duration=600,
                start_time=now,
                end_time=now + timedelta(minutes=10),
                origin=Coordinates(lat=49.44, lon=7.75),
                destination=Coordinates(lat=49.45, lon=7.76),
                legs=[
                    LegDetailed(
                        mode=Mode.walk,
                        duration=600,
                        distance=700,
                        geometry="abcd",
                        start_time=now,
                        end_time=now + timedelta(minutes=10),
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
                                distance=700,
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
        ]
    )


def _itinerary_response() -> ItineraryResponseModel:
    return _detailed_response().itineraries[0]


def _routing_payload() -> dict:
    return {
        "origin": {"lat": 49.44, "lon": 7.75},
        "destination": {"lat": 49.45, "lon": 7.76},
        "date": "2026-02-18",
        "time": "10:00:00",
        "transport_modes": ["WALK"],
    }


def _patch_all_adaptors(monkeypatch, adaptor):
    monkeypatch.setattr(routing_endpoint, "adaptor_otp", adaptor)
    monkeypatch.setattr(routing_endpoint, "adaptor_otp_kl", adaptor)
    monkeypatch.setattr(routing_endpoint, "adaptor_valhalla", adaptor)
    monkeypatch.setattr(routing_endpoint, "adaptor_hybrid", adaptor)


def test_routing_plan_success(monkeypatch):
    fake_adaptor = _FakeRoutingAdaptor(summary_response=_summary_response())
    _patch_all_adaptors(monkeypatch, fake_adaptor)
    client = TestClient(app)

    response = client.post("/v1/routing/plan", json=_routing_payload())

    assert response.status_code == 200
    assert len(response.json()["itineraries"]) == 1
    assert fake_adaptor.last_call["summarized"] is True


def test_routing_itinerary_detailed_success(monkeypatch):
    fake_adaptor = _FakeRoutingAdaptor(detailed_response=_detailed_response())
    _patch_all_adaptors(monkeypatch, fake_adaptor)
    client = TestClient(app)

    response = client.post(
        "/v1/routing/itinerary-detailed",
        params={"engine": RoutingEngine.valhalla.value},
        json=_routing_payload(),
    )

    assert response.status_code == 200
    assert len(response.json()["itineraries"][0]["legs"]) == 1
    assert fake_adaptor.last_call["summarized"] is False


def test_routing_plan_translates_http_status_error(monkeypatch):
    error = httpx.HTTPStatusError(
        "bad gateway",
        request=httpx.Request("POST", "https://router.example"),
        response=httpx.Response(status_code=502),
    )
    fake_adaptor = _FakeRoutingAdaptor(error=error)
    _patch_all_adaptors(monkeypatch, fake_adaptor)
    client = TestClient(app)

    response = client.post("/v1/routing/plan", json=_routing_payload())

    assert response.status_code == 502
    assert "Error making plan request" in response.json()["detail"]


def test_routing_get_itinerary_success(monkeypatch):
    fake_adaptor = _FakeRoutingAdaptor(itinerary_response=_itinerary_response())
    _patch_all_adaptors(monkeypatch, fake_adaptor)
    client = TestClient(app)

    response = client.get("/v1/routing/itinerary/abc123")

    assert response.status_code == 200
    assert response.json()["duration"] == 600
    assert fake_adaptor.last_call["itinerary_id"] == "abc123"


def test_routing_plan_invalid_request_returns_422(monkeypatch):
    fake_adaptor = _FakeRoutingAdaptor(summary_response=_summary_response())
    _patch_all_adaptors(monkeypatch, fake_adaptor)
    client = TestClient(app)

    payload = _routing_payload()
    payload["date"] = "18-02-2026"
    response = client.post("/v1/routing/plan", json=payload)

    assert response.status_code == 422
