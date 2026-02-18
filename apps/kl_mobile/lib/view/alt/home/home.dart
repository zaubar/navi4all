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
import 'package:navi4all/controllers/favorites_controller.dart';
import 'package:navi4all/l10n/app_localizations.dart';
import 'package:navi4all/view/favourites/favorites.dart';
import 'package:navi4all/view/search/search.dart';
import 'package:navi4all/view/common/accessible_button.dart';
import 'package:navi4all/view/settings/settings.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Semantics(
          focused: true,
          label: AppLocalizations.of(context)!.homeScreenSemantic,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  Spacer(),
                  AccessibleButton(
                    label: AppLocalizations.of(context)!.homeSearchButton,
                    style: AccessibleButtonStyle.pink,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              const SearchScreen(altMode: true),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Consumer<FavoritesController>(
                    builder: (context, favoritesController, _) =>
                        AccessibleButton(
                          label: AppLocalizations.of(context)!.favouritesTitle,
                          style: AccessibleButtonStyle.pink,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const FavoritesScreen(altMode: true),
                              ),
                            );
                          },
                        ),
                  ),
                  const SizedBox(height: 32),
                  AccessibleButton(
                    label: AppLocalizations.of(context)!.settingsTitle,
                    style: AccessibleButtonStyle.pink,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              const SettingsScreen(altMode: true),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Spacer(),
                  Semantics(
                    excludeSemantics: true,
                    child: Image.asset("assets/stadt_kl_red.png", width: 100),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
