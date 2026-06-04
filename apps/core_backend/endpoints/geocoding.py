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

import httpx
from fastapi import APIRouter
from schemas.coordinates import Coordinates
from schemas.geocoding import GeocodingAutocompleteRequestModel, GeocodingAutocompleteResponseModel, GeocodingReverseRequestModel, GeocodingReverseResponseModel
from services.adaptors.geocoding import GeocodingAdaptor
from core.config import settings

router = APIRouter(prefix="/geocoding")
adaptor = GeocodingAdaptor(
    provider=settings.GEOCODING_PROVIDER,
    api_url=settings.GEOCODING_PROVIDER_API_URL,
    api_key=settings.GEOCODING_PROVIDER_API_KEY,
)


@router.get("/autocomplete", response_model=GeocodingAutocompleteResponseModel)
async def autocomplete(
    timestamp: str,
    query: str,
    focus_point_lat: float | None = None,
    focus_point_lon: float | None = None,
    limit: int | None = 5,
):
    async with httpx.AsyncClient() as client:
        response = await adaptor.autocomplete(
            client,
            GeocodingAutocompleteRequestModel(
                timestamp=timestamp,
                query=query,
                focus_point=Coordinates(lat=focus_point_lat, lon=focus_point_lon)
                if focus_point_lat is not None and focus_point_lon is not None
                else None,
                limit=limit,
            ),
        )
    return response



@router.get("/reverse", response_model=GeocodingReverseResponseModel)
async def reverse(
    timestamp: str,
    lat: float,
    lon: float,
    limit: int | None = 5,
):
    async with httpx.AsyncClient() as client:
        response = await adaptor.reverse(
            client,
            GeocodingReverseRequestModel(
                timestamp=timestamp,
                lat=lat,
                lon=lon,
                limit=limit,
            ),
        )
    return response
