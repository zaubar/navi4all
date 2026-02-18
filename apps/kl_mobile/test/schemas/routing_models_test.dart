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

import 'package:flutter_test/flutter_test.dart';
import 'package:navi4all/schemas/routing/coordinates.dart';
import 'package:navi4all/schemas/routing/itinerary.dart';
import 'package:navi4all/schemas/routing/leg.dart';
import 'package:navi4all/schemas/routing/mode.dart';
import 'package:navi4all/schemas/routing/place.dart';
import 'package:navi4all/schemas/routing/request_config.dart';

void main() {
  group('Schema routing models', () {
    test('Coordinates round-trips via json', () {
      const model = Coordinates(lat: 49.44, lon: 7.77);
      final decoded = Coordinates.fromJson(model.toJson());
      expect(decoded, model);
    });

    test('Place uses address as fallback for unknown enum value', () {
      final place = Place.fromJson({
        'id': '1',
        'name': 'X',
        'type': 'SOMETHING_UNKNOWN',
        'description': 'd',
        'address': 'a',
        'coordinates': {'lat': 49.44, 'lon': 7.77},
      });

      expect(place.type, PlaceType.address);
    });

    test('RoutingRequestConfig round-trips via json', () {
      const config = RoutingRequestConfig(
        walkingSpeed: 5.0,
        walkingAvoid: false,
        transitModes: [Mode.BUS, Mode.TRAM],
        bicycleSpeed: 18.0,
        accessible: true,
      );

      final decoded = RoutingRequestConfig.fromJson(config.toJson());
      expect(decoded, config);
    });

    test('LegDetailed parses nested step and route', () {
      final leg = LegDetailed.fromJson({
        'start_time': '2026-02-18T10:00:00.000Z',
        'end_time': '2026-02-18T10:10:00.000Z',
        'mode': 'WALK',
        'duration': 600,
        'distance': 800,
        'geometry': 'abc',
        'steps': [
          {
            'distance': 100.0,
            'lat': 49.4401,
            'lon': 7.7701,
            'relative_direction': 'DEPART',
            'absolute_direction': 'NORTH',
            'street_name': 'Main St',
            'bogus_name': false,
          },
        ],
        'route': {'id': 'r1', 'short_name': '1', 'mode': 'BUS'},
      });

      expect(leg.steps.single.relativeDirection, RelativeDirection.DEPART);
      expect(leg.route?.mode, Mode.BUS);
    });

    test('ItinerarySummary and ItineraryDetails parse payloads', () {
      final summary = ItinerarySummary.fromJson({
        'itinerary_id': 'it-1',
        'duration': 1200,
        'start_time': '2026-02-18T10:00:00.000Z',
        'end_time': '2026-02-18T10:20:00.000Z',
        'origin': {'lat': 49.44, 'lon': 7.77},
        'destination': {'lat': 49.45, 'lon': 7.78},
        'legs': [
          {
            'mode': 'WALK',
            'duration': 1200,
            'distance': 1400,
            'ratio': 1.0,
            'geometry': 'g',
          },
        ],
      });

      final details = ItineraryDetails.fromJson({
        'itinerary_id': 'it-2',
        'duration': 1800,
        'start_time': '2026-02-18T10:00:00.000Z',
        'end_time': '2026-02-18T10:30:00.000Z',
        'origin': {'lat': 49.44, 'lon': 7.77},
        'destination': {'lat': 49.46, 'lon': 7.79},
        'legs': [
          {
            'start_time': '2026-02-18T10:00:00.000Z',
            'end_time': '2026-02-18T10:30:00.000Z',
            'mode': 'BUS',
            'duration': 1800,
            'distance': 3000,
            'geometry': 'h',
            'steps': [
              {
                'distance': 100.0,
                'lat': 49.4401,
                'lon': 7.7701,
                'relative_direction': 'DEPART',
                'absolute_direction': 'NORTH',
                'street_name': 'Main St',
                'bogus_name': false,
              },
            ],
          },
        ],
      });

      expect(summary.itineraryId, 'it-1');
      expect(summary.legs.single.mode, Mode.WALK);
      expect(details.itineraryId, 'it-2');
      expect(details.legs.single.mode, Mode.BUS);
    });
  });
}
