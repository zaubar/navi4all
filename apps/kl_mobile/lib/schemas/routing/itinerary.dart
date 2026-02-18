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
import 'coordinates.dart';
import 'leg.dart';

part 'itinerary.freezed.dart';
part 'itinerary.g.dart';

@freezed
abstract class ItinerarySummary with _$ItinerarySummary {
  const factory ItinerarySummary({
    @JsonKey(name: 'itinerary_id') required String itineraryId,
    required int duration,
    @JsonKey(name: 'start_time') required DateTime startTime,
    @JsonKey(name: 'end_time') required DateTime endTime,
    required Coordinates origin,
    required Coordinates destination,
    required List<LegSummary> legs,
  }) = _ItinerarySummary;

  factory ItinerarySummary.fromJson(Map<String, Object?> json) =>
      _$ItinerarySummaryFromJson(json);
}

@freezed
abstract class ItineraryDetails with _$ItineraryDetails {
  const factory ItineraryDetails({
    @JsonKey(name: 'itinerary_id') required String itineraryId,
    required int duration,
    @JsonKey(name: 'start_time') required DateTime startTime,
    @JsonKey(name: 'end_time') required DateTime endTime,
    required Coordinates origin,
    required Coordinates destination,
    required List<LegDetailed> legs,
  }) = _ItineraryDetails;

  factory ItineraryDetails.fromJson(Map<String, Object?> json) =>
      _$ItineraryDetailsFromJson(json);
}
