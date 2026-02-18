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
import 'package:navi4all/core/theme/colors.dart';
import 'package:navi4all/core/persistence/preference_helper.dart';
import 'package:navi4all/view/onboarding/onboarding.dart';
import 'package:navi4all/view/home/home.dart';
import 'package:navi4all/view/alt/home/home.dart' as home_alt;
import 'package:navi4all/core/theme/profile_mode.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<StatefulWidget> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    _launchHomeScreen();

    super.initState();
  }

  Future<void> _launchHomeScreen() async {
    await Future.delayed(Duration(milliseconds: 1500));

    bool isOnboardingComplete = await PreferenceHelper.isOnboardingComplete();
    if (!isOnboardingComplete) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => OnboardingScreen()),
      );
    } else {
      switch (await PreferenceHelper.getProfileMode()) {
        case ProfileMode.blind:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => home_alt.HomeScreen()),
          );
          break;
        case ProfileMode.visionImpaired:
        case ProfileMode.general:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Navi4AllColors.klRed,
    body: Center(child: Image.asset("assets/stadt_kl_white.png", width: 100)),
  );
}
