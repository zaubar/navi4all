// Navi4All
// Copyright (C) Navi4All contributors
// Maintainer: Plan4Better GmbH
//
// SPDX-License-Identifier: AGPL-3.0-only
//
// Licensed under the GNU Affero General Public License, Version 3 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.gnu.org/licenses/agpl-3.0.en.html
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:dio/dio.dart';
import 'package:navi4all/schemas/routing/place.dart';
import 'package:navi4all/services/api.dart';

class GeocodingService extends APIService {
  Future<(DateTime, List<Place>)> autocomplete({
    required String timestamp,
    required String query,
    double? focusPointLat,
    double? focusPointLon,
    int limit = 5,
  }) async {
    Response response = await apiClient.get(
      '/geocoding/autocomplete',
      queryParameters: {
        'timestamp': timestamp,
        'query': query,
        if (focusPointLat != null) 'focus_point_lat': focusPointLat,
        if (focusPointLon != null) 'focus_point_lon': focusPointLon,
        'limit': limit,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(response.statusMessage);
    }
    return (
      DateTime.parse(response.data['timestamp']),
      (response.data['results'] as List)
          .map((item) => Place.fromJson(item))
          .toList(),
    );
  }
}
