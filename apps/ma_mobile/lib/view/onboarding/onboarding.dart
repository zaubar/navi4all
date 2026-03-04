import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smartroots/core/persistence/preference_helper.dart';
import 'package:smartroots/core/theme/values.dart';
import 'package:smartroots/l10n/app_localizations.dart';
import 'package:smartroots/core/theme/colors.dart';
import 'package:smartroots/view/home/home.dart';
import 'package:smartroots/view/common/accessible_button.dart';
import 'package:geolocator/geolocator.dart';

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
    _SymbolInformationScreen(),
    _FavoritesInformationScreen(),
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

  Future<void> _onPageChangeButtonClick() async {
    // Run any pre-page-change logic before navigating to the next page
    await _onPageChangeInitiated();

    // Navigate to the next page or finish onboarding
    if (_pages[_currentPage] is _FinishScreen) {
      PreferenceHelper.setOnboardingComplete(true);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _onPageChangeInitiated() async {
    if (_pages[_currentPage] is _UserLocationScreen) {
      await _requestLocationPermission();
    } else if (_pages[_currentPage] is _NavigationGuidanceScreen &&
        defaultTargetPlatform == TargetPlatform.android) {
      PermissionStatus notificationStatus =
          await Permission.notification.status;
      if (notificationStatus != PermissionStatus.granted) {
        await Permission.notification.request();
      }
    }
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
    onPageChanged: (index) {
      _onPageChangeInitiated();
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
                  ? SmartRootsColors.maWhite
                  : SmartRootsColors.maBlue,
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
          onTap: _onPageChangeButtonClick,
        ),
      ),
      Image.asset("assets/smart_logo.png", width: 64),
      SizedBox(height: 32),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmartRootsColors.maBlueExtraExtraDark,
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
    return Center(
      child: SingleChildScrollView(
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
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.onboardingWelcomeSubtitle,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.onboardingWelcomeHint,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SymbolInformationScreen extends StatelessWidget {
  const _SymbolInformationScreen();

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
                AppLocalizations.of(context)!.onboardingSymbolInformationTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(
                  context,
                )!.onboardingSymbolInformationSubtitle,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 32),
              _SymbolLegendRow(
                iconColor: SmartRootsColors.maGreen,
                icon: Image.asset(
                  SmartRootsValues.assetMarkerParkingAvblYesGeneral,
                  width: 32.0,
                ),
                hint: AppLocalizations.of(
                  context,
                )!.onboardingSymbolInformationParkingAvailable,
              ),
              const SizedBox(height: 16),
              _SymbolLegendRow(
                iconColor: SmartRootsColors.maRed,
                icon: Image.asset(
                  SmartRootsValues.assetMarkerParkingAvblNoGeneral,
                  width: 32.0,
                ),
                hint: AppLocalizations.of(
                  context,
                )!.onboardingSymbolInformationParkingUnavailable,
              ),
              const SizedBox(height: 16),
              _SymbolLegendRow(
                iconColor: SmartRootsColors.maBlueExtraDark,
                icon: Image.asset(
                  SmartRootsValues.assetMarkerParkingAvblUnknownGeneral,
                  width: 32.0,
                ),
                hint: AppLocalizations.of(
                  context,
                )!.onboardingSymbolInformationParkingUnknown,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesInformationScreen extends StatelessWidget {
  const _FavoritesInformationScreen();

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
                AppLocalizations.of(
                  context,
                )!.onboardingFavoritesInformationTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(
                  context,
                )!.onboardingFavoritesInformationSubtitle,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 32),
              _SymbolLegendRow(
                iconColor: SmartRootsColors.maBlueExtraExtraDark,
                icon: Icon(Icons.star_border, color: SmartRootsColors.maWhite),
                hint: AppLocalizations.of(
                  context,
                )!.onboardingFavoritesNotFavorited,
              ),
              const SizedBox(height: 16),
              _SymbolLegendRow(
                iconColor: SmartRootsColors.maBlueExtraExtraDark,
                icon: Icon(Icons.star, color: SmartRootsColors.maWhite),
                hint: AppLocalizations.of(
                  context,
                )!.onboardingFavoritesFavorited,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SymbolLegendRow extends StatelessWidget {
  final Color iconColor;
  final Widget icon;
  final String hint;

  const _SymbolLegendRow({
    required this.iconColor,
    required this.icon,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      icon,
      const SizedBox(width: 16),
      Expanded(
        child: Text(
          hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );
}

class _UserLocationScreen extends StatelessWidget {
  const _UserLocationScreen();

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
                AppLocalizations.of(context)!.onboardingUserLocationTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.onboardingUserLocationSubtitle,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ),
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

class _FinishScreen extends StatelessWidget {
  const _FinishScreen();

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
                AppLocalizations.of(context)!.onboardingFinishTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.onboardingFinishSubtitle,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
