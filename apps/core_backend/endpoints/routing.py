import httpx
from fastapi import APIRouter
from schemas.routing import RoutingEngine, RoutingPlanRequestModel, RoutingPlanResponseModel, ItineraryResponseModel
from services.adaptors.open_trip_planner import OpenTripPlannerAdaptor
from core.config import settings

router = APIRouter(prefix="/routing")
adaptor_otp = OpenTripPlannerAdaptor(url=settings.ROUTING_ENGINE_URLS[RoutingEngine.open_trip_planner])
adaptor_otp_kl = OpenTripPlannerAdaptor(url=settings.ROUTING_ENGINE_URLS[RoutingEngine.open_trip_planner_kl])


@router.post("/plan", response_model=RoutingPlanResponseModel)
async def plan(request: RoutingPlanRequestModel, engine: RoutingEngine = RoutingEngine.open_trip_planner):
    async with httpx.AsyncClient() as client:
        if engine == RoutingEngine.open_trip_planner:
            adaptor = adaptor_otp
        elif engine == RoutingEngine.open_trip_planner_kl:
            adaptor = adaptor_otp_kl
        else:
            raise ValueError("Unsupported routing engine specified.")
        response = await adaptor.make_plan_request(client, request)

    return response


@router.get("/itinerary/{itinerary_id}", response_model=ItineraryResponseModel)
async def get_itinerary(itinerary_id: str, engine: RoutingEngine = RoutingEngine.open_trip_planner):
    if engine == RoutingEngine.open_trip_planner:
        adaptor = adaptor_otp
    elif engine == RoutingEngine.open_trip_planner_kl:
        adaptor = adaptor_otp_kl
    else:
        raise ValueError("Unsupported routing engine specified.")
    
    response = await adaptor.get_itinerary(itinerary_id)

    return response
