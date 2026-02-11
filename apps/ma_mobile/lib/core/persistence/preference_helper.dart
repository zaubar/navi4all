import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartroots/core/config.dart';
import 'package:smartroots/core/theme/base_map_style.dart';
import 'package:smartroots/schemas/routing/place.dart';

String keyOnboardingComplete = "ma_onboarding_complete";
String keyFavorites = "ma_favorites";
String keyProfileMode = "ma_profile_mode";
String keyThemeMode = "ma_theme_mode";
String keyBaseMapStyle = "ma_base_map_style";
String keyRecentSearches = "ma_recent_searches";
String keySearchRadius = "ma_search_radius";
String keyRoutingRequestConfig = "ma_routing_request_config";
String keyUserEngagementEvents = "ma_user_engagement_events";
String keyLaunchCount = "ma_launch_count";

class PreferenceHelper {
  static Future<bool> isOnboardingComplete() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getBool(keyOnboardingComplete) ?? false;
  }

  static Future<void> setOnboardingComplete(bool complete) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool(keyOnboardingComplete, complete);
  }

  static List<String> _getStoredFavorites(SharedPreferences preferences) =>
      preferences.getStringList(keyFavorites) ?? [];

  static Future<List<Place>> getFavorites() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    List<Place> favorites = [];

    for (var item in _getStoredFavorites(preferences)) {
      favorites.add(Place.fromJson(jsonDecode(item)));
    }
    return favorites;
  }

  static Future<void> addFavorite(Place place) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    List<String> favorites = _getStoredFavorites(preferences);

    favorites.add(jsonEncode(place.toJson()));

    await preferences.setStringList(keyFavorites, favorites);
  }

  static Future<void> removeFavorite(Place place) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    List<String> favorites = _getStoredFavorites(preferences);

    favorites.removeWhere((item) {
      Place storedPlace = Place.fromJson(jsonDecode(item));
      return storedPlace.id == place.id && storedPlace.type == place.type;
    });

    await preferences.setStringList(keyFavorites, favorites);
  }

  static Future<void> reorderFavorite(Place place, int newIndex) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    List<String> favorites = _getStoredFavorites(preferences);

    int currentIndex = favorites.indexWhere((item) {
      Place storedPlace = Place.fromJson(jsonDecode(item));
      return storedPlace.id == place.id && storedPlace.type == place.type;
    });

    if (currentIndex == -1) {
      return;
    }

    try {
      String favoriteItem = favorites.removeAt(currentIndex);
      favorites.insert(
        newIndex > currentIndex ? newIndex - 1 : newIndex,
        favoriteItem,
      );

      await preferences.setStringList(keyFavorites, favorites);
    } catch (e) {
      return;
    }
  }

  static Future<bool> isFavorite(Place place) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    List<String> favorites = _getStoredFavorites(preferences);

    for (var item in favorites) {
      Place storedPlace = Place.fromJson(jsonDecode(item));
      if (storedPlace.id == place.id && storedPlace.type == place.type) {
        return true;
      }
    }
    return false;
  }

  /* static Future<ProfileMode> getProfileMode() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    return ProfileMode.values.byName(
      preferences.getString(keyProfileMode) ?? ProfileMode.general.name,
    );
  }

  static Future<void> setProfileMode(ProfileMode mode) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(keyProfileMode, mode.name);
  } */

  static Future<ThemeMode> getThemeMode() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    return ThemeMode.values.byName(
      preferences.getString(keyThemeMode) ?? ThemeMode.light.name,
    );
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(keyThemeMode, mode.name);
  }

  static Future<BaseMapStyle> getBaseMapStyle() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    return BaseMapStyle.values.byName(
      preferences.getString(keyBaseMapStyle) ?? BaseMapStyle.light.name,
    );
  }

  static Future<void> setBaseMapStyle(BaseMapStyle style) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(keyBaseMapStyle, style.name);
  }

  static Future<void> addRecentSearch(Place place) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    List<String> recentSearches =
        preferences.getStringList(keyRecentSearches) ?? [];

    // Remove existing entry if it exists
    recentSearches.removeWhere((item) {
      Place existingPlace = Place.fromJson(jsonDecode(item));
      return existingPlace.id == place.id;
    });

    // Add to the beginning of the list
    recentSearches.insert(0, jsonEncode(place.toJson()));

    // Retain a limited number of recent searches
    if (recentSearches.length > Settings.numRecentSearchesRetained) {
      recentSearches = recentSearches.sublist(
        0,
        Settings.numRecentSearchesRetained,
      );
    }

    await preferences.setStringList(keyRecentSearches, recentSearches);
  }

  static Future<List<Place>> getRecentSearches() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    List<String> recentSearches =
        preferences.getStringList(keyRecentSearches) ?? [];

    return recentSearches
        .map((item) => Place.fromJson(jsonDecode(item)))
        .toList();
  }

  static Future<int> getSearchRadius() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getInt(keySearchRadius) ?? Settings.searchRadiusDefault;
  }

  static Future<void> setSearchRadius(int radius) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    preferences.setInt(keySearchRadius, radius);
  }

  /* static Future<void> setRoutingRequestConfig(
    RoutingRequestConfig config,
  ) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      keyRoutingRequestConfig,
      jsonEncode(config.toJson()),
    );
  }

  static Future<RoutingRequestConfig?> getRoutingRequestConfig() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    String? configString = preferences.getString(keyRoutingRequestConfig);

    if (configString != null) {
      return RoutingRequestConfig.fromJson(jsonDecode(configString));
    }
    return null;
  } */

  static List<String> _getStoredUserEngagementEvents(
    SharedPreferences preferences,
  ) => preferences.getStringList(keyUserEngagementEvents) ?? [];

  static Future<void> addDisplayedUserEngagementEvent(String eventId) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    List<String> events = _getStoredUserEngagementEvents(preferences);

    if (!events.contains(eventId)) {
      events.add(eventId);
      await preferences.setStringList(keyUserEngagementEvents, events);
    }
  }

  static Future<bool> isUserEngagementEventDisplayed(String eventId) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    List<String> events = _getStoredUserEngagementEvents(preferences);
    return events.contains(eventId);
  }

  static Future<int> getLaunchCount() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getInt(keyLaunchCount) ?? 0;
  }

  static Future<int> incrementLaunchCount() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final int nextCount = (preferences.getInt(keyLaunchCount) ?? 0) + 1;
    await preferences.setInt(keyLaunchCount, nextCount);
    return nextCount;
  }
}
