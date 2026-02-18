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
import 'package:navi4all/core/persistence/preference_helper.dart';
import 'package:navi4all/schemas/routing/place.dart';
// import 'package:navi4all/services/poi_parking.dart';

class FavoritesController extends ChangeNotifier {
  // POIParkingService parkingService = POIParkingService();

  final List<Place> _favorites = [];
  FavoritesControllerState _state = FavoritesControllerState.idle;

  FavoritesController(BuildContext context) {
    refresh();
  }

  UnmodifiableListView<Place> get favorites => UnmodifiableListView(_favorites);
  FavoritesControllerState get state => _state;

  Future<void> addFavorite(Place place) async {
    await PreferenceHelper.addFavorite(place);
    refresh();
  }

  Future<void> removeFavorite(Place place) async {
    await PreferenceHelper.removeFavorite(place);
    refresh();
  }

  Future<void> reorderFavorite(int oldIndex, int newIndex) async {
    Place place = _favorites.removeAt(oldIndex);
    _favorites.insert(oldIndex < newIndex ? newIndex - 1 : newIndex, place);

    notifyListeners();

    await PreferenceHelper.reorderFavorite(place, newIndex);
  }

  Future<bool> checkIsFavorite(Place place) async {
    return await PreferenceHelper.isFavorite(place);
  }

  Future<void> refresh() async {
    _state = FavoritesControllerState.refreshing;

    try {
      _favorites.clear();

      // Fetch favorites from persistent storage
      List<Place> favoritesMetadata = await PreferenceHelper.getFavorites();

      // Refresh latest status of each favorite
      for (var item in favoritesMetadata) {
        _favorites.add(item);
      }
    } catch (e) {
      _state = FavoritesControllerState.error;
      notifyListeners();
      return;
    }

    _state = FavoritesControllerState.idle;
    notifyListeners();
  }
}

enum FavoritesControllerState { idle, refreshing, error }
