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
import 'package:navi4all/core/config.dart';
import 'package:navi4all/core/persistence/preference_helper.dart';
import 'package:navi4all/core/theme/profile_mode.dart';
import 'package:navi4all/schemas/routing/request_config.dart';

class ProfileController extends ChangeNotifier {
  RoutingRequestConfig _routingRequestConfig =
      Settings.routingRequestConfigs[Settings.defaultRoutingProfiles[ProfileMode
          .general]!]!;

  ProfileController() {
    _initialize();
  }

  RoutingRequestConfig get routingRequestConfig => _routingRequestConfig;

  Future<void> _initialize() async {
    RoutingRequestConfig? routingRequestConfig =
        await PreferenceHelper.getRoutingRequestConfig();

    if (routingRequestConfig != null) {
      setRoutingRequestConfig(routingRequestConfig);
      return;
    }

    ProfileMode profileMode = await PreferenceHelper.getProfileMode();
    setRoutingRequestConfig(
      Settings.routingRequestConfigs[Settings
          .defaultRoutingProfiles[profileMode]!]!,
    );
  }

  void setRoutingRequestConfig(RoutingRequestConfig config) {
    _routingRequestConfig = config;
    notifyListeners();

    PreferenceHelper.setRoutingRequestConfig(config);
  }

  Future<void> resetRoutingRequestConfig() async {
    ProfileMode profileMode = await PreferenceHelper.getProfileMode();
    RoutingRequestConfig defaultConfig = Settings
        .routingRequestConfigs[Settings.defaultRoutingProfiles[profileMode]!]!;

    setRoutingRequestConfig(defaultConfig);
  }

  RoutingProfile? getAssociatedRoutingProfile() {
    for (var entry in Settings.routingRequestConfigs.entries) {
      // Check individual fields for equality
      bool isDefault = true;
      isDefault &=
          _routingRequestConfig.walkingSpeed == entry.value.walkingSpeed;
      isDefault &=
          _routingRequestConfig.walkingAvoid == entry.value.walkingAvoid;
      isDefault &=
          _routingRequestConfig.transitModes.length ==
              entry.value.transitModes.length &&
          _routingRequestConfig.transitModes.every(
            (mode) => entry.value.transitModes.contains(mode),
          );
      isDefault &=
          _routingRequestConfig.bicycleSpeed == entry.value.bicycleSpeed;
      isDefault &= _routingRequestConfig.accessible == entry.value.accessible;

      if (isDefault) {
        return entry.key;
      }
    }

    return null;
  }
}
