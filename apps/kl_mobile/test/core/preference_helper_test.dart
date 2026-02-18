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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi4all/core/persistence/preference_helper.dart';
import 'package:navi4all/core/theme/base_map_style.dart';
import 'package:navi4all/core/theme/profile_mode.dart';
import 'package:navi4all/schemas/routing/mode.dart';
import 'package:navi4all/schemas/routing/place.dart';
import 'package:navi4all/schemas/routing/request_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('onboarding flag can be set and read', () async {
    expect(await PreferenceHelper.isOnboardingComplete(), isFalse);
    await PreferenceHelper.setOnboardingComplete(true);
    expect(await PreferenceHelper.isOnboardingComplete(), isTrue);
  });

  test('theme/profile/base map prefs round-trip', () async {
    await PreferenceHelper.setProfileMode(ProfileMode.visionImpaired);
    await PreferenceHelper.setThemeMode(ThemeMode.dark);
    await PreferenceHelper.setBaseMapStyle(BaseMapStyle.satellite);

    expect(await PreferenceHelper.getProfileMode(), ProfileMode.visionImpaired);
    expect(await PreferenceHelper.getThemeMode(), ThemeMode.dark);
    expect(await PreferenceHelper.getBaseMapStyle(), BaseMapStyle.satellite);
  });

  test('favorites and favorite checks from persisted storage', () async {
    final json = jsonEncode({
      'id': 'p1',
      'name': 'Central Station',
      'type': 'address',
      'description': 'Main station',
      'address': '1 Station Road',
      'coordinates': {'lat': 49.44, 'lon': 7.77},
    });

    SharedPreferences.setMockInitialValues({
      keyFavorites: [json],
    });

    final favorites = await PreferenceHelper.getFavorites();
    expect(favorites.length, 1);

    final probe = Place.fromJson({
      'id': 'p1',
      'name': 'Any',
      'type': 'address',
      'description': '',
      'address': '',
      'coordinates': {'lat': 0.0, 'lon': 0.0},
    });
    expect(await PreferenceHelper.isFavorite(probe), isTrue);

    await PreferenceHelper.removeFavorite(probe);
    expect(await PreferenceHelper.getFavorites(), isEmpty);
  });

  test('routing request config round-trip', () async {
    const config = RoutingRequestConfig(
      walkingSpeed: 5.0,
      walkingAvoid: false,
      transitModes: [Mode.BUS, Mode.TRAM],
      bicycleSpeed: 20.0,
      accessible: true,
    );

    await PreferenceHelper.setRoutingRequestConfig(config);
    expect(await PreferenceHelper.getRoutingRequestConfig(), config);
  });

  test('launch count increments', () async {
    expect(await PreferenceHelper.getLaunchCount(), 0);
    expect(await PreferenceHelper.incrementLaunchCount(), 1);
    expect(await PreferenceHelper.incrementLaunchCount(), 2);
    expect(await PreferenceHelper.getLaunchCount(), 2);
  });
}
