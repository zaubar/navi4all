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

from pydantic import BaseModel, field_validator, model_validator
from datetime import datetime
from enum import Enum
from uuid import UUID
from schemas.coordinates import Coordinates


class Mode(str, Enum):
    airplane = "AIRPLANE"
    bicycle = "BICYCLE"
    bus = "BUS"
    cable_car = "CABLE_CAR"
    car = "CAR"
    coach = "COACH"
    ferry = "FERRY"
    flex = "FLEX"
    funicular = "FUNICULAR"
    gondola = "GONDOLA"
    rail = "RAIL"
    scooter = "SCOOTER"
    subway = "SUBWAY"
    tram = "TRAM"
    carpool = "CARPOOL"
    taxi = "TAXI"
    transit = "TRANSIT"
    walk = "WALK"
    trolleybus = "TROLLEYBUS"
    monorail = "MONORAIL"


class RelativeDirection(Enum):
    depart = "DEPART"
    hard_left = "HARD_LEFT"
    left = "LEFT"
    slightly_left = "SLIGHTLY_LEFT"
    continue_ = "CONTINUE"
    slightly_right = "SLIGHTLY_RIGHT"
    right = "RIGHT"
    hard_right = "HARD_RIGHT"
    circle_clockwise = "CIRCLE_CLOCKWISE"
    circle_counterclockwise = "CIRCLE_COUNTERCLOCKWISE"
    elevator = "ELEVATOR"
    uturn_left = "UTURN_LEFT"
    uturn_right = "UTURN_RIGHT"
    enter_station = "ENTER_STATION"
    exit_station = "EXIT_STATION"
    follow_signs = "FOLLOW_SIGNS"
    arrive = "ARRIVE"
    transit_transfer = "TRANSIT_TRANSFER"
    transit_board = "TRANSIT_BOARD"
    transit_ride = "TRANSIT_RIDE"
    transit_alight = "TRANSIT_ALIGHT"


class AbsoluteDirection(Enum):
    north = "NORTH"
    northeast = "NORTHEAST"
    east = "EAST"
    southeast = "SOUTHEAST"
    south = "SOUTH"
    southwest = "SOUTHWEST"
    west = "WEST"
    northwest = "NORTHWEST"
    unknown = "UNKNOWN"


class Step(BaseModel):
    distance: float
    lon: float
    lat: float
    relative_direction: RelativeDirection
    absolute_direction: AbsoluteDirection = AbsoluteDirection.unknown
    street_name: str
    bogus_name: bool
    voice_instruction: str | None = None
    text_instruction: str | None = None
    time_of_step: datetime | None = None


class Route(BaseModel):
    id: str
    short_name: str | None = None
    mode: Mode | None = None


class PlaceType(str, Enum):
    address = "address"
    stop = "stop"


class Place(BaseModel):
    id: str
    name: str
    type: PlaceType
    coordinates: Coordinates
    address: str | None = None


class LegSummary(BaseModel):
    mode: Mode
    duration: int
    distance: int
    ratio: float | None = None
    geometry: str


class LegDetailed(LegSummary):
    start_time: datetime
    end_time: datetime
    start_place: Place
    end_place: Place
    steps: list[Step]
    route: Route | None = None
    headsign: str | None = None
    intermediate_stops: list[Place] | None = None

    @model_validator(mode="before")
    def validate_headsign(cls, leg: dict[str, any]) -> dict[str, any]:
        if leg.get("route") is not None and leg.get("headsign") is None:
            raise ValueError("Leg with a route must have a headsign.")
        return leg


class ItineraryBase(BaseModel):
    itinerary_id: UUID
    duration: int
    start_time: datetime
    end_time: datetime
    origin: Coordinates
    destination: Coordinates


class ItinerarySummary(ItineraryBase):
    legs: list[LegSummary]

    @model_validator(mode="before")
    def compute_leg_ratios(cls, itinerary: dict[str, any]) -> dict[str, any]:
        total_duration = itinerary["duration"]
        for leg in itinerary["legs"]:
            leg.ratio = (
                round(leg.duration / total_duration, 2) if total_duration > 0 else 0
            )
        return itinerary


class ItineraryDetailed(ItineraryBase):
    legs: list[LegDetailed]


class RoutingEngine(str, Enum):
    open_trip_planner = "otp"
    open_trip_planner_kl = "otp_kl"
    valhalla = "valhalla"
    hybrid = "hybrid"


class WalkOptions(BaseModel):
    speed: float
    avoid: bool


class BicycleOptions(BaseModel):
    speed: float


class GuidanceLanguage(str, Enum):
    en = "en"
    de = "de"


"""Request and response models exposed via the API"""


class RoutingPlanRequestModel(BaseModel):
    origin: Coordinates
    destination: Coordinates
    date: str
    time: str
    time_is_arrival: bool = False
    transport_modes: list[Mode]
    walk: WalkOptions | None = None
    bicycle: BicycleOptions | None = None
    accessible: bool = False
    num_itineraries: int = 3
    guidance_language: GuidanceLanguage = GuidanceLanguage.en

    @field_validator("date", mode="before")
    @classmethod
    def validate_date(cls, value: str):
        try:
            datetime.strptime(value, "%Y-%m-%d")
            return value
        except ValueError:
            raise ValueError("Date must be in the format 'YYYY-MM-DD'.")

    @field_validator("time", mode="before")
    @classmethod
    def validate_time(cls, value: str):
        try:
            datetime.strptime(value, "%H:%M:%S")
            return value
        except ValueError:
            raise ValueError("Time must be in the format 'HH:MM:SS'.")


class RoutingPlanSummaryResponseModel(BaseModel):
    itineraries: list[ItinerarySummary]


class RoutingPlanDetailedResponseModel(BaseModel):
    itineraries: list[ItineraryDetailed]


class ItineraryResponseModel(ItineraryDetailed):
    pass
