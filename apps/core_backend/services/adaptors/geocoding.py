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

from schemas.geocoding import (
    SupportedGeocodingProviders,
    GeocodingAutocompleteRequestModel,
    GeocodingAutocompleteResponseModel,
    GeocodingReverseRequestModel,
    GeocodingReverseResponseModel,
)
from httpx import AsyncClient, Response
from urllib.parse import urljoin
from fastapi import HTTPException
from schemas.place import Place, PlaceType
from schemas.coordinates import Coordinates


class GeocodingAdaptor:
    def __init__(
        self, provider: SupportedGeocodingProviders, api_url: str, api_key: str
    ):
        self.provider = provider
        self.api_url = api_url
        self.api_key = api_key

    def _build_request_pelias_autocomplete(
        self, request: GeocodingAutocompleteRequestModel
    ) -> tuple[str, dict]:
        """Build the request URL and params for a Pelias autocomplete request."""

        request_url = urljoin(self.api_url, "v1/autocomplete")
        request_params = {
            "api_key": self.api_key,
            "text": request.query,
            # TODO: Make layer exclusion dynamic
            "layers": "-country,-region,-macrocounty,-borough,-county,-localadmin,-locality",
        }
        if request.focus_point:
            request_params["focus.point.lat"] = request.focus_point.lat
            request_params["focus.point.lon"] = request.focus_point.lon
        return request_url, request_params

    def _process_response_pelias(self, response: Response) -> list[Place]:
        """Process the response from a Pelias request."""

        places = []
        for feature in response.json()["features"]:
            # Determine place type
            type: PlaceType = PlaceType.ADDRESS
            if feature["properties"]["layer"] == PlaceType.STREET.value:
                type = PlaceType.STREET
            
            places.append(
                Place(
                    id=feature["properties"]["id"],
                    name=feature["properties"]["name"],
                    address=feature["properties"]["label"],
                    type=type,
                    street=feature["properties"].get("street", None),
                    locality=feature["properties"].get("locality", None),
                    postcode=feature["properties"].get("postalcode", None),
                    coordinates=Coordinates(
                        lat=feature["geometry"]["coordinates"][1],
                        lon=feature["geometry"]["coordinates"][0],
                    ),
                )
            )

        return places


    def _build_request_pelias_reverse(
        self, request: GeocodingReverseRequestModel
    ) -> tuple[str, dict]:
        """Build the request URL and params for a Pelias reverse geocoding request."""

        request_url = urljoin(self.api_url, "v1/reverse")
        request_params = {
            "api_key": self.api_key,
            "point.lat": request.lat,
            "point.lon": request.lon,
            "layers": "address,street,venue,neighbourhood",
        }
        return request_url, request_params

    def _process_response_pelias_reverse(self, response: Response) -> list[Place]:
        """Process the response from a Pelias reverse geocoding request."""

        places = []
        for feature in response.json()["features"]:
            # Determine place type
            ptype: PlaceType = PlaceType.ADDRESS
            if feature["properties"]["layer"] == PlaceType.STREET.value:
                ptype = PlaceType.STREET

            places.append(
                Place(
                    id=feature["properties"]["id"],
                    name=feature["properties"]["name"],
                    address=feature["properties"]["label"],
                    type=ptype,
                    street=feature["properties"].get("street", None),
                    locality=feature["properties"].get("locality", None),
                    postcode=feature["properties"].get("postalcode", None),
                    coordinates=Coordinates(
                        lat=feature["geometry"]["coordinates"][1],
                        lon=feature["geometry"]["coordinates"][0],
                    ),
                )
            )

        return places

    async def reverse(
        self, async_client: AsyncClient, request: GeocodingReverseRequestModel
    ) -> GeocodingReverseResponseModel:
        """Make a reverse geocoding request."""

        # Build request URL and params
        if self.provider == SupportedGeocodingProviders.PELIAS:
            request_url, request_params = self._build_request_pelias_reverse(request)
        else:
            raise HTTPException(
                status_code=400, detail="Unsupported geocoding provider."
            )

        # Make request to selected geocoding provider
        response = await async_client.get(
            url=request_url,
            params=request_params,
        )

        if response.status_code != 200:
            raise HTTPException(
                status_code=response.status_code, detail="Reverse geocoding request failed."
            )

        # Process response
        places: list[Place] = []
        if self.provider == SupportedGeocodingProviders.PELIAS:
            places = self._process_response_pelias_reverse(response)

        # Clip length of response if limit is set
        if request.limit and len(places) > request.limit:
            places = places[: request.limit]

        return GeocodingReverseResponseModel(
            timestamp=request.timestamp,
            results=places,
        )


    async def autocomplete(
        self, async_client: AsyncClient, request: GeocodingAutocompleteRequestModel
    ) -> list[Place]:
        """Make an autocomplete geocoding request."""

        # Build request URL and params
        if self.provider == SupportedGeocodingProviders.PELIAS:
            request_url, request_params = self._build_request_pelias_autocomplete(
                request
            )
        else:
            raise HTTPException(
                status_code=400, detail="Unsupported geocoding provider."
            )

        # Make request to selected geocoding provider
        response = await async_client.get(
            url=request_url,
            params=request_params,
        )

        if response.status_code != 200:
            raise HTTPException(
                status_code=response.status_code, detail="Geocoding request failed."
            )

        # Process response
        places: list[Place] = []
        if self.provider == SupportedGeocodingProviders.PELIAS:
            places = self._process_response_pelias(response)

        # Clip length of response if limit is set
        if request.limit and len(places) > request.limit:
            places = places[: request.limit]

        return GeocodingAutocompleteResponseModel(
            timestamp=request.timestamp,
            results=places,
        )
