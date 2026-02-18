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

import 'package:intl/intl.dart';
import 'package:navi4all/schemas/routing/itinerary.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as maps_toolkit;

class TextFormatter {
  static String formatDistanceText(ItinerarySummary itinerary) {
    final double distanceInMeters = itinerary.legs.fold(
      0,
      (sum, leg) => sum + leg.distance,
    );

    // Format distance based on its length, replace point with comma for locales that use comma
    if (distanceInMeters >= 1000) {
      final distanceInKm = formatKilometersDistanceFromMeters(distanceInMeters);
      return '${distanceInKm.toString().replaceAll('.', ',')} km';
    }
    return '${formatMetersDistanceFromMeters(distanceInMeters)} m';
  }

  static String formatDistanceValueText(double distance) {
    // Format distance based on its length, replace point with comma for locales that use comma
    if (distance >= 1000) {
      final distanceInKm = formatKilometersDistanceFromMeters(distance);
      return '${distanceInKm.toString().replaceAll('.', ',')} km';
    }
    return '${formatMetersDistanceFromMeters(distance)} m';
  }

  static int formatMetersDistanceFromMeters(double distance) {
    // Above 100m, round to the nearest 50m, below round to the nearest 10m
    if (distance > 100) {
      final roundedDistance = (distance / 50).round() * 50;
      return roundedDistance.round();
    } else {
      final roundedDistance = (distance / 10).round() * 10;
      return roundedDistance.round();
    }
  }

  static double formatKilometersDistanceFromMeters(double distance) {
    // Convert to km with one decimal place
    final distanceInKm = distance / 1000;
    return (distanceInKm * 10).round() / 10;
  }

  static String formatDurationText(int duration) {
    final durationInMinutes = (duration / 60).round();
    if (durationInMinutes < 60) {
      return '$durationInMinutes min';
    }
    final hours = durationInMinutes ~/ 60;
    final minutes = durationInMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  static String formatSpeedText(double speed) {
    if (speed % 1 == 0) {
      return '${speed.toInt()} km/h';
    } else {
      return '${speed.toStringAsFixed(1)} km/h';
    }
  }

  static String extractCityFromAddress(String fullAddress) {
    // Currently designed for the German address format
    List<String> addressParts = fullAddress.split(',');
    if (addressParts.length >= 2) {
      String cityPart = addressParts[1].trim();
      List<String> cityParts = cityPart.split(' ');
      if (cityParts.length >= 2) {
        return cityParts.sublist(1).join(' ');
      }
    }
    return '';
  }

  static String formatTimeOfDay(DateTime dateTime) =>
      DateFormat.Hm().format(dateTime);
}

class GeographyUtils {
  static int? getLocationIndexOnPath(
    maps_toolkit.LatLng point,
    List<maps_toolkit.LatLng> path,
    double threshold,
  ) {
    // Find nearest point on path within snapping threshold
    int? indexOnPath;
    num nearestDistance = double.infinity;

    for (int i = 0; i < path.length; i++) {
      num distance = maps_toolkit.SphericalUtil.computeDistanceBetween(
        point,
        path[i],
      );
      if (distance <= threshold &&
          (indexOnPath == null || distance < nearestDistance)) {
        indexOnPath = i;
        nearestDistance = distance;
      }
    }
    return indexOnPath;
  }
}
