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
from pydantic import Field, model_validator
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
    #
    # OpenTripPlanner was retired 2026-09: Valhalla carries every function the
    # app used from it. The two URLs are accepted and ignored so an existing
    # compose/helm env still boots; nothing constructs an OTP adaptor any more
    # (engine=otp|otp_kl|hybrid answers HTTP 400, see endpoints/routing.py).
    OPEN_TRIP_PLANNER_URL: str | None = None
    OPEN_TRIP_PLANNER_KL_URL: str | None = None
    OPEN_TRIP_PLANNER_PLAN_TEMPLATE: str = "plan.graphql"

    VALHALLA_URL: str

    # Only the engines whose URL is set appear here. Valhalla is always present.
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

    # Detour cap for surface-avoiding walk plans (services/detour_cap.py). The
    # surface options price bumpy paving at 20 to 25 times its length, so the
    # cheapest route can be much longer than the route without the setting
    # (prod 2026-09-19: 173 m -> 328 m to avoid 31 m of bumpy paving). Among
    # the alternatives the engine returned, the first one at most this many
    # times as long as the unpenalised route leads; none within it => the
    # shortest leads. 0 disables the cap.
    VALHALLA_SURFACE_DETOUR_MAX_RATIO: float = Field(1.5, ge=0.0)

    # Valhalla adds destination_only_penalty (default 600 s) when a route
    # enters an edge tagged access=destination / motor_vehicle=destination,
    # for pedestrians too (upstream PR #5862 to change the default is open).
    # In the Regensburg Altstadt nearly every living street carries that
    # vehicle rule, so walking routes circled the old town: on 80 real POI
    # pairs the total distance was 66.7 km at 600 s and 56.0 km at 0 s, 35
    # pairs more than 10 % shorter, none longer (2026-09-11). Pedestrians
    # are not bound by "Anlieger frei"; 0 is the correct value.
    VALHALLA_PEDESTRIAN_DESTINATION_ONLY_PENALTY: float = 0.0

    # Soft cobblestone avoidance (zaubar/valhalla fork PR #1): the pedestrian
    # costing option avoid_bad_surfaces (0..1, engine default 0) makes an edge
    # whose surface is paved_rough or worse cost 1 + 24 * value times more;
    # sett now files as paved_rough. The adaptor sends SMOOTH for
    # walk.surface_quality >= 0.7 and MEDIUM for 0.3 < surface_quality < 0.7;
    # otherwise the option is not sent. Measured 2026-09-13 on 100 real POI
    # pairs: a hard exclusion was rejected (4 pairs unroutable, 42 routes up
    # to 3x longer); OTP accessible routes crossed 9.8 km of sett against
    # 22.0 km on the Valhalla wheelchair type, which this option is to close.
    VALHALLA_AVOID_BAD_SURFACES_SMOOTH: float = Field(0.4, ge=0.0, le=1.0)
    # MEDIUM 0.15 priced sound sett like the smooth band (4.6x): the middle slider step
    # took the smooth band's detours. 0.08 measured 2026-09-17 on 218 Altstadt pairs,
    # zaubar/regensburg-web#267.
    VALHALLA_AVOID_BAD_SURFACES_MEDIUM: float = Field(0.08, ge=0.0, le=1.0)
    # Fork PR #3 splits the rough side: the value above now charges paved_rough
    # (sound sett, cobblestone) only; these charge compacted and worse, where the
    # fork files sett in bad repair (the Regensburg survey's bumpy squares), gravel
    # and dirt. Sent for the same two bands, so "Nur glatte Wege" pushes hardest
    # on the bumpy tier and "Einige Pflasterungen" keeps sound sett cheap while
    # still steering off the bumpy one.
    VALHALLA_AVOID_VERY_ROUGH_SURFACES_SMOOTH: float = Field(1.0, ge=0.0, le=1.0)
    VALHALLA_AVOID_VERY_ROUGH_SURFACES_MEDIUM: float = Field(0.8, ge=0.0, le=1.0)

    GEOCODING_PROVIDER: SupportedGeocodingProviders
    GEOCODING_PROVIDER_API_URL: str | None = None
    GEOCODING_PROVIDER_API_KEY: str | None = None

    @model_validator(mode="after")
    def validate_geocoding_provider(cls, values: "Settings") -> dict[str, any]:
        if values.GEOCODING_PROVIDER != SupportedGeocodingProviders.NONE:
            if values.GEOCODING_PROVIDER_API_URL is None:
                raise ValueError("GEOCODING_PROVIDER_API_URL must be set")
    
        # Map routing engine URLs (retired OTP entries only when configured)
        if values.OPEN_TRIP_PLANNER_URL is not None:
            values.ROUTING_ENGINE_URLS[RoutingEngine.open_trip_planner] = values.OPEN_TRIP_PLANNER_URL
        if values.OPEN_TRIP_PLANNER_KL_URL is not None:
            values.ROUTING_ENGINE_URLS[RoutingEngine.open_trip_planner_kl] = values.OPEN_TRIP_PLANNER_KL_URL
        values.ROUTING_ENGINE_URLS[RoutingEngine.valhalla] = values.VALHALLA_URL
    
        return values


settings = Settings()
