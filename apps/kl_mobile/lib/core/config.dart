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

import 'package:navi4all/core/theme/base_map_style.dart';
import 'package:navi4all/core/theme/profile_mode.dart';
import 'package:navi4all/schemas/routing/audio_stage.dart';
import 'package:navi4all/schemas/routing/coordinates.dart';
import 'package:navi4all/schemas/routing/mode.dart';
import 'package:navi4all/schemas/routing/request_config.dart';

class Settings {
  static String _requiredString(String key, String value) {
    if (value.isEmpty) {
      throw StateError('Missing required environment value: $key');
    }
    return value;
  }

  static int _requiredInt(String key, int value) {
    if (value == 0) {
      throw StateError('Missing required environment value: $key');
    }
    return value;
  }

  static double _requiredDouble(String key, String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) {
      throw StateError('Invalid double environment value for $key: $value');
    }
    return parsed;
  }

  // Matomo analytics settings
  static const String matomoUrl = String.fromEnvironment('MATOMO_URL');
  static const String matomoSiteId = String.fromEnvironment('MATOMO_SITE_ID');

  // API service settings
  static final String apiBaseUrl = _requiredString(
    'API_BASE_URL',
    const String.fromEnvironment('API_BASE_URL'),
  );
  static const String apiAuthorizationUsername = String.fromEnvironment(
    'API_AUTH_USERNAME',
  );
  static const String apiAuthorizationPassword = String.fromEnvironment(
    'API_AUTH_PASSWORD',
  );
  static final int apiConnectTimeout = _requiredInt(
    'API_CONNECT_TIMEOUT',
    const int.fromEnvironment('API_CONNECT_TIMEOUT'),
  );
  static final int apiReceiveTimeout = _requiredInt(
    'API_RECEIVE_TIMEOUT',
    const int.fromEnvironment('API_RECEIVE_TIMEOUT'),
  );
  static final String apiRoutingEngine = _requiredString(
    'API_ROUTING_ENGINE',
    const String.fromEnvironment('API_ROUTING_ENGINE'),
  );
  static final int dataRefreshIntervalSeconds = _requiredInt(
    'DATA_REFRESH_INTERVAL_SECONDS',
    const int.fromEnvironment('DATA_REFRESH_INTERVAL_SECONDS'),
  );

  // Fallback coordinates if user location is unavailable
  static final Coordinates defaultFocalPoint = Coordinates(
    lat: _requiredDouble(
      'DEFAULT_FOCAL_LAT',
      const String.fromEnvironment('DEFAULT_FOCAL_LAT'),
    ),
    lon: _requiredDouble(
      'DEFAULT_FOCAL_LON',
      const String.fromEnvironment('DEFAULT_FOCAL_LON'),
    ),
  );

  // Base map styles
  static final Map<BaseMapStyle, String> baseMapStyleUrls = {
    BaseMapStyle.light: _requiredString(
      'BASE_MAP_STYLE_URL_LIGHT',
      const String.fromEnvironment('BASE_MAP_STYLE_URL_LIGHT'),
    ),
    BaseMapStyle.dark: _requiredString(
      'BASE_MAP_STYLE_URL_DARK',
      const String.fromEnvironment('BASE_MAP_STYLE_URL_DARK'),
    ),
    BaseMapStyle.satellite: _requiredString(
      'BASE_MAP_STYLE_URL_SATELLITE',
      const String.fromEnvironment('BASE_MAP_STYLE_URL_SATELLITE'),
    ),
  };

  // Support and feedback
  static final String supportEmailUrl = _requiredString(
    'SUPPORT_EMAIL_URL',
    const String.fromEnvironment('SUPPORT_EMAIL_URL'),
  );
  static final String supportEmailSubject = _requiredString(
    'SUPPORT_EMAIL_SUBJECT',
    const String.fromEnvironment('SUPPORT_EMAIL_SUBJECT'),
  );
  static final String feedbackEmailSubject = _requiredString(
    'FEEDBACK_EMAIL_SUBJECT',
    const String.fromEnvironment('FEEDBACK_EMAIL_SUBJECT'),
  );

  // User engagement
  static const int userEngagementMinLaunchCount = 3;

  // Navigation audio thresholds
  static const Map<AudioStage, double> navigationAudioStages = {
    AudioStage.far: 250,
    AudioStage.medium: 100,
    AudioStage.near: 8,
  };

  // Caching
  static const int numRecentSearchesRetained = 5;

  // Default routing profile request configs
  static const Map<ProfileMode, RoutingProfile> defaultRoutingProfiles = {
    ProfileMode.general: RoutingProfile.standard,
    ProfileMode.visionImpaired: RoutingProfile.visionImpairment,
    ProfileMode.blind: RoutingProfile.visionImpairment,
  };

  // Additional routing profile request configs
  static const Map<RoutingProfile, RoutingRequestConfig> routingRequestConfigs =
      {
        RoutingProfile.standard: RoutingRequestConfig(
          walkingSpeed: 5.0,
          walkingAvoid: false,
          transitModes: [Mode.BUS, Mode.TRAM, Mode.SUBWAY, Mode.RAIL],
          bicycleSpeed: 20.0,
          accessible: false,
        ),
        RoutingProfile.visionImpairment: RoutingRequestConfig(
          walkingSpeed: 3.0,
          walkingAvoid: false,
          transitModes: [Mode.BUS, Mode.TRAM, Mode.SUBWAY, Mode.RAIL],
          bicycleSpeed: 15.0,
          accessible: true,
        ),
        RoutingProfile.wheelchair: RoutingRequestConfig(
          walkingSpeed: 5.0,
          walkingAvoid: true,
          transitModes: [Mode.BUS, Mode.TRAM, Mode.SUBWAY, Mode.RAIL],
          bicycleSpeed: 15.0,
          accessible: true,
        ),
        RoutingProfile.rollator: RoutingRequestConfig(
          walkingSpeed: 2.0,
          walkingAvoid: true,
          transitModes: [Mode.BUS, Mode.TRAM, Mode.SUBWAY, Mode.RAIL],
          bicycleSpeed: 15.0,
          accessible: true,
        ),
        RoutingProfile.slightWalkingDisability: RoutingRequestConfig(
          walkingSpeed: 3.0,
          walkingAvoid: false,
          transitModes: [Mode.BUS, Mode.TRAM, Mode.SUBWAY, Mode.RAIL],
          bicycleSpeed: 15.0,
          accessible: false,
        ),
        RoutingProfile.moderateWalkingDisability: RoutingRequestConfig(
          walkingSpeed: 2.0,
          walkingAvoid: false,
          transitModes: [Mode.BUS, Mode.TRAM, Mode.SUBWAY, Mode.RAIL],
          bicycleSpeed: 15.0,
          accessible: true,
        ),
        RoutingProfile.severeWalkingDisability: RoutingRequestConfig(
          walkingSpeed: 1.0,
          walkingAvoid: true,
          transitModes: [Mode.BUS, Mode.TRAM, Mode.SUBWAY, Mode.RAIL],
          bicycleSpeed: 15.0,
          accessible: true,
        ),
        RoutingProfile.stroller: RoutingRequestConfig(
          walkingSpeed: 5.0,
          walkingAvoid: false,
          transitModes: [Mode.BUS, Mode.TRAM, Mode.SUBWAY, Mode.RAIL],
          bicycleSpeed: 15.0,
          accessible: true,
        ),
      };

  // Legal and privacy
  static final String legalAndPrivacyUrl = _requiredString(
    'LEGAL_AND_PRIVACY_URL',
    const String.fromEnvironment('LEGAL_AND_PRIVACY_URL'),
  );
}
