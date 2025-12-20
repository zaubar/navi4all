import 'package:flutter/material.dart';
import 'package:navi4all/core/persistence/preference_helper.dart';
import 'package:navi4all/core/theme/base_map_style.dart';
import 'package:navi4all/core/theme/colors.dart';
import 'package:navi4all/core/theme/profile_mode.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  BaseMapStyle _baseMapStyle = BaseMapStyle.light;
  ProfileMode _profileMode = ProfileMode.general;
  Color textColorLight = Navi4AllColors.klRed;
  Color textColorDark = Navi4AllColors.klLightRed;
  Color surfaceColorLight = Navi4AllColors.klSurfaceLight;
  Color surfaceColorDark = Navi4AllColors.klSurfaceDark;
  Color primaryColorLight = Navi4AllColors.klRed;
  Color primaryColorDark = Navi4AllColors.klLightRed;
  Color secondaryColorLight = Navi4AllColors.klPink;
  Color secondaryColorDark = Navi4AllColors.klBlack;
  Color tertiaryColorLight = Navi4AllColors.klLightRed;
  Color tertiaryColorDark = Navi4AllColors.klTertiaryDark;

  ThemeController(BuildContext context) {
    _initialize(context);
  }

  Future<void> _initialize(BuildContext context) async {
    setProfileMode(await PreferenceHelper.getProfileMode());

    Brightness platformBrightness = MediaQuery.of(context).platformBrightness;
    _themeMode = await PreferenceHelper.getThemeMode();
    if (_themeMode == ThemeMode.system) {
      _baseMapStyle = platformBrightness == Brightness.dark
          ? BaseMapStyle.dark
          : BaseMapStyle.light;
      notifyListeners();
    } else {
      _baseMapStyle = await PreferenceHelper.getBaseMapStyle();
      notifyListeners();
    }
  }

  ThemeMode get themeMode => _themeMode;
  BaseMapStyle get baseMapStyle => _baseMapStyle;
  ProfileMode get profileMode => _profileMode;

  void setBaseMapStyle(BaseMapStyle style) {
    switch (style) {
      case BaseMapStyle.light:
        _themeMode = ThemeMode.light;
        break;
      case BaseMapStyle.dark:
        _themeMode = ThemeMode.dark;
        break;
      case BaseMapStyle.satellite:
        _themeMode = ThemeMode.light;
        break;
    }

    _baseMapStyle = style;
    notifyListeners();

    PreferenceHelper.setThemeMode(_themeMode);
    PreferenceHelper.setBaseMapStyle(style);
  }

  void setProfileMode(ProfileMode mode) {
    _profileMode = mode;

    switch (mode) {
      case ProfileMode.blind:
        textColorLight = Navi4AllColors.klRed;
        textColorDark = Navi4AllColors.klLightRed;
        surfaceColorLight = Navi4AllColors.klWhite;
        surfaceColorDark = Navi4AllColors.klBlack;
        primaryColorLight = Navi4AllColors.klRed;
        primaryColorDark = Navi4AllColors.klLightRed;
        secondaryColorLight = Navi4AllColors.klPink;
        secondaryColorDark = Navi4AllColors.klBlack;
        tertiaryColorLight = Navi4AllColors.klLightRed;
        tertiaryColorDark = Navi4AllColors.klTertiaryDark;
        break;
      case ProfileMode.visionImpaired:
        textColorLight = Navi4AllColors.klBlack;
        textColorDark = Navi4AllColors.klYellow;
        surfaceColorLight = Navi4AllColors.klYellow;
        surfaceColorDark = Navi4AllColors.klBlack;
        primaryColorLight = Navi4AllColors.klYellow;
        primaryColorDark = Navi4AllColors.klBlack;
        secondaryColorLight = Navi4AllColors.klBlack;
        secondaryColorDark = Navi4AllColors.klYellow;
        tertiaryColorLight = Navi4AllColors.klBlack;
        tertiaryColorDark = Navi4AllColors.klYellow;
        break;
      case ProfileMode.general:
        textColorLight = Navi4AllColors.klRed;
        textColorDark = Navi4AllColors.klLightRed;
        surfaceColorLight = Navi4AllColors.klWhite;
        surfaceColorDark = Navi4AllColors.klBlack;
        primaryColorLight = Navi4AllColors.klRed;
        primaryColorDark = Navi4AllColors.klLightRed;
        secondaryColorLight = Navi4AllColors.klPink;
        secondaryColorDark = Navi4AllColors.klPink;
        tertiaryColorLight = Navi4AllColors.klLightRed;
        tertiaryColorDark = Navi4AllColors.klTertiaryDark;
        break;
    }

    notifyListeners();
  }
}
