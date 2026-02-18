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
import 'mode.dart';

part 'leg.freezed.dart';
part 'leg.g.dart';

@freezed
abstract class LegSummary with _$LegSummary {
  const factory LegSummary({
    required Mode mode,
    required int duration,
    required int distance,
    required double ratio,
    required String geometry,
  }) = _LegSummary;

  factory LegSummary.fromJson(Map<String, Object?> json) =>
      _$LegSummaryFromJson(json);
}

@freezed
abstract class LegDetailed with _$LegDetailed {
  const factory LegDetailed({
    @JsonKey(name: "start_time") required DateTime startTime,
    @JsonKey(name: "end_time") required DateTime endTime,
    required Mode mode,
    required int duration,
    required int distance,
    required String geometry,
    required List<Step> steps,
    Route? route,
    String? headsign,
  }) = _LegDetailed;

  factory LegDetailed.fromJson(Map<String, Object?> json) =>
      _$LegDetailedFromJson(json);
}

@freezed
abstract class Route with _$Route {
  const factory Route({
    required String id,
    @JsonKey(name: "short_name") String? shortName,
    Mode? mode,
  }) = _Route;

  factory Route.fromJson(Map<String, Object?> json) => _$RouteFromJson(json);
}

@freezed
abstract class Step with _$Step {
  const factory Step({
    required double distance,
    required double lat,
    required double lon,
    @JsonKey(name: "relative_direction")
    required RelativeDirection relativeDirection,
    @JsonKey(name: "absolute_direction")
    required AbsoluteDirection absoluteDirection,
    @JsonKey(name: "street_name") required String streetName,
    @JsonKey(name: "bogus_name") required bool bogusName,
    @JsonKey(name: "voice_instruction") String? voiceInstruction,
    @JsonKey(name: "text_instruction") String? textInstruction,
    @JsonKey(name: "time_of_step") DateTime? timeOfStep,
  }) = _Step;

  factory Step.fromJson(Map<String, Object?> json) => _$StepFromJson(json);
}
