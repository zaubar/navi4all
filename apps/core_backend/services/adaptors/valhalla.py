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

from core.config import settings
from httpx import AsyncClient
from redis import Redis
from schemas.routing import (
    RoutingPlanRequestModel,
    RoutingPlanSummaryResponseModel,
    RoutingPlanDetailedResponseModel,
    ItinerarySummary,
    LegSummary,
    LegDetailed,
    Step,
    ItineraryResponseModel,
    ItineraryDetailed,
    AbsoluteDirection,
    RelativeDirection,
    Place,
    PlaceType,
)
from services.schemas.valhalla import (
    ValhallaRouteRequestModel,
    ValhallaRouteResponseModel,
    ValhallaLocation,
    ValhallaCosting,
    ValhallaManeuverType,
    MANEUVER_TYPE_TO_RELATIVE_DIRECTION,
    MODE_TO_COSTING,
    TRAVEL_MODE_TO_MODE,
)
from services import route_utils
from uuid import uuid4
from datetime import datetime, timedelta
import json
import polyline


class ValhallaAdaptor:
    def __init__(self, url: str):
        """Initalize adaptor settings and setup persistent itinerary cache."""

        # Initialise adaptor URL
        self.url = url

        # Setup Redis client to cache itineraries
        self.redis_client = Redis(host=settings.REDIS_HOST, port=settings.REDIS_PORT)

    async def make_plan_request(
        self,
        async_client: AsyncClient,
        request: RoutingPlanRequestModel,
        summarized: bool = True,
    ) -> RoutingPlanSummaryResponseModel | RoutingPlanDetailedResponseModel:
        """Make a route request to the Valhalla routing engine."""

        def _get_surface_quality_options(
            surface_quality: float | None,
            accessible: bool,
            grade_category: str | None = None,
        ) -> ValhallaPedestrianCostingOptions:
            """Map surface_quality (0.0-1.0) and grade_category to Valhalla pedestrian options."""

            # grade_category takes precedence over surface_quality + accessible
            if grade_category:
                if grade_category == "gentle":
                    costing_type = ValhallaPedestrianCostingOptionsType.wheelchair
                else:
                    costing_type = ValhallaPedestrianCostingOptionsType.foot
                return ValhallaPedestrianCostingOptions(
                    walking_speed=request.walk.speed if request.walk else None,
                    type=costing_type,
                )

            # Determine type
            if surface_quality is not None and surface_quality >= 0.7:
                costing_type = ValhallaPedestrianCostingOptionsType.wheelchair
            elif surface_quality is not None and surface_quality > 0.0:
                costing_type = ValhallaPedestrianCostingOptionsType.foot
            else:
                costing_type = (
                    ValhallaPedestrianCostingOptionsType.wheelchair
                    if accessible
                    else ValhallaPedestrianCostingOptionsType.foot
                )

            # Determine surface_smoothness
            surface_smoothness: float | None = None
            if surface_quality is not None and surface_quality > 0.0:
                if surface_quality <= 0.3:
                    surface_smoothness = 0.0
                elif surface_quality <= 0.6:
                    surface_smoothness = 0.5
                elif surface_quality <= 0.9:
                    surface_smoothness = 0.75
                else:
                    surface_smoothness = 1.0

            return ValhallaPedestrianCostingOptions(
                walking_speed=request.walk.speed if request.walk else None,
                surface_smoothness=surface_smoothness,
                type=costing_type,
            )

        # Reformat request payload
        request_dict = str(
            ValhallaRouteRequestModel(
                locations=[
                    ValhallaLocation(lat=request.origin.lat, lon=request.origin.lon),
                    ValhallaLocation(
                        lat=request.destination.lat, lon=request.destination.lon
                    ),
                ],
                costing=MODE_TO_COSTING.get(request.transport_modes[0])
                if len(request.transport_modes) == 1
                else ValhallaCosting.multi_modal,
                costing_options=ValhallaCostingOptions(
                    pedestrian=_get_surface_quality_options(
                        surface_quality=request.walk.surface_quality if request.walk else None,
                        accessible=request.accessible,
                        grade_category=request.grade_category,
                    )
                ),
                language=request.guidance_language.value,
            ).model_dump(mode="json", exclude_none=True)
        ).replace("'", '"')

        # Make the request to the routing engine
        router_response = await async_client.get(
            f"{self.url}/route?json={request_dict}",
        )
        router_response.raise_for_status()

        # Process routing engine response
        router_response = ValhallaRouteResponseModel.model_validate(
            router_response.json()
        )

        # Build response
        response = (
            RoutingPlanSummaryResponseModel(itineraries=[])
            if summarized
            else RoutingPlanDetailedResponseModel(itineraries=[])
        )

        # Write itinerary to cache
        # Produce a unique ID for this itinerary and the journey it represents
        itinerary_id = str(uuid4())

        # Produce ItineraryDetailed model for full itinerary response
        legs: list[LegDetailed] = []
        for leg in router_response.trip.legs:
            shape_points = polyline.decode(leg.shape, precision=6)

            steps: list[Step] = []
            for i, maneuver in enumerate(leg.maneuvers):
                step_shape = shape_points[
                    maneuver.begin_shape_index : maneuver.end_shape_index + 1
                ]
                step_bearing = route_utils.compute(step_shape)

                # For first step (depart) keep the original maneuver type;
                # for subsequent steps compute turn direction from bearing
                # difference between consecutive street segments.
                if i == 0:
                    relative_direction = MANEUVER_TYPE_TO_RELATIVE_DIRECTION.get(
                        maneuver.type, RelativeDirection.continue_
                    )
                else:
                    prev_maneuver = leg.maneuvers[i - 1]
                    prev_shape = shape_points[
                        prev_maneuver.begin_shape_index : prev_maneuver.end_shape_index + 1
                    ]
                    prev_bearing = route_utils.compute(prev_shape)
                    relative_direction = route_utils.turn_direction(prev_bearing, step_bearing)

                # Determine absolute (compass) direction from the step bearing.
                if step_bearing < 22.5 or step_bearing >= 337.5:
                    absolute_direction = AbsoluteDirection.north
                elif step_bearing < 67.5:
                    absolute_direction = AbsoluteDirection.northeast
                elif step_bearing < 112.5:
                    absolute_direction = AbsoluteDirection.east
                elif step_bearing < 157.5:
                    absolute_direction = AbsoluteDirection.southeast
                elif step_bearing < 202.5:
                    absolute_direction = AbsoluteDirection.south
                elif step_bearing < 247.5:
                    absolute_direction = AbsoluteDirection.southwest
                elif step_bearing < 292.5:
                    absolute_direction = AbsoluteDirection.west
                else:
                    absolute_direction = AbsoluteDirection.northwest

                steps.append(
                    Step(
                        distance=round(maneuver.length * 1000),  # convert km to m
                        lat=step_shape[0][0],
                        lon=step_shape[0][1],
                        relative_direction=relative_direction,
                        absolute_direction=absolute_direction,
                        street_name=maneuver.instruction,
                        bogus_name=True,
                        text_instruction=maneuver.instruction,
                        voice_instruction=maneuver.verbal_pre_transition_instruction,
                    )
                )

            legs.append(
                LegDetailed(
                    start_time=datetime.now(),
                    end_time=datetime.now()
                    + timedelta(seconds=round(leg.summary.time)),
                    start_place=Place(
                        id="",
                        name="",
                        type=PlaceType.address,
                        coordinates=request.origin,
                    ),
                    end_place=Place(
                        id="",
                        name="",
                        type=PlaceType.address,
                        coordinates=request.destination,
                    ),
                    mode=TRAVEL_MODE_TO_MODE[leg.maneuvers[0].travel_mode],
                    duration=round(leg.summary.time),
                    distance=round(leg.summary.length * 1000),  # convert km to m
                    geometry=polyline.encode(polyline.decode(leg.shape, precision=6)),
                    steps=steps,
                )
            )

        itinerary_detailed = ItineraryDetailed(
            itinerary_id=itinerary_id,
            duration=round(router_response.trip.summary.time),
            start_time=datetime.now(),
            end_time=datetime.now()
            + timedelta(seconds=router_response.trip.summary.time),
            origin=request.origin,
            destination=request.destination,
            legs=legs,
        )

        if summarized:
            # Write the full journey to cache
            serialized_mapping = {
                k: json.dumps(v) if isinstance(v, (list, dict)) else v
                for k, v in itinerary_detailed.model_dump(
                    mode="json", exclude_none=True
                ).items()
            }
            self.redis_client.hset(name=itinerary_id, mapping=serialized_mapping)

            # Consider the itinerary to be invalid past its start time
            current_time = datetime.now()
            if current_time < itinerary_detailed.end_time:
                self.redis_client.expire(
                    itinerary_id, (itinerary_detailed.end_time - current_time).seconds
                )
            else:
                # TODO: Throw an exception & return an appropriate error response
                print("Invalid itinerary start time.")

            # Write an itinerary summary to the response
            response.itineraries.append(
                ItinerarySummary(
                    itinerary_id=itinerary_detailed.itinerary_id,
                    duration=itinerary_detailed.duration,
                    start_time=itinerary_detailed.start_time,
                    end_time=itinerary_detailed.end_time,
                    origin=itinerary_detailed.origin,
                    destination=itinerary_detailed.destination,
                    legs=[
                        LegSummary(
                            mode=leg.mode,
                            duration=int(leg.duration),
                            distance=leg.distance,
                            geometry=leg.geometry,
                        )
                        for leg in itinerary_detailed.legs
                    ],
                )
            )
        else:
            response.itineraries.append(itinerary_detailed)

        return response

    async def get_itinerary(self, itinerary_id: str) -> ItineraryResponseModel:
        """Retrieve a full itinerary from the cache by its journey ID."""

        # Fetch itinerary from cache
        data = self.redis_client.hgetall(itinerary_id)

        # Decode
        decoded_data = {k.decode(): v.decode() for k, v in data.items()}

        # Deserialize
        deserialized_data = {
            k: json.loads(v) if v.startswith("[") or v.startswith("{") else v
            for k, v in decoded_data.items()
        }

        # Validate and return the full itinerary
        return ItineraryResponseModel.model_validate(deserialized_data)
