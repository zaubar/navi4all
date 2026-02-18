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

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:navi4all/core/persistence/preference_helper.dart';
import 'package:navi4all/schemas/routing/coordinates.dart';
import 'package:navi4all/schemas/routing/place.dart';
import 'package:navi4all/services/geocoding.dart';
import 'package:navi4all/core/config.dart';

class AutocompleteController extends ChangeNotifier {
  final GeocodingService _geocodingService = GeocodingService();

  SearchControllerState _state = SearchControllerState.idle;
  Coordinates _focalPoint = Settings.defaultFocalPoint;
  String _searchQuery = '';
  DateTime? _searchTimestamp;
  final List<Place> _searchResults = [];
  final List<Place> _recentSearches = [];

  AutocompleteController(BuildContext context) {
    _refreshRecentSearches();
    _initializeFocalPoint(context);
  }

  SearchControllerState get state => _state;
  UnmodifiableListView<Place> get searchResults =>
      UnmodifiableListView(_searchResults);
  UnmodifiableListView<Place> get recentSearches =>
      UnmodifiableListView(_recentSearches);
  String get searchQuery => _searchQuery;

  void updateSearchQuery(String query) {
    _searchQuery = query;
    _refresh();
  }

  Future<void> addRecentSearch(Place place) async {
    // Add place to recent searches
    await PreferenceHelper.addRecentSearch(place);

    // Update local recent searches list
    await _refreshRecentSearches();
  }

  void reset() {
    _searchQuery = '';
    _searchTimestamp = null;
    _searchResults.clear();
    notifyListeners();
  }

  Future<void> _initializeFocalPoint(BuildContext context) async {
    // Attempt to get current position (lazy)
    Position? currentPosition = await _getUserLocation(context);

    if (currentPosition != null) {
      _focalPoint = Coordinates(
        lat: currentPosition.latitude,
        lon: currentPosition.longitude,
      );
    }
  }

  Future<void> _refreshRecentSearches() async {
    _recentSearches.clear();
    _recentSearches.addAll(await PreferenceHelper.getRecentSearches());
    notifyListeners();
  }

  Future<void> _refresh() async {
    _state = SearchControllerState.refreshing;

    try {
      // Use timestamp to discard outdated results
      _searchTimestamp = DateTime.now();
      _searchResults.clear();

      if (_searchQuery.isNotEmpty) {
        // Search favorites by address and name
        List<Place> favoritePlaces = await PreferenceHelper.getFavorites();
        for (Place place in favoritePlaces) {
          if (place.address.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              place.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
            _searchResults.add(place.copyWith(isFavorite: true));
          }
        }

        // Fetch autocomplete results
        var (timestamp, places) = await _geocodingService.autocomplete(
          timestamp: _searchTimestamp!.toIso8601String(),
          query: _searchQuery,
          focusPointLat: _focalPoint.lat,
          focusPointLon: _focalPoint.lon,
          limit: 4,
        );

        // Ensure results are fresh
        if (_searchTimestamp != null && timestamp.isBefore(_searchTimestamp!)) {
          return;
        }

        _searchResults.addAll(places);
      }
    } catch (e) {
      _state = SearchControllerState.error;
      notifyListeners();
      return;
    }

    _state = SearchControllerState.idle;
    notifyListeners();
  }

  Future<Position?> _getUserLocation(BuildContext context) async {
    // Check location permission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return null;
    }

    // Fetch user location
    return await Geolocator.getLastKnownPosition();
  }
}

enum SearchControllerState { idle, refreshing, error }
