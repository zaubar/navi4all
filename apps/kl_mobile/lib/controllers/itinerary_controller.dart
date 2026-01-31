import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:navi4all/controllers/profile_controller.dart';
import 'package:navi4all/core/theme/values.dart';
import 'package:navi4all/l10n/app_localizations.dart';
import 'package:navi4all/schemas/routing/coordinates.dart';
import 'package:navi4all/schemas/routing/itinerary.dart';
import 'package:navi4all/schemas/routing/mode.dart';
import 'package:navi4all/schemas/routing/place.dart';
import 'package:navi4all/schemas/routing/request_config.dart';
import 'package:navi4all/services/routing.dart';
import 'package:provider/provider.dart';

class ItineraryController extends ChangeNotifier {
  final RoutingService _routingService = RoutingService();

  Place? _originPlace;
  Place? _destinationPlace;

  DateTime? _time;
  bool? _isArrivalTime;
  Mode? _primaryMode;
  RoutingRequestConfig? _routingRequestConfig;

  Place? get originPlace => _originPlace;
  Place? get destinationPlace => _destinationPlace;
  DateTime? get time => _time;
  bool? get isArrivalTime => _isArrivalTime;
  Mode? get primaryMode => _primaryMode;
  RoutingRequestConfig? get routingRequestConfig => _routingRequestConfig;

  final List<ItinerarySummary> _itineraries = [];
  ItineraryControllerState _state = ItineraryControllerState.idle;

  UnmodifiableListView<ItinerarySummary> get itineraries =>
      UnmodifiableListView(_itineraries);
  ItineraryControllerState get state => _state;

  bool get hasParametersSet =>
      _originPlace != null &&
      _destinationPlace != null &&
      _primaryMode != null &&
      _routingRequestConfig != null &&
      _isArrivalTime != null;

  void setParameters({
    required BuildContext context,
    required Place originPlace,
    required Place destinationPlace,
    required Mode primaryMode,
    DateTime? time,
    bool isArrivalTime = false,
  }) {
    _originPlace = originPlace;
    _destinationPlace = destinationPlace;
    _time = time;
    _primaryMode = primaryMode;
    _routingRequestConfig = Provider.of<ProfileController>(
      context,
      listen: false,
    ).routingRequestConfig;
    _isArrivalTime = isArrivalTime;

    _refresh(context);
  }

  Future<List<ItinerarySummary>> fetchItinerariesOnce({
    required BuildContext context,
    required Place origin,
    required Place destination,
    required Mode primaryMode,
    DateTime? time,
    bool isArrivalTime = false,
  }) async {
    return await _fetchItinerarySummaries(
      context,
      origin,
      destination,
      primaryMode,
      time,
      isArrivalTime,
      Provider.of<ProfileController>(
        context,
        listen: false,
      ).routingRequestConfig,
    );
  }

  void reset(BuildContext context) {
    _originPlace = null;
    _destinationPlace = null;
    _routingRequestConfig = null;
    _time = null;
    _isArrivalTime = null;

    _refresh(context);
  }

  Future<void> _refresh(BuildContext context) async {
    _state = ItineraryControllerState.refreshing;
    _itineraries.clear();
    notifyListeners();

    // Ensure request parameters are set
    if (!hasParametersSet) {
      _state = ItineraryControllerState.idle;
      notifyListeners();
      return;
    }

    // Refresh user location if required
    if (_originPlace!.id == Navi4AllValues.userLocation) {
      Position? userLocation = await _getUserLocation(context);
      if (userLocation != null) {
        _originPlace = Place(
          id: Navi4AllValues.userLocation,
          name: AppLocalizations.of(context)!.origDestCurrentLocation,
          type: PlaceType.address,
          address: '',
          description: '',
          coordinates: Coordinates(
            lat: userLocation.latitude,
            lon: userLocation.longitude,
          ),
        );
      } else {
        reset(context);
        return;
      }
    }

    if (_destinationPlace!.id == Navi4AllValues.userLocation) {
      Position? userLocation = await _getUserLocation(context);
      if (userLocation != null) {
        _destinationPlace = Place(
          id: Navi4AllValues.userLocation,
          name: AppLocalizations.of(context)!.origDestCurrentLocation,
          type: PlaceType.address,
          address: '',
          description: '',
          coordinates: Coordinates(
            lat: userLocation.latitude,
            lon: userLocation.longitude,
          ),
        );
      } else {
        reset(context);
        return;
      }
    }

    try {
      // Fetch data and update results
      List<ItinerarySummary> results = await _fetchItinerarySummaries(
        context,
        _originPlace!,
        _destinationPlace!,
        _primaryMode!,
        _time,
        _isArrivalTime!,
        _routingRequestConfig!,
      );
      _itineraries.clear();
      _itineraries.addAll(results);
    } catch (e) {
      reset(context);
      _state = ItineraryControllerState.error;
      notifyListeners();
      return;
    }

    _state = ItineraryControllerState.idle;
    notifyListeners();
  }

  Future<Position?> _getUserLocation(BuildContext context) async {
    // Check location permission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      // User will need to enable permissions from app settings
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.userLocationDeniedSnackbarText,
          ),
        ),
      );
      return null;
    }

    // Fetch user location
    return await Geolocator.getCurrentPosition();
  }

  Future<List<ItinerarySummary>> _fetchItinerarySummaries(
    BuildContext context,
    Place origin,
    Place destination,
    Mode primaryMode,
    DateTime? time,
    bool isArrivalTime,
    RoutingRequestConfig routingRequestConfig,
  ) async {
    // Call routing service
    List<ItinerarySummary> results = (await _routingService.getItineraries(
      originLat: origin.coordinates.lat,
      originLon: origin.coordinates.lon,
      destinationLat: destination.coordinates.lat,
      destinationLon: destination.coordinates.lon,
      time: time ?? DateTime.now(),
      transportModes: primaryMode == Mode.TRANSIT
          ? routingRequestConfig.transitModes.map((e) => e.name).toList()
          : [primaryMode.name],
      timeIsArrival: isArrivalTime,
      walkingSpeed: routingRequestConfig.walkingSpeed,
      walkingAvoid: routingRequestConfig.walkingAvoid,
      bicycleSpeed: routingRequestConfig.bicycleSpeed,
      accessible: routingRequestConfig.accessible,
      guidanceLanguage: Localizations.localeOf(context).toLanguageTag(),
      summarized: true,
    )).cast<ItinerarySummary>();

    // For now, always reorder by duration ascending
    results.sort((a, b) => a.duration.compareTo(b.duration));

    return results;
  }
}

enum ItineraryControllerState { idle, refreshing, error }
