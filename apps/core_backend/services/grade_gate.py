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

"""Hard gradient gate for grade_category="gentle" walk requests.

Neither engine can hard-exclude steep streets today: Valhalla's wheelchair
``max_grade`` check is commented out upstream (its ``use_hills`` bias, wired
by this adaptor, is a soft preference only), and OpenTripPlanner ignores
``optimize`` for walk requests entirely. Rather than forking engine C++/Java,
this gate enforces the exclusion engine-agnostically: after an engine returns
its itineraries, each walk leg's shape is sampled against Valhalla's
``/height`` endpoint (which has real DEM data — ``build_elevation=True``) and
itineraries whose sustained grade exceeds the threshold are dropped, provided
at least one compliant itinerary remains. When every candidate is too steep,
the least-steep one is kept so the user always gets a route.

The gate fails OPEN: any error talking to ``/height`` (or missing elevation
coverage) leaves the engine response untouched — a degraded preference must
never become a routing outage.
"""

import asyncio
import logging
import math

import polyline
from httpx import AsyncClient

from core.config import settings
from schemas.routing import (
    GradeCategory,
    Mode,
    RoutingPlanDetailedResponseModel,
    RoutingPlanRequestModel,
    RoutingPlanSummaryResponseModel,
)

logger = logging.getLogger(__name__)

_EARTH_RADIUS_M = 6371000.0


def _haversine_m(a: tuple[float, float], b: tuple[float, float]) -> float:
    """Great-circle distance in meters between two (lat, lon) points."""

    d_lat = math.radians(b[0] - a[0])
    d_lon = math.radians(b[1] - a[1])
    s = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(a[0])) * math.cos(math.radians(b[0])) * math.sin(d_lon / 2) ** 2
    )
    return 2 * _EARTH_RADIUS_M * math.asin(math.sqrt(s))


