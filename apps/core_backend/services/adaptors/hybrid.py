from services.adaptors.open_trip_planner import OpenTripPlannerAdaptor
from services.adaptors.valhalla import ValhallaAdaptor
from redis import Redis
from core.config import settings
from httpx import AsyncClient
from schemas.routing import (
    RoutingPlanRequestModel,
    RoutingPlanSummaryResponseModel,
    RoutingPlanDetailedResponseModel,
    Mode,
    Coordinates,
    ItinerarySummary,
    LegSummary,
    ItineraryResponseModel,
    GuidanceLanguage,
)
import polyline
import json
from datetime import datetime


class HybridAdaptor:
    """Combines routing results from OpenTripPlanner and Valhalla."""

    def __init__(
        self, otp_adaptor: OpenTripPlannerAdaptor, valhalla_adaptor: ValhallaAdaptor
    ):
        """Initalize adaptor settings and setup persistent itinerary cache."""

        # Initialise sub-adaptors
        self.otp_adaptor = otp_adaptor
        self.valhalla_adaptor = valhalla_adaptor

        # Setup Redis client to cache itineraries
        self.redis_client = Redis(host=settings.REDIS_HOST, port=settings.REDIS_PORT)

    async def make_plan_request(
        self,
        async_client: AsyncClient,
        request: RoutingPlanRequestModel,
        summarized: bool = True,
    ) -> RoutingPlanSummaryResponseModel:
        """Make a route request to the OpenTripPlanner and Valhalla routing engines."""

        # Make a request to the OpenTripPlanner adaptor
        otp_response = await self.otp_adaptor.make_plan_request(
            async_client, request, summarized=False
        )

        # Build response
        response = (
            RoutingPlanSummaryResponseModel(itineraries=[])
            if summarized
            else RoutingPlanDetailedResponseModel(itineraries=[])
        )

        # Make a request to the Valhalla adaptor for every walking or car leg
        for itinerary_detailed in otp_response.itineraries:
            for leg in itinerary_detailed.legs:
                if leg.mode in [Mode.walk, Mode.car]:
                    leg_origin = polyline.decode(leg.geometry)[0]
                    leg_destination = polyline.decode(leg.geometry)[-1]

                    # Fetch itinerary from Valhalla for this leg
                    valhalla_request = RoutingPlanRequestModel(
                        origin=Coordinates(lat=leg_origin[0], lon=leg_origin[1]),
                        destination=Coordinates(
                            lat=leg_destination[0], lon=leg_destination[1]
                        ),
                        date=request.date,
                        time=request.time,
                        transport_modes=[leg.mode],
                        guidance_language=request.guidance_language,
                    )
                    valhalla_response = await self.valhalla_adaptor.make_plan_request(
                        async_client,
                        valhalla_request, 
                        summarized=False,
                    )

                    # Don't replace existing leg if no itinerary was found
                    if (
                        len(valhalla_response.itineraries) == 0
                        or len(valhalla_response.itineraries[0].legs) == 0
                    ):
                        continue

                    # Replace existing leg
                    newLeg = valhalla_response.itineraries[0].legs[0]
                    otp_response.itineraries[
                        otp_response.itineraries.index(itinerary_detailed)
                    ].legs[itinerary_detailed.legs.index(leg)] = newLeg

            # Recompute itinerary stats
            total_duration = sum(leg.duration for leg in itinerary_detailed.legs)
            itinerary_detailed.duration = int(total_duration)

            if summarized:
                # Write the full journey to cache
                serialized_mapping = {
                    k: json.dumps(v) if isinstance(v, (list, dict)) else v
                    for k, v in itinerary_detailed.model_dump(
                        mode="json", exclude_none=True
                    ).items()
                }
                self.redis_client.hset(
                    name=str(itinerary_detailed.itinerary_id),
                    mapping=serialized_mapping,
                )

                # Consider the itinerary to be invalid past its start time
                current_time = datetime.now()
                if current_time < itinerary_detailed.end_time:
                    self.redis_client.expire(
                        str(itinerary_detailed.itinerary_id),
                        (itinerary_detailed.end_time - current_time).seconds,
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
