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

from pydantic import BaseModel, field_validator
from enum import Enum
from schemas.routing import RelativeDirection, Mode


class ValhallaLocation(BaseModel):
    lat: float
    lon: float


class ValhallaCosting(str, Enum):
    auto = "auto"
    multi_modal = "multimodal"
    pedestrian = "pedestrian"


MODE_TO_COSTING: dict[Mode, ValhallaCosting] = {
    Mode.airplane: ValhallaCosting.multi_modal,
    Mode.bicycle: ValhallaCosting.auto,
    Mode.bus: ValhallaCosting.multi_modal,
    Mode.cable_car: ValhallaCosting.multi_modal,
    Mode.car: ValhallaCosting.auto,
    Mode.coach: ValhallaCosting.multi_modal,
    Mode.ferry: ValhallaCosting.multi_modal,
    Mode.flex: ValhallaCosting.multi_modal,
    Mode.funicular: ValhallaCosting.multi_modal,
    Mode.gondola: ValhallaCosting.multi_modal,
    Mode.rail: ValhallaCosting.multi_modal,
    Mode.scooter: ValhallaCosting.pedestrian,
    Mode.subway: ValhallaCosting.multi_modal,
    Mode.tram: ValhallaCosting.multi_modal,
    Mode.carpool: ValhallaCosting.auto,
    Mode.taxi: ValhallaCosting.auto,
    Mode.transit: ValhallaCosting.multi_modal,
    Mode.walk: ValhallaCosting.pedestrian,
    Mode.trolleybus: ValhallaCosting.multi_modal,
    Mode.monorail: ValhallaCosting.multi_modal,
}


class ValhallaPedestrianCostingOptionsType(str, Enum):
    foot = "foot"
    wheelchair = "wheelchair"
    blind = "blind"


class ValhallaPedestrianCostingOptions(BaseModel):
    walking_speed: float | None = None
    surface_smoothness: float | None = None
    type: ValhallaPedestrianCostingOptionsType | None = None


class ValhallaCostingOptions(BaseModel):
    pedestrian: ValhallaPedestrianCostingOptions | None = None


class ValhallaLanguage(str, Enum):
    en = "en-GB"
    de = "de-DE"


class ValhallaManeuverType(int, Enum):
    kNone = 0
    kStart = 1
    kStartRight = 2
    kStartLeft = 3
    kDestination = 4
    kDestinationRight = 5
    kDestinationLeft = 6
    kBecomes = 7
    kContinue = 8
    kSlightRight = 9
    kRight = 10
    kSharpRight = 11
    kUturnRight = 12
    kUturnLeft = 13
    kSharpLeft = 14
    kLeft = 15
    kSlightLeft = 16
    kRampStraight = 17
    kRampRight = 18
    kRampLeft = 19
    kExitRight = 20
    kExitLeft = 21
    kStayStraight = 22
    kStayRight = 23
    kStayLeft = 24
    kMerge = 25
    kRoundaboutEnter = 26
    kRoundaboutExit = 27
    kFerryEnter = 28
    kFerryExit = 29
    kTransit = 30
    kTransitTransfer = 31
    kTransitRemainOn = 32
    kTransitConnectionStart = 33
    kTransitConnectionTransfer = 34
    kTransitConnectionDestination = 35
    kPostTransitConnectionDestination = 36
    kMergeRight = 37
    kMergeLeft = 38
    kElevatorEnter = 39
    kStepsEnter = 40
    kEscalatorEnter = 41
    kBuildingEnter = 42
    kBuildingExit = 43


