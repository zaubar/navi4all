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

from pydantic import BaseModel, computed_field
from schemas.coordinates import Coordinates
from enum import Enum


class Place(BaseModel):
    id: str
    name: str
    type: "PlaceType"
    address: str
    street: str | None = None
    locality: str | None = None
    postcode: str | None = None
    coordinates: Coordinates

    @computed_field
    def description(self) -> str:
        """Produces a simplified subtext from the address."""
        parts = [self.street, self.locality, self.postcode]
        return (
            ", ".join(part for part in parts if part)
            if self.street or self.locality and self.name != self.locality
            else self.address
        )

class PlaceType(Enum):
    ADDRESS = "address"
    STREET = "street"
    PARKING_SPOT = "parkingSpot"
    PARKING_SITE = "parkingSite"
