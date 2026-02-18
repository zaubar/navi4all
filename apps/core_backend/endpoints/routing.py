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

import httpx
from fastapi import APIRouter, HTTPException
from typing import Union
from schemas.routing import (
    RoutingEngine,
    RoutingPlanRequestModel,
    RoutingPlanSummaryResponseModel,
    RoutingPlanDetailedResponseModel,
    ItineraryResponseModel,
)
from services.adaptors.open_trip_planner import OpenTripPlannerAdaptor
from services.adaptors.valhalla import ValhallaAdaptor
from services.adaptors.hybrid import HybridAdaptor
from core.config import settings


router = APIRouter(prefix="/routing")
adaptor_otp = OpenTripPlannerAdaptor(
    url=settings.ROUTING_ENGINE_URLS[RoutingEngine.open_trip_planner]
)
adaptor_otp_kl = OpenTripPlannerAdaptor(
    url=settings.ROUTING_ENGINE_URLS[RoutingEngine.open_trip_planner_kl]
)
adaptor_valhalla = ValhallaAdaptor(
    url=settings.ROUTING_ENGINE_URLS[RoutingEngine.valhalla]
)
adaptor_hybrid = HybridAdaptor(
    otp_adaptor=adaptor_otp_kl,
    valhalla_adaptor=adaptor_valhalla,
)


@router.post(
    "/plan",
    response_model=RoutingPlanSummaryResponseModel,
)
async def plan(
    request: RoutingPlanRequestModel,
    engine: RoutingEngine = RoutingEngine.open_trip_planner,
):
    async with httpx.AsyncClient() as client:
        if engine == RoutingEngine.open_trip_planner:
            adaptor = adaptor_otp
        elif engine == RoutingEngine.open_trip_planner_kl:
            adaptor = adaptor_otp_kl
        elif engine == RoutingEngine.valhalla:
            adaptor = adaptor_valhalla
        elif engine == RoutingEngine.hybrid:
            adaptor = adaptor_hybrid
        else:
            raise ValueError("Unsupported routing engine specified.")

        try:
            response = await adaptor.make_plan_request(
                client, request, summarized=True
            )
        except httpx.HTTPStatusError as e:
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"Error making plan request: HTTPStatus {e.response.status_code}",
            )

    return response


@router.post(
    "/itinerary-detailed",
    response_model=RoutingPlanDetailedResponseModel,
)
async def itinerary_detailed(
    request: RoutingPlanRequestModel,
    engine: RoutingEngine = RoutingEngine.open_trip_planner,
):
    async with httpx.AsyncClient() as client:
        if engine == RoutingEngine.open_trip_planner:
            adaptor = adaptor_otp
        elif engine == RoutingEngine.open_trip_planner_kl:
            adaptor = adaptor_otp_kl
        elif engine == RoutingEngine.valhalla:
            adaptor = adaptor_valhalla
        elif engine == RoutingEngine.hybrid:
            adaptor = adaptor_hybrid
        else:
            raise ValueError("Unsupported routing engine specified.")

        try:
            response = await adaptor.make_plan_request(
                client, request, summarized=False
            )
        except httpx.HTTPStatusError as e:
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"Error making plan request: HTTPStatus {e.response.status_code}",
            )

    return response


@router.get("/itinerary/{itinerary_id}", response_model=ItineraryResponseModel)
async def get_itinerary(
    itinerary_id: str, engine: RoutingEngine = RoutingEngine.open_trip_planner
):
    if engine == RoutingEngine.open_trip_planner:
        adaptor = adaptor_otp
    elif engine == RoutingEngine.open_trip_planner_kl:
        adaptor = adaptor_otp_kl
    elif engine == RoutingEngine.valhalla:
        adaptor = adaptor_valhalla
    elif engine == RoutingEngine.hybrid:
        adaptor = adaptor_hybrid
    else:
        raise ValueError("Unsupported routing engine specified.")

    response = await adaptor.get_itinerary(itinerary_id)

    return response
