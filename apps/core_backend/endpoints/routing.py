import httpx
from fastapi import APIRouter, HTTPException
from schemas.routing import RoutingEngine, RoutingPlanRequestModel, RoutingPlanSummaryResponseModel, ItineraryResponseModel
from services.adaptors.open_trip_planner import OpenTripPlannerAdaptor
from services.adaptors.valhalla import ValhallaAdaptor
from services.adaptors.hybrid import HybridAdaptor
from core.config import settings


router = APIRouter(prefix="/routing")
adaptor_otp = OpenTripPlannerAdaptor(url=settings.ROUTING_ENGINE_URLS[RoutingEngine.open_trip_planner])
adaptor_otp_kl = OpenTripPlannerAdaptor(url=settings.ROUTING_ENGINE_URLS[RoutingEngine.open_trip_planner_kl])
adaptor_valhalla = ValhallaAdaptor(url=settings.ROUTING_ENGINE_URLS[RoutingEngine.valhalla])
adaptor_hybrid = HybridAdaptor(
    otp_adaptor=adaptor_otp_kl,
    valhalla_adaptor=adaptor_valhalla,
)


@router.post("/plan", response_model=RoutingPlanSummaryResponseModel)
async def plan(request: RoutingPlanRequestModel, engine: RoutingEngine = RoutingEngine.open_trip_planner):
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
            response = await adaptor.make_plan_request(client, request)
        except httpx.HTTPStatusError as e:
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"Error making plan request: HTTPStatus {e.response.status_code}",
            )

    return response


@router.get("/itinerary/{itinerary_id}", response_model=ItineraryResponseModel)
async def get_itinerary(itinerary_id: str, engine: RoutingEngine = RoutingEngine.open_trip_planner):
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
