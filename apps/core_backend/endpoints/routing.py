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
from schemas.routing import (
    RETIRED_ROUTING_ENGINES,
    RoutingEngine,
    RoutingPlanRequestModel,
    RoutingPlanSummaryResponseModel,
    RoutingPlanDetailedResponseModel,
    ItineraryResponseModel,
)
from services.adaptors.valhalla import ValhallaAdaptor
from services.detour_cap import apply_detour_cap
from services.grade_gate import apply_grade_gate
from core.config import settings


router = APIRouter(prefix="/routing")

# Valhalla is the only engine since 2026-09. The OpenTripPlanner and hybrid
# adaptor modules still exist in services/adaptors but nothing constructs
# them, so the service boots without OPEN_TRIP_PLANNER_URL / _KL_URL.
adaptor_valhalla = ValhallaAdaptor(url=settings.VALHALLA_URL)


def _select_adaptor(engine: RoutingEngine) -> ValhallaAdaptor:
    """Return the adaptor for ``engine`` or answer 400 for a retired one.

    Called before any HTTP client is opened so a retired engine never costs a
    connection. Unknown engine strings never reach here: FastAPI rejects them
    at query validation with a 422.
    """
    if engine in RETIRED_ROUTING_ENGINES:
        raise HTTPException(status_code=400, detail="engine retired: use valhalla")
    return adaptor_valhalla


@router.post(
    "/plan",
    response_model=RoutingPlanSummaryResponseModel,
)
async def plan(
    request: RoutingPlanRequestModel,
    engine: RoutingEngine = RoutingEngine.valhalla,
):
    adaptor = _select_adaptor(engine)
    async with httpx.AsyncClient() as client:
        try:
            response = await adaptor.make_plan_request(client, request, summarized=True)
        except httpx.HTTPStatusError as e:
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"Error making plan request: HTTPStatus {e.response.status_code}",
            )

        # Engine-agnostic hard gradient exclusion (no-op unless the request
        # asks for gentle grades on a walk mode) -- see services/grade_gate.py.
        response = await apply_grade_gate(client, request, response)
        # Surface-avoiding plans only: keep the first itinerary within the detour
        # cap, after the grade gate has removed what is too steep.
        response = await apply_detour_cap(client, adaptor, request, response)

    return response


@router.post(
    "/itinerary-detailed",
    response_model=RoutingPlanDetailedResponseModel,
)
async def itinerary_detailed(
    request: RoutingPlanRequestModel,
    engine: RoutingEngine = RoutingEngine.valhalla,
):
    adaptor = _select_adaptor(engine)
    async with httpx.AsyncClient() as client:
        try:
            response = await adaptor.make_plan_request(
                client, request, summarized=False
            )
        except httpx.HTTPStatusError as e:
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"Error making plan request: HTTPStatus {e.response.status_code}",
            )

        # Engine-agnostic hard gradient exclusion (no-op unless the request
        # asks for gentle grades on a walk mode) -- see services/grade_gate.py.
        response = await apply_grade_gate(client, request, response)
        # Surface-avoiding plans only: keep the first itinerary within the detour
        # cap, after the grade gate has removed what is too steep.
        response = await apply_detour_cap(client, adaptor, request, response)

    return response


@router.get("/itinerary/{itinerary_id}", response_model=ItineraryResponseModel)
async def get_itinerary(
    itinerary_id: str, engine: RoutingEngine = RoutingEngine.valhalla
):
    adaptor = _select_adaptor(engine)

    response = await adaptor.get_itinerary(itinerary_id)

    return response