MANEUVER_TYPE_TO_RELATIVE_DIRECTION: dict[ValhallaManeuverType, RelativeDirection] = {
    ValhallaManeuverType.kNone: RelativeDirection.continue_,
    ValhallaManeuverType.kStart: RelativeDirection.depart,
    ValhallaManeuverType.kStartRight: RelativeDirection.depart,
    ValhallaManeuverType.kStartLeft: RelativeDirection.depart,
    ValhallaManeuverType.kContinue: RelativeDirection.continue_,
    ValhallaManeuverType.kSlightRight: RelativeDirection.slightly_right,
    ValhallaManeuverType.kRight: RelativeDirection.right,
    ValhallaManeuverType.kSharpRight: RelativeDirection.hard_right,
    ValhallaManeuverType.kUturnRight: RelativeDirection.uturn_right,
    ValhallaManeuverType.kUturnLeft: RelativeDirection.uturn_left,
    ValhallaManeuverType.kSharpLeft: RelativeDirection.hard_left,
    ValhallaManeuverType.kLeft: RelativeDirection.left,
    ValhallaManeuverType.kSlightLeft: RelativeDirection.slightly_left,
    ValhallaManeuverType.kStayStraight: RelativeDirection.continue_,
    ValhallaManeuverType.kRoundaboutEnter: RelativeDirection.circle_clockwise,
    ValhallaManeuverType.kElevatorEnter: RelativeDirection.elevator,
    ValhallaManeuverType.kStepsEnter: RelativeDirection.continue_,
    ValhallaManeuverType.kEscalatorEnter: RelativeDirection.continue_,
    ValhallaManeuverType.kBuildingEnter: RelativeDirection.continue_,
    ValhallaManeuverType.kBuildingExit: RelativeDirection.exit_station,
    ValhallaManeuverType.kDestination: RelativeDirection.arrive,
    ValhallaManeuverType.kDestinationRight: RelativeDirection.arrive,
    ValhallaManeuverType.kDestinationLeft: RelativeDirection.arrive,
    ValhallaManeuverType.kBecomes: RelativeDirection.continue_,
    ValhallaManeuverType.kRampStraight: RelativeDirection.continue_,
    ValhallaManeuverType.kRampRight: RelativeDirection.right,
    ValhallaManeuverType.kRampLeft: RelativeDirection.left,
    ValhallaManeuverType.kExitRight: RelativeDirection.right,
    ValhallaManeuverType.kExitLeft: RelativeDirection.left,
    ValhallaManeuverType.kStayRight: RelativeDirection.continue_,
    ValhallaManeuverType.kStayLeft: RelativeDirection.continue_,
    ValhallaManeuverType.kMerge: RelativeDirection.continue_,
    ValhallaManeuverType.kMergeRight: RelativeDirection.continue_,
    ValhallaManeuverType.kMergeLeft: RelativeDirection.continue_,
    ValhallaManeuverType.kRoundaboutExit: RelativeDirection.continue_,
    ValhallaManeuverType.kFerryEnter: RelativeDirection.continue_,
    ValhallaManeuverType.kFerryExit: RelativeDirection.continue_,
    ValhallaManeuverType.kTransit: RelativeDirection.continue_,
    ValhallaManeuverType.kTransitTransfer: RelativeDirection.continue_,
    ValhallaManeuverType.kTransitRemainOn: RelativeDirection.continue_,
    ValhallaManeuverType.kTransitConnectionStart: RelativeDirection.enter_station,
    ValhallaManeuverType.kTransitConnectionTransfer: RelativeDirection.follow_signs,
    ValhallaManeuverType.kTransitConnectionDestination: RelativeDirection.exit_station,
    ValhallaManeuverType.kPostTransitConnectionDestination: RelativeDirection.exit_station,
}


class ValhallaTravelMode(str, Enum):
    drive = "drive"
    pedestrian = "pedestrian"
    bicycle = "bicycle"
    transit = "transit"


TRAVEL_MODE_TO_MODE: dict[ValhallaTravelMode, Mode] = {
    ValhallaTravelMode.drive: Mode.car,
    ValhallaTravelMode.pedestrian: Mode.walk,
    ValhallaTravelMode.bicycle: Mode.bicycle,
    ValhallaTravelMode.transit: Mode.transit,
}


class ValhallaManeuver(BaseModel):
    type: ValhallaManeuverType
    instruction: str
    verbal_pre_transition_instruction: str | None = None
    travel_mode: ValhallaTravelMode
    time: float  # in seconds
    length: float  # in kilometers
    begin_shape_index: int
    end_shape_index: int
    
    @field_validator("type", mode="before")
    @classmethod
    def validate_type(cls, value: int):
        try:
            return ValhallaManeuverType(value)
        except ValueError:
            return ValhallaManeuverType.kNone


class ValhallaSummary(BaseModel):
    time: float  # in seconds
    length: float  # in kilometers


class ValhallaLeg(BaseModel):
    maneuvers: list[ValhallaManeuver]
    summary: ValhallaSummary
    shape: str


class ValhallaTrip(BaseModel):
    legs: list[ValhallaLeg]
    summary: ValhallaSummary


class ValhallaRouteRequestModel(BaseModel):
    locations: list[ValhallaLocation]
    costing: ValhallaCosting = ValhallaCosting.pedestrian
    costing_options: ValhallaCostingOptions | None = None
    language: ValhallaLanguage = ValhallaLanguage.en
    
    @field_validator("language", mode="before")
    @classmethod
    def validate_language(cls, value: str):
        """ Check if any of the ValhallaLanguage enum values contain the provided value. """
        for lang in ValhallaLanguage:
            if lang.value.startswith(value):
                return lang
        return ValhallaLanguage.en


class ValhallaRouteResponseModel(BaseModel):
    trip: ValhallaTrip
