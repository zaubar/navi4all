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

import 'package:flutter/material.dart';
import 'package:navi4all/schemas/routing/mode.dart';
import 'package:navi4all/schemas/routing/place.dart';

class ModeIcons {
  static const Map<Mode, IconData> icons = {
    Mode.BICYCLE: Icons.directions_bike,
    Mode.BUS: Icons.directions_bus,
    Mode.CABLE_CAR: Icons.directions_railway,
    Mode.CAR: Icons.directions_car,
    Mode.COACH: Icons.directions_bus,
    Mode.FERRY: Icons.directions_boat,
    Mode.FUNICULAR: Icons.directions_railway,
    Mode.GONDOLA: Icons.directions_railway,
    Mode.RAIL: Icons.train,
    Mode.SUBWAY: Icons.subway,
    Mode.TRAM: Icons.tram,
    Mode.TRANSIT: Icons.directions_transit,
    Mode.WALK: Icons.directions_walk,
    Mode.TROLLEYBUS: Icons.directions_bus,
    Mode.MONORAIL: Icons.subway,
  };

  static IconData get(Mode mode) {
    return icons[mode] ?? Icons.commute;
  }
}

class PlaceTypeIcons {
  static const Map<PlaceType, IconData> icons = {
    PlaceType.address: Icons.place_outlined,
    PlaceType.street: Icons.signpost_outlined,
    PlaceType.parkingSpot: Icons.local_parking,
    PlaceType.parkingSite: Icons.local_parking,
  };

  static IconData get(PlaceType type) {
    return icons[type] ?? Icons.place_outlined;
  }
}
