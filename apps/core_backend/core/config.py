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
    REDIS_HOST: str = "core-redis"
    REDIS_PORT: int = 6379

    # User engagement settings
    USER_ENGAGEMENT_EVENT_FILE: str | None = None

    # Adaptor settings
    OPEN_TRIP_PLANNER_URL: str
    OPEN_TRIP_PLANNER_KL_URL: str
    OPEN_TRIP_PLANNER_PLAN_TEMPLATE: str = "plan.graphql"
    
    VALHALLA_URL: str

    ROUTING_ENGINE_URLS: dict[RoutingEngine, str] = {}

    # Hard gradient gate for grade_category="gentle" walk requests (see
    # services/grade_gate.py). Uses Valhalla's /height DEM endpoint, so it
    # works for itineraries from ANY engine. Threshold is the maximum
    # sustained grade a "gentle" route may contain; the window is the span
    # over which a grade must persist to count. 40 m measured on the live
    # Regensburg DEM: flat old-town streets read 3-4% (30 m-DEM noise), the
    # Blaue-Lilien-Gasse ramp reads 12.5% -- a 20 m window put flat streets
    # at 6-7%, above the threshold. Disable via env GRADE_GATE_ENABLED=false.
    GRADE_GATE_ENABLED: bool = True
    GRADE_GATE_MAX_PERCENT: float = 6.0
    GRADE_GATE_WINDOW_M: float = 40.0
    GRADE_GATE_TIMEOUT_S: float = 5.0

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
