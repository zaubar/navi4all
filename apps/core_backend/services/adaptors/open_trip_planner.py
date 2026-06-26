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
from pathlib import Path
from httpx import AsyncClient
import os
from core.utils import to_camel_case
from redis import Redis
from schemas.routing import (
    RoutingPlanRequestModel,
    RoutingPlanSummaryResponseModel,
    RoutingPlanDetailedResponseModel,
    ItinerarySummary,
    LegSummary,
    LegDetailed,
    Step,
    Route,
    Coordinates,
    ItineraryResponseModel,
    ItineraryDetailed,
    Place,
    PlaceType,
    RelativeDirection,
)
from services.schemas.open_trip_planner import (
    OTPInputCoordinates,
    OTPOptimizeType,
    OTPPlanRequestModel,
    OTPPlanResponseModel,
    OTPTransportMode,
    OTPLeg,
)
from services import route_utils
from uuid import uuid4
from datetime import datetime, timedelta
import json


class OpenTripPlannerAdaptor:
    def __init__(self, url: str):
        """Initalize adaptor settings and setup persistent itinerary cache."""

        # Initialise adaptor URL
        self.url = url

        # Setup Redis client to cache itineraries
        self.redis_client = Redis(host=settings.REDIS_HOST, port=settings.REDIS_PORT)

    def _load_graphql_template(self, template_name: str):
        """Load a GraphQL query template to perform a request."""

        path = Path(os.path.join(settings.TEMPLATES_DIR, template_name))
        if not path.exists():
            raise FileNotFoundError(f"GraphQL query template not found at {path}")
        return path.read_text()

    def _get_leg_headsign(self, otp_leg: OTPLeg) -> str | None:
        """Produce a headsign for a given leg based on OTP route and trip data."""

        if otp_leg.headsign:
            return otp_leg.headsign
        if otp_leg.trip:
            if otp_leg.trip.trip_headsign:
                return otp_leg.trip.trip_headsign
            if len(otp_leg.trip.stops) > 0:
                return otp_leg.trip.stops[-1].name

        return ""

    def _build_steps(self, otp_steps: list) -> list[Step]:
        """Build Step list with bearing-normalized turn directions.

        Computes turn direction at each step point by comparing the bearing
        of the segment *into* the step with the segment *out of* the step.

        Pre-computes all segment bearings from the coordinate list so that
        every step (except the last) can be compared against its incoming
        AND outgoing segment, eliminating the off-by-one shift that existed
        when bearings were computed incrementally.
        """
        coords = [(s.lat, s.lon) for s in otp_steps]

        # Pre-compute bearing for each segment between consecutive step points
        segment_bearings: list[float] = []
        for j in range(len(coords) - 1):
            segment_bearings.append(route_utils.compute([coords[j], coords[j + 1]]))

        steps: list[Step] = []
        for i, s in enumerate(otp_steps):
            if i == 0:
                relative_direction = RelativeDirection.depart
            elif i < len(segment_bearings):
                # Turn at step i: compare incoming segment (i-1→i)
                # with outgoing segment (i→i+1).
                relative_direction = route_utils.turn_direction(
                    segment_bearings[i - 1], segment_bearings[i]
                )
            else:
                # Last step — no outgoing segment to compare.
                relative_direction = RelativeDirection.continue_

            steps.append(Step(
                distance=s.distance,
                lon=s.lon,
                lat=s.lat,
                relative_direction=relative_direction,
                street_name=s.street_name,
                bogus_name=s.bogus_name,
            ))

        return steps

    async def make_plan_request(
        self,
        async_client: AsyncClient,
        request: RoutingPlanRequestModel,
        summarized: bool = True,
    ) -> RoutingPlanSummaryResponseModel | RoutingPlanDetailedResponseModel:
        """Make a plan request to the OpenTripPlanner routing engine."""

        # Load GraphQL query template from file
        request_template = self._load_graphql_template(
            settings.OPEN_TRIP_PLANNER_PLAN_TEMPLATE
        )

        # Reformat request payload
        wheelchair_value = request.accessible
        if request.walk and request.walk.surface_quality is not None:
            wheelchair_value = request.walk.surface_quality >= 0.7

        # grade_category overrides wheelchair and adds optimize
        if request.grade_category:
            wheelchair_value = request.grade_category == "gentle"
            optimize_value = OTPOptimizeType.flat if request.grade_category in ("gentle", "moderate") else OTPOptimizeType.quick
        else:
            optimize_value = None

        request_dict = OTPPlanRequestModel(
            date=request.date,
            time=(
                datetime.strptime(request.time, "%H:%M:%S") + timedelta(hours=1)
            ).strftime("%H:%M:%S"),
            from_=OTPInputCoordinates(lat=request.origin.lat, lon=request.origin.lon),
            to=OTPInputCoordinates(
                lat=request.destination.lat, lon=request.destination.lon
            ),
            wheelchair=wheelchair_value,
            walk_speed=(request.walk.speed * 1000) / 3600 if request.walk else None,
            walk_reluctance=(
                6.0 if request.walk.surface_quality >= 1.0
                else 5.0 if request.walk.surface_quality >= 0.7
                else 4.0 if request.walk.surface_quality >= 0.4
                else 2.5 if request.walk.surface_quality > 0.0
                else 2.0
            ) if request.walk and request.walk.surface_quality is not None
            else 4.0
            if request.walk and request.walk.avoid
            else 2.0
            if request.walk
            else None,
            bike_speed=(request.bicycle.speed * 1000) / 3600
            if request.bicycle
            else None,
            num_itineraries=request.num_itineraries,
            arrive_by=request.time_is_arrival,
            transport_modes=[
                OTPTransportMode(mode=mode) for mode in request.transport_modes
            ],
            optimize=optimize_value,
        ).model_dump()
        request_dict = {to_camel_case(k): v for k, v in request_dict.items()}

        # Make the request to the routing engine
        router_response = await async_client.post(
            self.url,
            json={"query": request_template, "variables": request_dict},
        )

        # Process routing engine response
        router_response = OTPPlanResponseModel.model_validate(
            router_response.json()["data"]["plan"]
        )

        # Build response
        response = (
            RoutingPlanSummaryResponseModel(itineraries=[])
            if summarized
            else RoutingPlanDetailedResponseModel(itineraries=[])
        )

        # Write itineraries to cache
        for itinerary in router_response.itineraries:
            # Produce a unique ID for this itinerary and the journey it represents
            itinerary_id = str(uuid4())

            # Produce ItineraryDetailed model for full itinerary response
            itinerary_detailed = ItineraryDetailed(
                itinerary_id=itinerary_id,
                duration=itinerary.duration,
                start_time=itinerary.start_time,
                end_time=itinerary.end_time,
                origin=Coordinates(
                    lat=router_response.from_.lat, lon=router_response.from_.lon
                ),
                destination=Coordinates(
                    lat=router_response.to.lat, lon=router_response.to.lon
                ),
                legs=[
                    LegDetailed(
                        mode=leg.mode,
                        duration=int(leg.duration),
                        start_time=leg.start_time,
                        end_time=leg.end_time,
                        start_place=Place(
                            id=leg.from_.name,
                            name=leg.from_.name,
                            type=PlaceType.stop,
                            coordinates=Coordinates(
                                lat=leg.from_.lat, lon=leg.from_.lon
                            ),
                        ),
                        end_place=Place(
                            id=leg.to.name,
                            name=leg.to.name,
                            type=PlaceType.stop,
                            coordinates=Coordinates(lat=leg.to.lat, lon=leg.to.lon),
                        ),
                        distance=round(leg.distance),
                        geometry=leg.leg_geometry.points,
                        steps=self._build_steps(leg.steps),
                        route=Route(
                            id=leg.route.id,
                            short_name=leg.route.short_name,
                            mode=leg.mode,
                        )
                        if leg.route
                        else None,
                        headsign=self._get_leg_headsign(leg) if leg.route else None,
                        intermediate_stops=[
                            Place(
                                id=stop.id,
                                name=stop.name,
                                type=PlaceType.stop,
                                coordinates=Coordinates(lat=stop.lat, lon=stop.lon),
                            )
                            for stop in leg.intermediate_stops
                        ]
                        if leg.intermediate_stops
                        else None,
                    )
                    for leg in itinerary.legs
                ],
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
                if current_time < itinerary.end_time:
                    self.redis_client.expire(
                        itinerary_id, (itinerary.end_time - current_time).seconds
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
