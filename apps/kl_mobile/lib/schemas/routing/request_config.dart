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

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:navi4all/schemas/routing/mode.dart';

part 'request_config.freezed.dart';
part 'request_config.g.dart';

@freezed
abstract class RoutingRequestConfig with _$RoutingRequestConfig {
  const factory RoutingRequestConfig({
    required double walkingSpeed,
    required bool walkingAvoid,
    required List<Mode> transitModes,
    required double bicycleSpeed,
    required bool accessible,
  }) = _RoutingRequestConfig;

  factory RoutingRequestConfig.fromJson(Map<String, dynamic> json) =>
      _$RoutingRequestConfigFromJson(json);
}
