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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:navi4all/controllers/theme_controller.dart';
import 'package:navi4all/core/persistence/preference_helper.dart';
import 'package:navi4all/l10n/app_localizations.dart';
import 'package:navi4all/core/theme/colors.dart';
import 'package:navi4all/view/alt/home/home.dart' as home_alt;
import 'package:navi4all/view/common/accessible_selector.dart';
import 'package:navi4all/view/common/accessible_button.dart';
import 'package:navi4all/view/home/home.dart';
import 'package:geolocator/geolocator.dart';
import 'package:navi4all/core/theme/profile_mode.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<StatefulWidget> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final Key _key = GlobalKey();
  final PageController _controller = PageController();
  final List<Widget> _pages = const [
    _WelcomeScreen(),
    _ProfileSelectionScreen(),
    _UserLocationScreen(),
    _NavigationGuidanceScreen(),
    _FinishScreen(),
  ];
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    if (_pages[_currentPage] is _UserLocationScreen) {
      await _requestLocationPermission();
    } else if (_pages[_currentPage] is _NavigationGuidanceScreen &&
        defaultTargetPlatform == TargetPlatform.android) {
      PermissionStatus notificationStatus =
          await Permission.notification.status;
      if (notificationStatus != PermissionStatus.granted) {
        await Permission.notification.request();
      }
    } else if (_pages[_currentPage] is _FinishScreen) {
      PreferenceHelper.setOnboardingComplete(true);
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
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  Widget get _pageViewWidget => PageView(
    key: _key,
    controller: _controller,
    physics: const NeverScrollableScrollPhysics(),
    onPageChanged: (index) {
      setState(() => _currentPage = index);
    },
    children: _pages,
  );

  Widget get _bottomWidget => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _pages.length,
          (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: index == _currentPage
                  ? Navi4AllColors.klWhite
                  : Navi4AllColors.klPink,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: AccessibleButton(
          label: _currentPage < (_pages.length - 1)
              ? AppLocalizations.of(context)!.commonContinueButtonSemantic
              : AppLocalizations.of(context)!.onboardingFinishHomeScreenButton,
          style: AccessibleButtonStyle.white,
          onTap: () => _nextPage(),
        ),
      ),
      Image.asset("assets/stadt_kl_white.png", width: 64),
      SizedBox(height: 32),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Navi4AllColors.klRed,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) => orientation == Orientation.portrait
              ? Column(
                  children: [
                    SizedBox(height: 64),
                    Expanded(child: _pageViewWidget),
                    _bottomWidget,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _pageViewWidget),
                    _bottomWidget,
                  ],
                ),
        ),
      ),
    );
  }
}

class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      focused: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.onboardingWelcomeTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.onboardingWelcomeSubtitle,
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.onboardingWelcomeHint,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSelectionScreen extends StatefulWidget {
  const _ProfileSelectionScreen();

  @override
  State<_ProfileSelectionScreen> createState() =>
      _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<_ProfileSelectionScreen> {
  int _selectedIndex = 2;

  @override
  Widget build(BuildContext context) {
    final profiles = [
      AppLocalizations.of(context)!.onboardingProfileSelectionBlindUserTitle,
      AppLocalizations.of(
        context,
      )!.onboardingProfileSelectionVisionImpairedUserTitle,
      AppLocalizations.of(context)!.onboardingProfileSelectionGeneralUserTitle,
    ];
    return Semantics(
      focused: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 32),
            Center(
              child: Text(
                AppLocalizations.of(context)!.onboardingProfileSelectionTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Column(
              children: List.generate(
                profiles.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: AccessibleSelector(
                    label: profiles[index],
                    selected: _selectedIndex == index,
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      PreferenceHelper.setProfileMode(
                        ProfileMode.values[_selectedIndex],
                      );
                      Provider.of<ThemeController>(
                        context,
                        listen: false,
                      ).setProfileMode(ProfileMode.values[_selectedIndex]);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationGuidanceScreen extends StatelessWidget {
  const _NavigationGuidanceScreen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.onboardingNavigationGuidanceTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                defaultTargetPlatform == TargetPlatform.android
                    ? AppLocalizations.of(
                        context,
                      )!.onboardingNavigationGuidanceSubtitleAndroid
                    : AppLocalizations.of(
                        context,
                      )!.onboardingNavigationGuidanceSubtitleIos,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserLocationScreen extends StatelessWidget {
  const _UserLocationScreen();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      focused: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppLocalizations.of(context)!.onboardingUserLocationTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.onboardingUserLocationSubtitle,
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishScreen extends StatelessWidget {
  const _FinishScreen();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      focused: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.onboardingFinishTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.onboardingFinishSubtitle,
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
