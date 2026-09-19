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

"""Detour cap for surface-avoiding walk plans.

The surface options (avoid_bad_surfaces, avoid_very_rough_surfaces) price one
metre of bumpy paving like 20 to 25 metres of walking, so the engine's cheapest
route can be far longer than the route the same user gets without the setting:
measured on prod 2026-09-19, Rathausplatz -> Goliathhaus 173 m without, 328 m
with "smooth only", to avoid 31 m of bumpy paving, while the engine's second
alternative is 219 m.

The cap keeps the engine's pricing and only chooses among the alternatives it
already returned: the first one (engine order, cheapest first) that is at most
``max_ratio`` times as long as the unpenalised route goes first. When none is,
the shortest goes first. Nothing is dropped, and any failure leaves the
response untouched.
"""

import logging

from httpx import AsyncClient

from core.config import settings
from schemas.routing import (
    Mode,
    RoutingPlanDetailedResponseModel,
    RoutingPlanRequestModel,
    RoutingPlanSummaryResponseModel,
)

logger = logging.getLogger(__name__)

# The adaptor sends no surface option at or below this surface_quality
# (services/adaptors/valhalla.py), so there is no penalty to cap.
_SURFACE_PENALTY_ABOVE = 0.3


def pick_order(lengths: list[float], reference: float, max_ratio: float) -> list[int]:
    """Indices of the itineraries in their new order.

    The first itinerary within ``max_ratio * reference`` leads; when none is
    within it, the shortest leads. The others keep their engine order.
    """

    if not lengths:
        return []
    limit = max_ratio * reference
    within = [i for i, length in enumerate(lengths) if length <= limit]
    lead = within[0] if within else min(range(len(lengths)), key=lambda i: lengths[i])
    return [lead] + [i for i in range(len(lengths)) if i != lead]


def _length(itinerary) -> float:
    return float(sum(leg.distance for leg in itinerary.legs))


async def apply_detour_cap(
    client: AsyncClient,
    adaptor,
    request: RoutingPlanRequestModel,
    response: RoutingPlanSummaryResponseModel | RoutingPlanDetailedResponseModel,
) -> RoutingPlanSummaryResponseModel | RoutingPlanDetailedResponseModel:
    """Reorder a surface-avoiding plan so its first itinerary respects the cap."""

    max_ratio = settings.VALHALLA_SURFACE_DETOUR_MAX_RATIO
    if (
        max_ratio <= 0
        or Mode.walk not in request.transport_modes
        or request.walk is None
        or request.walk.surface_quality is None
        or request.walk.surface_quality <= _SURFACE_PENALTY_ABOVE
        or len(response.itineraries) < 2
    ):
        return response

    try:
        lengths = [_length(itinerary) for itinerary in response.itineraries]
        # Nothing shorter than the leader: no alternative could replace it.
        if lengths[0] <= min(lengths):
            return response

        plain = request.model_copy(deep=True)
        plain.walk.surface_quality = None
        plain.num_itineraries = 1
        reference_plan = await adaptor.make_plan_request(client, plain, summarized=True)
        if not reference_plan.itineraries:
            return response
        reference = _length(reference_plan.itineraries[0])
        if reference <= 0:
            return response

        order = pick_order(lengths, reference, max_ratio)
        if order[0] != 0:
            logger.info(
                "detour cap: %.0f m leader replaced by %.0f m (unpenalised %.0f m, cap x%.2f)",
                lengths[0],
                lengths[order[0]],
                reference,
                max_ratio,
            )
            response.itineraries = [response.itineraries[i] for i in order]
        return response
    except Exception:  # noqa: BLE001 - the cap must never break routing
        logger.warning("detour cap failed open", exc_info=True)
        return response