def resample_shape(
    points: list[tuple[float, float]], step_m: float = 15.0
) -> list[tuple[float, float]]:
    """Resample a (lat, lon) polyline to roughly equidistant points.

    DEM sampling at raw vertices alone under-samples long straight edges
    (a single 200 m edge would yield one grade reading for the whole block).
    Vertices are kept and intermediate points inserted every ``step_m``.
    """

    if len(points) < 2:
        return list(points)

    resampled: list[tuple[float, float]] = [points[0]]
    for start, end in zip(points, points[1:]):
        segment_m = _haversine_m(start, end)
        if segment_m > step_m:
            splits = int(segment_m // step_m)
            for i in range(1, splits + 1):
                t = i * step_m / segment_m
                if t >= 1.0:
                    break
                resampled.append(
                    (
                        start[0] + (end[0] - start[0]) * t,
                        start[1] + (end[1] - start[1]) * t,
                    )
                )
        resampled.append(end)
    return resampled


def max_sustained_grade_percent(
    range_height: list[tuple[float, float | None]], window_m: float = 40.0
) -> float | None:
    """Steepest sustained grade (%) over at-least-``window_m`` spans.

    ``range_height`` is Valhalla's ``/height?range=true`` output: cumulative
    distance along the shape plus the sampled height (``None`` where the DEM
    has no coverage). Grades are measured between samples at least
    ``window_m`` apart, which smooths single-sample DEM noise; a genuine ramp
    longer than the window is fully visible. Returns ``None`` when fewer than
    two usable samples exist (no coverage — caller must fail open).
    """

    usable = [(d, h) for d, h in range_height if h is not None]
    if len(usable) < 2:
        return None

    # 3-sample median filter on heights: a single glitched DEM sample would
    # otherwise sit at the endpoint of some window pair and read as a steep
    # ramp. The median flattens lone spikes while leaving genuine monotone
    # ramps untouched (the median of a monotone triple is its middle value).
    if len(usable) >= 3:
        heights = [h for _, h in usable]
        smoothed = (
            [heights[0]]
            + [
                sorted(heights[i - 1 : i + 2])[1]
                for i in range(1, len(heights) - 1)
            ]
            + [heights[-1]]
        )
        usable = [(d, s) for (d, _), s in zip(usable, smoothed)]

    steepest = 0.0
    j = 0
    for i in range(len(usable)):
        d_i, h_i = usable[i]
        j = max(j, i + 1)
        while j < len(usable) and usable[j][0] - d_i < window_m:
            j += 1
        if j >= len(usable):
            # Tail shorter than a full window: stop. Sub-window spans amplify
            # 30 m-DEM interpolation noise into fake ramps (measured live:
            # half-window tails put flat Regensburg streets above 6%), and a
            # stretch shorter than the window is by definition not sustained.
            break
        d_j, h_j = usable[j]
        steepest = max(steepest, abs(h_j - h_i) / (d_j - d_i) * 100.0)
    return steepest


def pick_itineraries(
    grades: list[float | None], threshold_percent: float
) -> list[int]:
    """Indices of itineraries to keep, in original order.

    Policy: drop itineraries whose sustained grade exceeds the threshold as
    long as at least one compliant itinerary remains. If none comply, keep
    the single least-steep one (a user asking for gentle routes still needs
    *a* route). Unknown grades (``None`` — no DEM coverage) count as
    compliant: absence of data must not discard an otherwise valid route.
    """

    compliant = [
        i for i, g in enumerate(grades) if g is None or g <= threshold_percent
    ]
    if compliant:
        return compliant

    known = [(g, i) for i, g in enumerate(grades) if g is not None]
    least_steep = min(known)[1]
    return [least_steep]


async def _itinerary_grade(
    client: AsyncClient, valhalla_url: str, itinerary, window_m: float
) -> float | None:
    """Max sustained grade across an itinerary's WALK legs, or None if unknown."""

    grades: list[float] = []
    for leg in itinerary.legs:
        if leg.mode != Mode.walk or not leg.geometry:
            continue
        shape = resample_shape(polyline.decode(leg.geometry))
        if len(shape) < 2:
            continue
        response = await client.post(
            f"{valhalla_url}/height",
            json={
                "range": True,
                "shape": [{"lat": lat, "lon": lon} for lat, lon in shape],
            },
            timeout=settings.GRADE_GATE_TIMEOUT_S,
        )
        response.raise_for_status()
        range_height = response.json().get("range_height") or []
        grade = max_sustained_grade_percent(range_height, window_m=window_m)
        if grade is not None:
            grades.append(grade)
    return max(grades) if grades else None


async def apply_grade_gate(
    client: AsyncClient,
    request: RoutingPlanRequestModel,
    response: RoutingPlanSummaryResponseModel | RoutingPlanDetailedResponseModel,
) -> RoutingPlanSummaryResponseModel | RoutingPlanDetailedResponseModel:
    """Enforce the hard grade exclusion on a plan response, failing open."""

    if (
        not settings.GRADE_GATE_ENABLED
        or request.grade_category != GradeCategory.gentle
        or Mode.walk not in request.transport_modes
        or len(response.itineraries) == 0
    ):
        return response

    try:
        grades = await asyncio.gather(
            *(
                _itinerary_grade(
                    client,
                    settings.VALHALLA_URL,
                    itinerary,
                    settings.GRADE_GATE_WINDOW_M,
                )
                for itinerary in response.itineraries
            )
        )
        keep = pick_itineraries(list(grades), settings.GRADE_GATE_MAX_PERCENT)
        if len(keep) < len(response.itineraries):
            dropped = [
                (str(response.itineraries[i].itinerary_id), grades[i])
                for i in range(len(response.itineraries))
                if i not in keep
            ]
            logger.info(
                "grade gate dropped %d/%d itineraries above %.1f%%: %s",
                len(dropped),
                len(response.itineraries),
                settings.GRADE_GATE_MAX_PERCENT,
                dropped,
            )
        response.itineraries = [response.itineraries[i] for i in keep]
        return response
    except Exception:  # noqa: BLE001 - the gate must never break routing
        logger.warning("grade gate failed open (height lookup error)", exc_info=True)
        return response
