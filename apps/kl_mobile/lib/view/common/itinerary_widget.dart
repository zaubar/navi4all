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
import 'package:navi4all/core/utils.dart';
import 'package:navi4all/l10n/app_localizations.dart';
import 'package:navi4all/schemas/routing/itinerary.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:navi4all/core/theme/icons.dart' show ModeIcons;

class ItineraryWidget extends StatelessWidget {
  final ItinerarySummary itinerary;
  final Function onTap;

  const ItineraryWidget({
    super.key,
    required this.itinerary,
    required this.onTap,
  });

  String get _startTime => DateFormat.Hm().format(itinerary.startTime);

  String get _endTime => DateFormat.Hm().format(itinerary.endTime);

  String get _legSummaryDescription {
    return itinerary.legs
        .map((legSummary) {
          return '${legSummary.mode.name} (${(legSummary.duration / 60).round()} min)';
        })
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(),
      child: Semantics(
        label: AppLocalizations.of(context)!.journeyOptionSemantic(
          TextFormatter.formatDurationText(itinerary.duration),
          _startTime,
          _endTime,
          _legSummaryDescription,
        ),
        child: Semantics(
          excludeSemantics: true,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TextFormatter.formatDurationText(itinerary.duration),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    Text('$_startTime - $_endTime'),
                    const SizedBox(height: 4),
                    Row(
                      children: itinerary.legs.map((legSummary) {
                        return Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.tertiary,
                              borderRadius: BorderRadius.only(
                                topLeft: legSummary == itinerary.legs.first
                                    ? Radius.circular(32)
                                    : Radius.circular(0),
                                topRight: legSummary == itinerary.legs.last
                                    ? Radius.circular(32)
                                    : Radius.circular(0),
                                bottomLeft: legSummary == itinerary.legs.first
                                    ? Radius.circular(32)
                                    : Radius.circular(0),
                                bottomRight: legSummary == itinerary.legs.last
                                    ? Radius.circular(32)
                                    : Radius.circular(0),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            margin: legSummary != itinerary.legs.last
                                ? EdgeInsets.only(right: 4)
                                : EdgeInsets.zero,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Icon(
                                  ModeIcons.get(legSummary.mode),
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    TextFormatter.formatDurationText(
                                      legSummary.duration,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Divider(
                  color: Theme.of(context).colorScheme.secondary,
                  height: 0.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
