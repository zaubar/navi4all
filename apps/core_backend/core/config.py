from pydantic_settings import BaseSettings
from pydantic import model_validator
from schemas.geocoding import SupportedGeocodingProviders
from schemas.routing import RoutingEngine


class Settings(BaseSettings):
    # API settings
    API_VERSION: str = "/v1"
    DEBUG: bool = False

    # Directory and path settings
    TEMPLATES_DIR: str = "./templates"

    # Redis settings
    REDIS_HOST: str = "navi4all-redis"
    REDIS_PORT: int = 6379

    # User engagement settings
    USER_ENGAGEMENT_EVENT_FILE: str | None = None

    # Adaptor settings
    OPEN_TRIP_PLANNER_URL: str
    OPEN_TRIP_PLANNER_KL_URL: str
    OPEN_TRIP_PLANNER_PLAN_TEMPLATE: str = "plan.graphql"
    
    VALHALLA_URL: str
    
    ROUTING_ENGINE_URLS: dict[RoutingEngine, str] = {}

    GEOCODING_PROVIDER: SupportedGeocodingProviders
    GEOCODING_PROVIDER_API_URL: str | None = None
    GEOCODING_PROVIDER_API_KEY: str | None = None

    @model_validator(mode="after")
    def validate_geocoding_provider(cls, values: "Settings") -> dict[str, any]:
        if values.GEOCODING_PROVIDER != SupportedGeocodingProviders.NONE:
            if values.GEOCODING_PROVIDER_API_URL is None:
                raise ValueError("GEOCODING_PROVIDER_API_URL must be set")
    
        # Map routing engine URLs
        values.ROUTING_ENGINE_URLS[RoutingEngine.open_trip_planner] = values.OPEN_TRIP_PLANNER_URL
        values.ROUTING_ENGINE_URLS[RoutingEngine.open_trip_planner_kl] = values.OPEN_TRIP_PLANNER_KL_URL
        values.ROUTING_ENGINE_URLS[RoutingEngine.valhalla] = values.VALHALLA_URL
    
        return values


settings = Settings()
