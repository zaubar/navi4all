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
