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
// import 'package:matomo_tracker/matomo_tracker.dart';
import 'package:navi4all/view/search/search.dart';
import 'package:navi4all/view/favourites/favorites.dart';
import 'package:navi4all/view/settings/settings.dart';
// import 'package:navi4all/core/analytics/events.dart';
import 'package:navi4all/l10n/app_localizations.dart';
import 'package:navi4all/view/home/map.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<StatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _pageIndex = 0;
  List<Widget> get _pages => [HomeMap(), FavoritesScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Stack(
            children: [
              Offstage(
                offstage: _pageIndex != 0,
                child: TickerMode(enabled: _pageIndex == 0, child: _pages[0]),
              ),
              Offstage(
                offstage: _pageIndex != 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 64.0),
                  child: TickerMode(enabled: _pageIndex == 1, child: _pages[1]),
                ),
              ),
              Offstage(
                offstage: _pageIndex != 2,
                child: TickerMode(enabled: _pageIndex == 2, child: _pages[2]),
              ),
            ],
          ),
          _pageIndex <= 1
              ? SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 32,
                        left: 16,
                        right: 16,
                      ),
                      child: Material(
                        elevation: _pageIndex == 0 ? 4 : 0,
                        borderRadius: BorderRadius.circular(28),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const SearchScreen(),
                              ),
                            );

                            // Analytics event
                            /* MatomoTracker.instance.trackEvent(
                              eventInfo: EventInfo(
                                category: EventCategory.homeMapScreen
                                    .toString(),
                                action: EventAction.homeMapScreenSearchClicked
                                    .toString(),
                              ),
                            ); */
                          },
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              color: _pageIndex == 0
                                  ? Theme.of(context).colorScheme.surface
                                  : Theme.of(context).colorScheme.tertiary,
                            ),
                            child: Row(
                              children: [
                                SizedBox(width: 24),
                                Icon(
                                  Icons.search,
                                  color: _pageIndex == 0
                                      ? Theme.of(
                                          context,
                                        ).textTheme.displayMedium?.color
                                      : Theme.of(context).colorScheme.primary,
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.homeSearchButtonHint,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _pageIndex == 0
                                          ? null
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : Container(),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                child: Material(
                  elevation: _pageIndex == 0 ? 4 : 0,
                  borderRadius: BorderRadius.circular(64),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(64)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(64)),
                      child: NavigationBar(
                        labelTextStyle:
                            WidgetStateProperty.resolveWith<TextStyle>((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return TextStyle(
                                  color: _pageIndex == 0
                                      ? null
                                      : Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                );
                              }
                              return TextStyle(
                                color: _pageIndex == 0
                                    ? null
                                    : Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              );
                            }),
                        backgroundColor: _pageIndex == 0
                            ? Theme.of(context).colorScheme.surface
                            : Theme.of(context).colorScheme.tertiary,
                        indicatorColor: _pageIndex == 0
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context).colorScheme.primary,
                        selectedIndex: _pageIndex,
                        onDestinationSelected: (index) => setState(() {
                          _pageIndex = index;
                        }),
                        labelPadding: EdgeInsets.all(4),
                        height: 72,
                        destinations: [
                          NavigationDestination(
                            icon: Icon(
                              Icons.place_outlined,
                              color: _pageIndex == 0
                                  ? Theme.of(context).colorScheme.secondary
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            selectedIcon: Icon(
                              Icons.place_rounded,
                              color: _pageIndex == 0
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.secondary,
                            ),
                            label: AppLocalizations.of(
                              context,
                            )!.homeNavigationMapTitle,
                          ),
                          NavigationDestination(
                            icon: Icon(
                              Icons.star_border,
                              color: _pageIndex == 0
                                  ? Theme.of(
                                      context,
                                    ).textTheme.displayMedium?.color
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            selectedIcon: Icon(
                              Icons.star,
                              color: _pageIndex == 0
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.secondary,
                            ),
                            label: AppLocalizations.of(
                              context,
                            )!.homeNavigationFavouritesTitle,
                          ),
                          NavigationDestination(
                            icon: Icon(
                              Icons.settings_outlined,
                              color: _pageIndex == 0
                                  ? Theme.of(
                                      context,
                                    ).textTheme.displayMedium?.color
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            selectedIcon: Icon(
                              Icons.settings,
                              color: _pageIndex == 0
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.secondary,
                            ),
                            label: AppLocalizations.of(
                              context,
                            )!.homeNavigationSettingsTitle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
