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
import 'package:maps_toolkit/maps_toolkit.dart' as maps_toolkit;
import 'package:navi4all/core/utils.dart';
import 'package:navi4all/schemas/routing/coordinates.dart';
import 'package:navi4all/schemas/routing/itinerary.dart';
import 'package:navi4all/schemas/routing/leg.dart';
import 'package:navi4all/schemas/routing/mode.dart';

void main() {
  group('TextFormatter', () {
    test('formats meters and kilometers', () {
      expect(TextFormatter.formatMetersDistanceFromMeters(96), 100);
      expect(TextFormatter.formatKilometersDistanceFromMeters(1499), 1.5);
      expect(TextFormatter.formatDistanceValueText(1499), '1,5 km');
      expect(TextFormatter.formatDistanceValueText(95), '100 m');
    });

    test('formats duration, speed and city extraction', () {
      expect(TextFormatter.formatDurationText(59 * 60), '59 min');
      expect(TextFormatter.formatDurationText(61 * 60), '1h 1m');
      expect(TextFormatter.formatSpeedText(5.0), '5 km/h');
      expect(TextFormatter.formatSpeedText(5.25), '5.3 km/h');
      expect(
        TextFormatter.extractCityFromAddress('Street 1, 67655 Kaiserslautern'),
        'Kaiserslautern',
      );
    });

    test('formats itinerary distance text', () {
      final itinerary = ItinerarySummary(
        itineraryId: 'it-3',
        duration: 1200,
        startTime: DateTime.utc(2026, 2, 18, 10),
        endTime: DateTime.utc(2026, 2, 18, 10, 20),
        origin: const Coordinates(lat: 49.44, lon: 7.77),
        destination: const Coordinates(lat: 49.45, lon: 7.78),
        legs: const [
          LegSummary(
            mode: Mode.WALK,
            duration: 400,
            distance: 700,
            ratio: 0.5,
            geometry: 'a',
          ),
          LegSummary(
            mode: Mode.BUS,
            duration: 800,
            distance: 600,
            ratio: 0.5,
            geometry: 'b',
          ),
        ],
      );

      expect(TextFormatter.formatDistanceText(itinerary), '1,3 km');
    });
  });

  group('GeographyUtils', () {
    test('returns nearest index within threshold', () {
      final point = maps_toolkit.LatLng(49.44002, 7.77002);
      final path = [
        maps_toolkit.LatLng(49.44, 7.77),
        maps_toolkit.LatLng(49.441, 7.771),
      ];

      final index = GeographyUtils.getLocationIndexOnPath(point, path, 20);
      expect(index, 0);
    });

    test('returns null when out of threshold', () {
      final point = maps_toolkit.LatLng(49.5, 7.9);
      final path = [
        maps_toolkit.LatLng(49.44, 7.77),
        maps_toolkit.LatLng(49.441, 7.771),
      ];

      final index = GeographyUtils.getLocationIndexOnPath(point, path, 20);
      expect(index, isNull);
    });
  });
}
