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
import 'package:intl/intl.dart';
import 'package:navi4all/core/config.dart';
import 'package:navi4all/schemas/routing/itinerary.dart';
import 'package:navi4all/services/api.dart';

class RoutingService extends APIService {
  Future<List<Object>> getItineraries({
    required double originLat,
    required double originLon,
    required double destinationLat,
    required double destinationLon,
    required DateTime time,
    bool timeIsArrival = false,
    required List<String> transportModes,
    double? walkingSpeed,
    bool? walkingAvoid,
    double? bicycleSpeed,
    bool? accessible,
    int numItineraries = 3,
    required String guidanceLanguage,
    bool summarized = true,
  }) async {
    // Build request body
    Map<String, dynamic> data = {
      'origin': {'lat': originLat, 'lon': originLon},
      'destination': {'lat': destinationLat, 'lon': destinationLon},
      'date': DateFormat('yyyy-MM-dd').format(time),
      'time': DateFormat('HH:mm:ss').format(time),
      'time_is_arrival': timeIsArrival,
      'transport_modes': transportModes,
      'num_itineraries': numItineraries,
      'guidance_language': guidanceLanguage,
      'summarized': summarized,
    };
    if (walkingSpeed != null && walkingAvoid != null) {
      data['walk'] = {'speed': walkingSpeed, 'avoid': walkingAvoid};
    }
    if (bicycleSpeed != null) {
      data['bicycle'] = {'speed': bicycleSpeed};
    }
    if (accessible != null) {
      data['accessible'] = accessible;
    }

    // Make request
    Response response = await apiClient.post(
      '/routing/plan',
      queryParameters: {'engine': Settings.apiRoutingEngine},
      data: data,
    );

    if (response.statusCode != 200) {
      throw Exception(response.statusMessage);
    }
    return (response.data['itineraries'] as List)
        .map(
          (item) => summarized
              ? ItinerarySummary.fromJson(item)
              : ItineraryDetails.fromJson(item),
        )
        .toList();
  }

  Future<List<ItineraryDetails>> getItinerariesDetailed({
    required double originLat,
    required double originLon,
    required double destinationLat,
    required double destinationLon,
    required DateTime time,
    bool timeIsArrival = false,
    required List<String> transportModes,
    double? walkingSpeed,
    bool? walkingAvoid,
    double? bicycleSpeed,
    bool? accessible,
    int numItineraries = 3,
    required String guidanceLanguage,
  }) async {
    // Build request body
    Map<String, dynamic> data = {
      'origin': {'lat': originLat, 'lon': originLon},
      'destination': {'lat': destinationLat, 'lon': destinationLon},
      'date': DateFormat('yyyy-MM-dd').format(time),
      'time': DateFormat('HH:mm:ss').format(time),
      'time_is_arrival': timeIsArrival,
      'transport_modes': transportModes,
      'num_itineraries': numItineraries,
      'guidance_language': guidanceLanguage,
    };
    if (walkingSpeed != null && walkingAvoid != null) {
      data['walk'] = {'speed': walkingSpeed, 'avoid': walkingAvoid};
    }
    if (bicycleSpeed != null) {
      data['bicycle'] = {'speed': bicycleSpeed};
    }
    if (accessible != null) {
      data['accessible'] = accessible;
    }

    // Make request
    Response response = await apiClient.post(
      '/routing/itinerary-detailed',
      queryParameters: {'engine': Settings.apiRoutingEngine},
      data: data,
    );

    if (response.statusCode != 200) {
      throw Exception(response.statusMessage);
    }
    return (response.data['itineraries'] as List)
        .map((item) => ItineraryDetails.fromJson(item))
        .toList();
  }

  Future<ItineraryDetails> getItineraryDetails({
    required String itineraryId,
  }) async => ItineraryDetails.fromJson(
    (await apiClient.get(
      '/routing/itinerary/$itineraryId',
      queryParameters: {'engine': Settings.apiRoutingEngine},
    )).data,
  );
}
