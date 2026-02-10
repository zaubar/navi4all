import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_notification_channel/flutter_notification_channel.dart';
import 'package:flutter_notification_channel/notification_importance.dart';
import 'package:flutter_notification_channel/notification_visibility.dart';
import 'package:navi4all/controllers/profile_controller.dart';
import 'package:navi4all/l10n/app_localizations.dart';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:navi4all/core/config.dart';
import 'package:navi4all/core/processing_status.dart';
import 'package:navi4all/core/utils.dart';
import 'package:navi4all/schemas/routing/audio_stage.dart';
import 'package:navi4all/schemas/routing/coordinates.dart';
import 'package:navi4all/schemas/routing/itinerary.dart';
import 'package:navi4all/schemas/routing/leg.dart' as leg_schema;
import 'package:navi4all/schemas/routing/mode.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as maps_toolkit;
import 'package:navi4all/schemas/routing/request_config.dart';
import 'package:navi4all/services/routing.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class RoutingController extends ChangeNotifier {
  // Constants
  static const double densificationThreshold = 2.0;
  static const double clippingThreshold = 5.0;
  static const double clippingThresholdTransit = 25.0;
  static const double snappingThreshold = 15.0;
  static const double snappingThresholdTransit = 30.0;
  static const Map<Mode, double> digressionThresholds = {
    Mode.BICYCLE: 50.0,
    Mode.BUS: 100.0,
    Mode.CABLE_CAR: 100.0,
    Mode.CAR: 50.0,
    Mode.COACH: 100.0,
    Mode.FERRY: 100.0,
    Mode.FUNICULAR: 100.0,
    Mode.GONDOLA: 100.0,
    Mode.RAIL: 100.0,
    Mode.SUBWAY: 100.0,
    Mode.TRAM: 100.0,
    Mode.TRANSIT: 100.0,
    Mode.WALK: 20.0,
    Mode.TROLLEYBUS: 100.0,
    Mode.MONORAIL: 100.0,
  };

  final RoutingService _routingService = RoutingService();

  // State tracking
  RoutingControllerState _state = RoutingControllerState.uninitialized;
  RoutingControllerState get state => _state;
  NavigationStatus _navigationStatus = NavigationStatus.idle;
  NavigationStatus get navigationStatus => _navigationStatus;
  AudioStatus _audioStatus = AudioStatus.unmuted;
  AudioStatus get audioStatus => _audioStatus;

  // Navigation tracking
  final LinkedHashMap<
    leg_schema.LegDetailed,
    LinkedHashMap<leg_schema.Step, List<maps_toolkit.LatLng>>
  >
  _actionTrail = LinkedHashMap();
  LinkedHashMap<
    leg_schema.LegDetailed,
    LinkedHashMap<leg_schema.Step, List<maps_toolkit.LatLng>>
  >
  get actionTrail => _actionTrail;
  StreamSubscription<Position>? _positionSubscription;
  leg_schema.LegDetailed? _activeLeg;
  leg_schema.LegDetailed? get activeLeg => _activeLeg;
  leg_schema.Step? _activeStep;
  leg_schema.Step? get activeStep => _activeStep;
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;
  bool _isCurrentPositionSnapped = false;
  bool get isCurrentPositionSnapped => _isCurrentPositionSnapped;

  DateTime? lastVibrate;
  double accuracyFactor = 1.0;

  void setParameters({required ItineraryDetails itineraryDetails}) {
    _reset();

    _buildActionTrail(itineraryDetails);
    _state = RoutingControllerState.initialized;
    notifyListeners();
  }

  void startNavigation(BuildContext context) {
    _state = RoutingControllerState.navigating;
    _navigationStatus = NavigationStatus.navigating;
    _subscribeToLocationStream(context);
    notifyListeners();
  }

  void pauseNavigation() {
    _navigationStatus = NavigationStatus.paused;
    _unsubscribeFromLocationStream();
    notifyListeners();
  }

  void resumeNavigation(BuildContext context) {
    _navigationStatus = NavigationStatus.navigating;
    _subscribeToLocationStream(context);
    notifyListeners();
  }

  void stopNavigation() {
    _reset();
    notifyListeners();
  }

  void muteAudio() {
    _audioStatus = AudioStatus.muted;
    notifyListeners();
  }

  void unmuteAudio() {
    _audioStatus = AudioStatus.unmuted;
    notifyListeners();
  }

  void _buildActionTrail(ItineraryDetails itineraryDetails) {
    // Iterate over legs in itinerary
    for (leg_schema.LegDetailed leg in itineraryDetails.legs) {
      // Fetch leg geometry
      List<maps_toolkit.LatLng> legCoordinates =
          maps_toolkit.PolygonUtil.decode(leg.geometry);

      // Densify leg geometry using interpolation
      List<maps_toolkit.LatLng> densifiedLegCoordinates = [];
      for (int i = 0; i < legCoordinates.length - 1; i++) {
        maps_toolkit.LatLng start = legCoordinates[i];
        maps_toolkit.LatLng end = legCoordinates[i + 1];
        densifiedLegCoordinates.add(start);
        num distance = maps_toolkit.SphericalUtil.computeDistanceBetween(
          start,
          end,
        );
        if (distance > densificationThreshold) {
          int numIntermediatePoints = (distance / densificationThreshold)
              .floor();
          for (int j = 1; j <= numIntermediatePoints; j++) {
            double fraction = j / (numIntermediatePoints + 1);
            maps_toolkit.LatLng intermediatePoint =
                maps_toolkit.SphericalUtil.interpolate(start, end, fraction);
            densifiedLegCoordinates.add(intermediatePoint);
          }
        }
      }
      legCoordinates = densifiedLegCoordinates;

      // Build step map for this leg
      final LinkedHashMap<leg_schema.Step, List<maps_toolkit.LatLng>> stepMap =
          LinkedHashMap();
      for (int i = 0; i < leg.steps.length; i++) {
        leg_schema.Step step = leg.steps[i];

        // Differentiate between linear and positional steps
        if (step.relativeDirection == RelativeDirection.TRANSIT_TRANSFER ||
            step.relativeDirection == RelativeDirection.TRANSIT_BOARD ||
            step.relativeDirection == RelativeDirection.TRANSIT_ALIGHT ||
            step.relativeDirection == RelativeDirection.ARRIVE) {
          // This is a positional step
          // Use step coordinates for action trail
          stepMap[step] = [maps_toolkit.LatLng(step.lat, step.lon)];

          continue;
        }

        // This is a linear step
        // Clip densified leg coordinates to this step
        maps_toolkit.LatLng stepStart = maps_toolkit.LatLng(step.lat, step.lon);
        int? stepStartIndex = GeographyUtils.getLocationIndexOnPath(
          stepStart,
          legCoordinates,
          step.relativeDirection != RelativeDirection.TRANSIT_RIDE
              ? clippingThreshold
              : clippingThresholdTransit,
        );
        maps_toolkit.LatLng stepEnd = (i < leg.steps.length - 1)
            ? maps_toolkit.LatLng(leg.steps[i + 1].lat, leg.steps[i + 1].lon)
            : maps_toolkit.LatLng(
                legCoordinates.last.latitude,
                legCoordinates.last.longitude,
              );
        int? stepEndIndex = GeographyUtils.getLocationIndexOnPath(
          stepEnd,
          legCoordinates,
          step.relativeDirection != RelativeDirection.TRANSIT_RIDE
              ? clippingThreshold
              : clippingThresholdTransit,
        );

        // Validate indices
        if ((stepStartIndex == null ||
            stepEndIndex == null ||
            stepEndIndex < stepStartIndex)) {
          _flagError();
          return;
        }

        stepMap[step] = legCoordinates.sublist(
          stepStartIndex,
          stepEndIndex + 1,
        );
      }

      _actionTrail[leg] = stepMap;
    }
  }

  Future<void> _validateLocationServices(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _flagError();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _flagError();
        return;
      }
    }

    LocationAccuracyStatus accuracyStatus =
        await Geolocator.getLocationAccuracy();
    if (accuracyStatus != LocationAccuracyStatus.precise) {
      _flagError();
      return;
    }

    PermissionStatus notificationStatus = await Permission.notification.status;
    if (notificationStatus != PermissionStatus.granted) {
      await Permission.notification.request();
    }

    await FlutterNotificationChannel().registerNotificationChannel(
      description: 'Schritt-für-Schritt Navigation im Hintergrund.',
      id: 'geolocator_channel_01',
      importance: NotificationImportance.IMPORTANCE_HIGH,
      name: AppLocalizations.of(context)!.routingScreenNotificationChannel,
      visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      allowBubbles: true,
      enableVibration: true,
      enableSound: false,
      showBadge: false,
    );
  }

  void _flagError() {
    _state = RoutingControllerState.error;
    _navigationStatus = NavigationStatus.idle;
    _unsubscribeFromLocationStream();
    notifyListeners();
  }

  void _reset() {
    // Reset state tracking
    _state = RoutingControllerState.uninitialized;
    _navigationStatus = NavigationStatus.idle;
    _audioStatus = AudioStatus.unmuted;

    // Reset navigation tracking
    _unsubscribeFromLocationStream();
    _actionTrail.clear();
    _activeLeg = null;
    _activeStep = null;
    _currentPosition = null;
    _isCurrentPositionSnapped = false;
  }

  Future<void> _subscribeToLocationStream(BuildContext context) async {
    // Ensure location services are available
    await _validateLocationServices(context);

    WakelockPlus.enable();

    // Initialize location settings based on platform
    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
    );
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        intervalDuration: const Duration(seconds: 1),
        distanceFilter: 1,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: AppLocalizations.of(context)!.appTitle,
          notificationText: AppLocalizations.of(
            context,
          )!.routingScreenNotificationDescription,
          notificationChannelName: AppLocalizations.of(
            context,
          )!.routingScreenNotificationChannel,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.otherNavigation,
      );
    }

    // Register location stream subscription
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) => _onLocationChanged(context, position));
  }

  void _unsubscribeFromLocationStream() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    WakelockPlus.disable();
  }

  void _onLocationChanged(BuildContext context, Position position) {
    _currentPosition = position;

    if (_state != RoutingControllerState.navigating) {
      return;
    }

    // Dynamically scale the snapping threshold based on position accuracy
    accuracyFactor = max(1.0, position.accuracy / 10.0);

    // Perform leg and step tracking
    for (leg_schema.LegDetailed leg in _actionTrail.keys) {
      // Ensure leg is active or immediately after active leg
      if (_activeLeg != null) {
        int legIndex = _actionTrail.keys.toList().indexOf(leg);
        int activeLegIndex = _actionTrail.keys.toList().indexOf(_activeLeg!);
        if (legIndex < activeLegIndex || legIndex > (activeLegIndex + 1)) {
          continue;
        }
      }

      for (leg_schema.Step step in _actionTrail[leg]!.keys) {
        // If step tracking was already active, limit checks to a small window
        int stepIndex = _actionTrail[leg]!.keys.toList().indexOf(step);
        if (activeStep != null) {
          if (_activeLeg == leg) {
            // Checking the current active leg
            int activeStepIndex = _actionTrail[leg]!.keys.toList().indexOf(
              _activeStep!,
            );
            if (stepIndex < (activeStepIndex - 1) ||
                stepIndex > (activeStepIndex + 3)) {
              continue;
            }
          } else {
            // Checking a leg not currently active
            if (stepIndex > 0) {
              // Only the first step of an inactive leg should be checked
              continue;
            }
          }
        }

        List<maps_toolkit.LatLng> stepCoordinates = _actionTrail[leg]![step]!;

        // Differentiate between linear and positional steps
        if (step.relativeDirection == RelativeDirection.TRANSIT_TRANSFER ||
            step.relativeDirection == RelativeDirection.TRANSIT_BOARD ||
            step.relativeDirection == RelativeDirection.TRANSIT_ALIGHT ||
            step.relativeDirection == RelativeDirection.ARRIVE) {
          // This is a positional step
          num distance = maps_toolkit.SphericalUtil.computeDistanceBetween(
            maps_toolkit.LatLng(position.latitude, position.longitude),
            maps_toolkit.LatLng(step.lat, step.lon),
          );
          if (distance <=
              (step.relativeDirection != RelativeDirection.TRANSIT_BOARD &&
                      step.relativeDirection != RelativeDirection.TRANSIT_ALIGHT
                  ? (snappingThreshold * accuracyFactor)
                  : (snappingThresholdTransit * accuracyFactor))) {
            _activeLeg = leg;
            _activeStep = step;
            break;
          }

          continue;
        }

        // This is a linear step
        int? indexOnPath = GeographyUtils.getLocationIndexOnPath(
          maps_toolkit.LatLng(position.latitude, position.longitude),
          stepCoordinates,
          step.relativeDirection != RelativeDirection.TRANSIT_RIDE
              ? snappingThreshold * accuracyFactor
              : snappingThresholdTransit * accuracyFactor,
        );
        if (indexOnPath != null && indexOnPath < stepCoordinates.length - 1) {
          _activeLeg = leg;
          _activeStep = step;
          break;
        }
      }
    }

    // Perform snapping to step for non-positional legs
    _isCurrentPositionSnapped = false;
    Position? snappedPosition = _attemptSnapToStep(position, accuracyFactor);
    if (snappedPosition != null) {
      _isCurrentPositionSnapped = true;
      _currentPosition = snappedPosition;

      // Haptic feedback to indicate user is on path
      if (lastVibrate == null ||
          lastVibrate!.difference(position.timestamp).inSeconds.abs() >= 5) {
        lastVibrate = position.timestamp;
        Vibration.hasVibrator().then((_) => Vibration.vibrate(duration: 100));
      }
    }

    // Check if user is digressing
    if (_checkDigressing(position)) {
      // Attempt to fetch alternative route
      if (_activeLeg!.mode == Mode.WALK ||
          _activeLeg!.mode == Mode.BICYCLE ||
          _activeLeg!.mode == Mode.CAR) {
        _state = RoutingControllerState.rerouting;

        // Compute alternative walking route from current position to end of
        // last step in active leg
        maps_toolkit.LatLng origin = maps_toolkit.LatLng(
          position.latitude,
          position.longitude,
        );
        maps_toolkit.LatLng destination =
            _actionTrail[_activeLeg!]![_actionTrail[_activeLeg!]!.keys.last]!
                .last;

        _fetchAlternative(
          context,
          origin,
          destination,
          Provider.of<ProfileController>(
            context,
            listen: false,
          ).routingRequestConfig,
        ).then(
          (alternativeItinerary) {
            if (alternativeItinerary != null) {
              // Replace leg in original itinerary with alternative leg
              // appending any additional legs and rebuild action trail
              List<leg_schema.LegDetailed> updatedLegs = _actionTrail.keys
                  .toList();
              int activeLegIndex = updatedLegs.indexOf(_activeLeg!);
              updatedLegs.removeAt(activeLegIndex);
              updatedLegs.insertAll(activeLegIndex, alternativeItinerary.legs);

              // Modify the final step of all pre-transit legs to indicate a transfer
              for (int i = 0; i < updatedLegs.length - 1; i++) {
                leg_schema.LegDetailed leg = updatedLegs[i];
                leg_schema.LegDetailed nextLeg = updatedLegs[i + 1];

                if (nextLeg.mode != Mode.WALK &&
                    nextLeg.mode != Mode.BICYCLE &&
                    nextLeg.mode != Mode.CAR) {
                  if (leg.steps.last.relativeDirection ==
                      RelativeDirection.ARRIVE) {
                    List<leg_schema.Step> updatedSteps = List.from(leg.steps);
                    leg_schema.Step finalStep = updatedSteps.removeLast();
                    finalStep = finalStep.copyWith(
                      relativeDirection: RelativeDirection.TRANSIT_TRANSFER,
                      streetName: nextLeg.steps.first.streetName,
                      bogusName: false,
                      voiceInstruction: null,
                      textInstruction: null,
                    );
                    updatedSteps.add(finalStep);
                    updatedLegs[i] = leg.copyWith(steps: updatedSteps);
                  }
                }
              }

              int updatedItineraryDuration = updatedLegs
                  .map((leg) => leg.duration)
                  .reduce((a, b) => a + b);
              ItineraryDetails updatedItinerary = ItineraryDetails(
                itineraryId: Uuid().v4(),
                duration: updatedItineraryDuration,
                startTime: DateTime.now(),
                endTime: DateTime.now().add(
                  Duration(seconds: updatedItineraryDuration),
                ),
                origin: Coordinates(
                  lat: updatedLegs.first.steps.first.lat,
                  lon: updatedLegs.first.steps.first.lon,
                ),
                destination: Coordinates(
                  lat: updatedLegs.last.steps.last.lat,
                  lon: updatedLegs.last.steps.last.lon,
                ),
                legs: updatedLegs,
              );
              _activeLeg = null;
              _activeStep = null;
              _isCurrentPositionSnapped = false;
              _actionTrail.clear();
              _buildActionTrail(updatedItinerary);

              _state = RoutingControllerState.navigating;
              notifyListeners();

              // Haptic feedback to indicate resolved rerouting
              Vibration.hasVibrator().then(
                (_) => Vibration.vibrate(pattern: [1000, 500, 1000, 500]),
              );
            } else {
              _state = RoutingControllerState.digressing;
              notifyListeners();

              // Haptic feedback to indicate unresolved rerouting
              Vibration.hasVibrator().then(
                (_) => Vibration.vibrate(
                  pattern: [1000, 500, 1000, 500, 1000, 500],
                ),
              );
            }
          },
          onError: (_) {
            _state = RoutingControllerState.digressing;
            notifyListeners();

            // Haptic feedback to indicate unresolved rerouting
            Vibration.hasVibrator().then(
              (_) =>
                  Vibration.vibrate(pattern: [1000, 500, 1000, 500, 1000, 500]),
            );
          },
        );
      } else {
        _state = RoutingControllerState.digressing;

        // Haptic feedback to indicate unresolved rerouting
        Vibration.hasVibrator().then(
          (_) => Vibration.vibrate(pattern: [1000, 500, 1000, 500, 1000, 500]),
        );
      }
    } else {
      _state = RoutingControllerState.navigating;
    }

    // Check if user has arrived
    if (_checkArrived(position)) {
      _activeLeg = _actionTrail.keys.last;
      _activeStep = _actionTrail[_activeLeg!]!.keys.last;
      _state = RoutingControllerState.arrived;
      _navigationStatus = NavigationStatus.arrived;
      _unsubscribeFromLocationStream();

      // Haptic feedback to indicate arrival
      Vibration.hasVibrator().then((_) => Vibration.vibrate(duration: 1000));
    }

    notifyListeners();
  }

  Position? _attemptSnapToStep(Position position, double accuracyFactor) {
    // Ensure an active leg exists
    if (_activeLeg == null || _activeStep == null) {
      return null;
    }

    // Only linear steps can be snapped
    if (_activeStep!.relativeDirection == RelativeDirection.TRANSIT_TRANSFER ||
        _activeStep!.relativeDirection == RelativeDirection.TRANSIT_BOARD ||
        _activeStep!.relativeDirection == RelativeDirection.TRANSIT_ALIGHT ||
        _activeStep!.relativeDirection == RelativeDirection.ARRIVE) {
      return null;
    }

    List<maps_toolkit.LatLng> stepPoints =
        _actionTrail[_activeLeg!]![_activeStep!]!;

    // Fetch index of position on active step
    int? positionIndex = GeographyUtils.getLocationIndexOnPath(
      maps_toolkit.LatLng(position.latitude, position.longitude),
      stepPoints,
      _activeStep!.relativeDirection != RelativeDirection.TRANSIT_RIDE
          ? snappingThreshold * accuracyFactor
          : snappingThresholdTransit * accuracyFactor,
    );

    if (positionIndex != null) {
      maps_toolkit.LatLng snappedPoint = stepPoints[positionIndex];
      maps_toolkit.LatLng nextPoint = stepPoints[positionIndex + 1];

      // Compute bearing, then normalise between 0-360 degrees
      num bearing = maps_toolkit.SphericalUtil.computeHeading(
        snappedPoint,
        nextPoint,
      );
      bearing = (bearing + 360) % 360;

      return Position(
        latitude: snappedPoint.latitude,
        longitude: snappedPoint.longitude,
        timestamp: position.timestamp,
        accuracy: position.accuracy,
        altitude: position.altitude,
        altitudeAccuracy: position.altitudeAccuracy,
        heading: bearing.toDouble(),
        headingAccuracy: position.headingAccuracy,
        speed: position.speed,
        speedAccuracy: position.speedAccuracy,
      );
    }
    return null;
  }

  bool _checkDigressing(Position currentPosition) {
    // User may digress only if current position is not snapped,
    // an active leg exists, and any active step is not a linear transit step
    if (_isCurrentPositionSnapped ||
        _activeLeg == null ||
        _activeStep == null ||
        (_activeStep != null &&
            _activeStep!.relativeDirection == RelativeDirection.TRANSIT_RIDE)) {
      return false;
    }

    // Index of position on active leg
    int? positionIndex = GeographyUtils.getLocationIndexOnPath(
      maps_toolkit.LatLng(currentPosition.latitude, currentPosition.longitude),
      _actionTrail[_activeLeg!]![_activeStep!]!,
      digressionThresholds[_activeLeg!.mode]! * accuracyFactor,
    );

    // If index is unavailable, user is digressing
    return positionIndex == null;
  }

  bool _checkArrived(Position currentPosition) {
    leg_schema.LegDetailed finalLeg = _actionTrail.keys
        .toList()[_actionTrail.keys.length - 1];
    leg_schema.Step finalStep = finalLeg.steps[finalLeg.steps.length - 1];
    maps_toolkit.LatLng finalCoordinates =
        _actionTrail[finalLeg]![finalStep]!.last;

    // Check if current position is within a certain threshold of destination
    if (maps_toolkit.SphericalUtil.computeDistanceBetween(
          maps_toolkit.LatLng(
            currentPosition.latitude,
            currentPosition.longitude,
          ),
          finalCoordinates,
        ) <=
        snappingThreshold * accuracyFactor) {
      return true;
    }

    return false;
  }

  Future<ItineraryDetails?> _fetchAlternative(
    BuildContext context,
    maps_toolkit.LatLng origin,
    maps_toolkit.LatLng destination,
    RoutingRequestConfig routingRequestConfig,
  ) async {
    // Call routing service
    List<ItineraryDetails> results = (await _routingService
        .getItinerariesDetailed(
          originLat: origin.latitude,
          originLon: origin.longitude,
          destinationLat: destination.latitude,
          destinationLon: destination.longitude,
          time: DateTime.now(),
          transportModes: [Mode.WALK.name],
          walkingSpeed: routingRequestConfig.walkingSpeed,
          walkingAvoid: routingRequestConfig.walkingAvoid,
          bicycleSpeed: routingRequestConfig.bicycleSpeed,
          accessible: routingRequestConfig.accessible,
          guidanceLanguage: Localizations.localeOf(context).toLanguageTag(),
        ));

    if (results.isEmpty) {
      return null;
    }
    return results.first;
  }
}

enum RoutingControllerState {
  uninitialized,
  initialized,
  error,
  navigating,
  rerouting,
  digressing,
  arrived,
}

class CurrentPositionController extends ChangeNotifier {
  late RoutingController _routingController;

  NavigationStatus? _navigationStatus;

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  bool _isCurrentPositionSnapped = false;
  bool get isCurrentPositionSnapped => _isCurrentPositionSnapped;

  CurrentPositionController(RoutingController routingController) {
    _routingController = routingController;
    _routingController.addListener(_refreshCurrentPositionControllerState);
  }

  void _refreshCurrentPositionControllerState() {
    // Compare with cached state
    if (_navigationStatus == _routingController.navigationStatus &&
        _arePositionsEqual(
          _currentPosition,
          _routingController.currentPosition,
        ) &&
        _isCurrentPositionSnapped ==
            _routingController.isCurrentPositionSnapped) {
      return;
    }

    // Current position is only snapped during navigation
    if (_routingController.navigationStatus == NavigationStatus.navigating) {
      _currentPosition = _routingController.currentPosition;
      _isCurrentPositionSnapped = _routingController.isCurrentPositionSnapped;
      notifyListeners();
    } else {
      if (_navigationStatus != _routingController.navigationStatus) {
        _currentPosition = null;
        _isCurrentPositionSnapped = false;
        notifyListeners();
      }
    }

    _navigationStatus = _routingController.navigationStatus;
  }

  bool _arePositionsEqual(Position? position1, Position? position2) {
    if (position1 == null && position2 == null) {
      return true;
    }
    if (position1 == null || position2 == null) {
      return false;
    }
    return position1.latitude == position2.latitude &&
        position1.longitude == position2.longitude &&
        position1.heading == position2.heading;
  }

  @override
  void dispose() {
    _routingController.removeListener(_refreshCurrentPositionControllerState);
    super.dispose();
  }
}

class ActionTrailController extends ChangeNotifier {
  late RoutingController _routingController;

  final LinkedHashMap<
    leg_schema.LegDetailed,
    LinkedHashMap<leg_schema.Step, List<maps_toolkit.LatLng>?>
  >
  _actionTrail = LinkedHashMap();
  LinkedHashMap<
    leg_schema.LegDetailed,
    LinkedHashMap<leg_schema.Step, List<maps_toolkit.LatLng>?>
  >
  get actionTrail => _actionTrail;

  final List<MapEntry<Mode, List<maps_toolkit.LatLng>>> _actionTrailRendered =
      [];
  UnmodifiableListView<MapEntry<Mode, List<maps_toolkit.LatLng>>>
  get actionTrailRendered => UnmodifiableListView(_actionTrailRendered);

  ActionTrailController(RoutingController routingController) {
    _routingController = routingController;
    _routingController.addListener(_refreshActionTrailControllerState);
  }

  void _refreshActionTrailControllerState() {
    // Compare with cached state
    if (_areActionTrailsEqual(_actionTrail, _routingController.actionTrail)) {
      return;
    }
    _actionTrail.clear();
    _actionTrail.addAll(_routingController.actionTrail);

    // Build action trail for rendering
    _actionTrailRendered.clear();
    for (leg_schema.LegDetailed leg in _routingController.actionTrail.keys) {
      List<maps_toolkit.LatLng> legCoordinates = [];
      for (leg_schema.Step step in _routingController.actionTrail[leg]!.keys) {
        List<maps_toolkit.LatLng>? stepCoordinates =
            _routingController.actionTrail[leg]![step];
        if (stepCoordinates != null) {
          legCoordinates.addAll(stepCoordinates);
        }
      }

      // If no step-level geometry, decode leg geometry
      if (legCoordinates.isEmpty) {
        legCoordinates = maps_toolkit.PolygonUtil.decode(leg.geometry);
      }

      _actionTrailRendered.add(MapEntry(leg.mode, legCoordinates));
    }

    notifyListeners();
  }

  bool _areActionTrailsEqual(
    LinkedHashMap<
      leg_schema.LegDetailed,
      LinkedHashMap<leg_schema.Step, List<maps_toolkit.LatLng>?>
    >
    trail1,
    LinkedHashMap<
      leg_schema.LegDetailed,
      LinkedHashMap<leg_schema.Step, List<maps_toolkit.LatLng>?>
    >
    trail2,
  ) {
    if (trail1.length != trail2.length) {
      return false;
    }
    for (leg_schema.LegDetailed leg in trail1.keys) {
      if (!trail2.containsKey(leg)) {
        return false;
      }
      LinkedHashMap<leg_schema.Step, List<maps_toolkit.LatLng>?> steps1 =
          trail1[leg]!;
      LinkedHashMap<leg_schema.Step, List<maps_toolkit.LatLng>?> steps2 =
          trail2[leg]!;
      if (steps1.length != steps2.length) {
        return false;
      }
      for (leg_schema.Step step in steps1.keys) {
        if (!steps2.containsKey(step)) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  void dispose() {
    _routingController.removeListener(_refreshActionTrailControllerState);
    super.dispose();
  }
}

class NavigationStatsController extends ChangeNotifier {
  late RoutingController _routingController;

  int? _timeToArrival;
  int? get timeToArrival => _timeToArrival;
  double? _distanceToArrival;
  double? get distanceToArrival => _distanceToArrival;

  NavigationStatsController(RoutingController routingController) {
    _routingController = routingController;
    _routingController.addListener(_refreshNavigationStatsControllerState);
  }

  void _refreshNavigationStatsControllerState() {
    // Fetch action trail
    LinkedHashMap<
      leg_schema.LegDetailed,
      LinkedHashMap<leg_schema.Step, List<maps_toolkit.LatLng>?>
    >
    actionTrail = _routingController.actionTrail;
    if (actionTrail.isEmpty) {
      _timeToArrival = null;
      _distanceToArrival = null;
      notifyListeners();
      return;
    }

    // If current position is unavailable, use default stats
    if (_routingController.currentPosition == null) {
      _timeToArrival = _routingController.actionTrail.keys.fold(
        0,
        (sum, leg) => sum! + leg.duration,
      );
      _distanceToArrival = _routingController.actionTrail.keys.fold(
        0.0,
        (sum, leg) => sum! + leg.distance,
      );
      notifyListeners();
      return;
    }

    Position currentPosition = _routingController.currentPosition!;
    leg_schema.LegDetailed? activeLeg = _routingController.activeLeg;
    leg_schema.Step? activeStep = _routingController.activeStep;

    double totalRemainingDistance = 0.0; // in meters
    int totalRemainingTime = 0; // in seconds

    List<leg_schema.LegDetailed> legs = actionTrail.keys.toList();
    int activeLegIndex = activeLeg != null ? legs.indexOf(activeLeg) : 0;

    // Iterate through remaining legs starting from active leg
    for (int legIndex = activeLegIndex; legIndex < legs.length; legIndex++) {
      leg_schema.LegDetailed leg = legs[legIndex];
      LinkedHashMap<leg_schema.Step, List<maps_toolkit.LatLng>?> stepMap =
          actionTrail[leg]!;
      List<leg_schema.Step> steps = stepMap.keys.toList();

      // For the active leg, process steps starting from active step
      if (legIndex == activeLegIndex && activeStep != null) {
        int activeStepIndex = steps.indexOf(activeStep);

        for (
          int stepIndex = activeStepIndex;
          stepIndex < steps.length;
          stepIndex++
        ) {
          leg_schema.Step step = steps[stepIndex];
          List<maps_toolkit.LatLng>? stepGeometry = stepMap[step];

          // For the active step, calculate remaining distance from current position
          if (stepIndex == activeStepIndex) {
            if (stepGeometry != null && stepGeometry.isNotEmpty) {
              maps_toolkit.LatLng currentLatLng = maps_toolkit.LatLng(
                currentPosition.latitude,
                currentPosition.longitude,
              );

              // Find closest point on step geometry
              int? closestIndex = GeographyUtils.getLocationIndexOnPath(
                currentLatLng,
                stepGeometry,
                step.relativeDirection != RelativeDirection.TRANSIT_RIDE
                    ? RoutingController.snappingThreshold *
                          _routingController.accuracyFactor
                    : RoutingController.snappingThresholdTransit *
                          _routingController.accuracyFactor,
              );

              if (closestIndex != null &&
                  closestIndex < stepGeometry.length - 1) {
                // Remaining distance for this step
                for (int i = closestIndex; i < stepGeometry.length - 1; i++) {
                  totalRemainingDistance +=
                      maps_toolkit.SphericalUtil.computeDistanceBetween(
                        stepGeometry[i],
                        stepGeometry[i + 1],
                      );
                }

                // Remaining time for this step
                double stepProgress = closestIndex / (stepGeometry.length - 1);
                totalRemainingTime +=
                    ((1 - stepProgress) *
                            step.distance /
                            leg.distance *
                            leg.duration)
                        .round();
              } else {
                // Unable to snap, use full step distance
                totalRemainingDistance += step.distance;
                totalRemainingTime +=
                    (step.distance / leg.distance * leg.duration).round();
              }
            }
          } else {
            // For subsequent steps in active leg, add full distance/time
            totalRemainingDistance += step.distance;
            totalRemainingTime += (step.distance / leg.distance * leg.duration)
                .round();
          }
        }
      } else {
        // For legs after the active leg, add full distance/time
        totalRemainingDistance += leg.distance;
        totalRemainingTime += leg.duration;
      }
    }

    _timeToArrival = totalRemainingTime;
    _distanceToArrival = totalRemainingDistance;

    notifyListeners();
  }

  @override
  void dispose() {
    _routingController.removeListener(_refreshNavigationStatsControllerState);
    super.dispose();
  }
}

class NavigationInstructionsController extends ChangeNotifier {
  late RoutingController _routingController;
  RoutingController get routingController => _routingController;

  NavigationStatus? _navigationStatus;
  NavigationStatus? get navigationStatus => _navigationStatus;

  AudioStatus? _audioStatus;
  AudioStatus? get audioStatus => _audioStatus;

  Position? _currentPosition;

  leg_schema.LegDetailed? _instructionLeg;
  leg_schema.LegDetailed? get instructionLeg => _instructionLeg;
  leg_schema.Step? _instructionStep;
  leg_schema.Step? get instructionStep => _instructionStep;

  final List<MapEntry<leg_schema.LegDetailed, List<leg_schema.Step>>>
  _upcomingInstructions = [];
  UnmodifiableListView<MapEntry<leg_schema.LegDetailed, List<leg_schema.Step>>>
  get upcomingInstructions => UnmodifiableListView(_upcomingInstructions);

  NavigationInstructionsController(RoutingController routingController) {
    _routingController = routingController;
    _routingController.addListener(
      _refreshNavigationInstructionsControllerState,
    );
  }

  void _refreshNavigationInstructionsControllerState() {
    // Fetch navigation state
    _navigationStatus = _routingController.navigationStatus;
    _audioStatus = _routingController.audioStatus;
    _currentPosition = _routingController.currentPosition;
    LinkedHashMap<
      leg_schema.LegDetailed,
      LinkedHashMap<leg_schema.Step, List<maps_toolkit.LatLng>?>
    >
    actionTrail = _routingController.actionTrail;
    leg_schema.LegDetailed? activeLeg = _routingController.activeLeg;
    leg_schema.Step? activeStep = _routingController.activeStep;

    // Clear instructions
    _instructionLeg = null;
    _instructionStep = null;
    _upcomingInstructions.clear();

    // Nothing more to do if navigation state is uninitialized
    if (actionTrail.isEmpty) {
      _instructionLeg = null;
      _instructionStep = null;
      notifyListeners();
      return;
    }

    // Build upcoming instructions
    // This frames the instructions in a distance-to-upcoming-action format
    List<leg_schema.LegDetailed> legs = actionTrail.keys.toList();
    int activeLegIndex = activeLeg != null ? legs.indexOf(activeLeg) : 0;
    for (int i = activeLegIndex; i < legs.length; i++) {
      leg_schema.LegDetailed leg = legs[i];

      List<leg_schema.Step> steps = actionTrail[leg]!.keys.toList();
      int activeStepIndex = 0;
      if (i == activeLegIndex && activeStep != null) {
        int currentStepIndex = steps.indexOf(activeStep);

        // Skip to upcoming step only if active step is linear and non-transit
        if (activeStep.relativeDirection !=
                RelativeDirection.TRANSIT_TRANSFER &&
            activeStep.relativeDirection != RelativeDirection.TRANSIT_BOARD &&
            activeStep.relativeDirection != RelativeDirection.TRANSIT_ALIGHT &&
            activeStep.relativeDirection != RelativeDirection.ARRIVE) {
          double distanceFromStart = _computeDistanceFromStartOfStep(
            _currentPosition!,
            activeStep,
            actionTrail[leg]![activeStep]!,
          );
          double startThreshold =
              (activeStep.relativeDirection != RelativeDirection.TRANSIT_RIDE
                  ? RoutingController.snappingThreshold
                  : RoutingController.snappingThresholdTransit) *
              _routingController.accuracyFactor;

          if (distanceFromStart >= startThreshold) {
            activeStepIndex = currentStepIndex + 1;
          } else {
            activeStepIndex = currentStepIndex;
          }
        } else {
          activeStepIndex = currentStepIndex;
        }
      }

      // Build new upcoming steps list using distance-to-step
      List<leg_schema.Step> upcomingSteps = [];
      for (int j = activeStepIndex; j < steps.length; j++) {
        double stepDistance = 0.0;
        if (j > 0 && j == activeStepIndex) {
          stepDistance = _computeDistanceToEndOfStep(
            _currentPosition!,
            steps[j - 1],
            actionTrail[leg]![steps[j - 1]]!,
          );
        } else if (j > 0) {
          stepDistance = steps[j - 1].distance;
        }

        upcomingSteps.add(steps[j].copyWith(distance: stepDistance));
      }

      _upcomingInstructions.add(MapEntry(leg, upcomingSteps));
    }

    // Set instruction leg and step
    _instructionLeg = upcomingInstructions.isNotEmpty
        ? upcomingInstructions.first.key
        : null;
    _instructionStep =
        upcomingInstructions.isNotEmpty &&
            upcomingInstructions.first.value.isNotEmpty
        ? upcomingInstructions.first.value.first
        : null;

    notifyListeners();
  }

  double _computeDistanceToEndOfStep(
    Position currentPosition,
    leg_schema.Step step,
    List<maps_toolkit.LatLng> stepGeometry,
  ) {
    double totalDistance = 0.0;

    maps_toolkit.LatLng currentLatLng = maps_toolkit.LatLng(
      currentPosition.latitude,
      currentPosition.longitude,
    );

    // Find closest point on step geometry
    int? closestIndex = GeographyUtils.getLocationIndexOnPath(
      currentLatLng,
      stepGeometry,
      step.relativeDirection != RelativeDirection.TRANSIT_RIDE
          ? RoutingController.snappingThreshold *
                _routingController.accuracyFactor
          : RoutingController.snappingThresholdTransit *
                _routingController.accuracyFactor,
    );

    if (closestIndex != null) {
      // Remaining distance for this step
      for (int i = closestIndex; i < stepGeometry.length - 1; i++) {
        totalDistance += maps_toolkit.SphericalUtil.computeDistanceBetween(
          stepGeometry[i],
          stepGeometry[i + 1],
        );
      }
    } else {
      // Unable to snap, return full step distance
      totalDistance = step.distance;
    }

    return totalDistance;
  }

  double _computeDistanceFromStartOfStep(
    Position currentPosition,
    leg_schema.Step step,
    List<maps_toolkit.LatLng> stepGeometry,
  ) {
    maps_toolkit.LatLng currentLatLng = maps_toolkit.LatLng(
      currentPosition.latitude,
      currentPosition.longitude,
    );

    int? closestIndex = GeographyUtils.getLocationIndexOnPath(
      currentLatLng,
      stepGeometry,
      step.relativeDirection != RelativeDirection.TRANSIT_RIDE
          ? RoutingController.snappingThreshold *
                _routingController.accuracyFactor
          : RoutingController.snappingThresholdTransit *
                _routingController.accuracyFactor,
    );

    if (closestIndex == null || closestIndex <= 0) {
      return 0.0;
    }

    double distanceFromStart = 0.0;
    for (int i = 0; i < closestIndex; i++) {
      distanceFromStart += maps_toolkit.SphericalUtil.computeDistanceBetween(
        stepGeometry[i],
        stepGeometry[i + 1],
      );
    }

    return distanceFromStart;
  }

  @override
  void dispose() {
    _routingController.removeListener(
      _refreshNavigationInstructionsControllerState,
    );
    super.dispose();
  }
}

class NavigationAudioController extends ChangeNotifier {
  late NavigationInstructionsController _navigationInstructionsController;

  leg_schema.LegDetailed? _instructionLeg;
  leg_schema.LegDetailed? get instructionLeg => _instructionLeg;
  leg_schema.Step? _instructionStep;
  leg_schema.Step? get instructionStep => _instructionStep;

  AudioStatus? _audioStatus;
  AudioStatus? get audioStatus => _audioStatus;

  AudioStage _audioStage = AudioStage.newStage;
  AudioStage get audioStage => _audioStage;

  NavigationAudioController(
    NavigationInstructionsController navigationInstructionsController,
  ) {
    _navigationInstructionsController = navigationInstructionsController;
    _navigationInstructionsController.addListener(
      _refreshNavigationAudioControllerState,
    );
  }

  void _refreshNavigationAudioControllerState() {
    _audioStatus = _navigationInstructionsController.audioStatus;

    // Audio instructions only during navigation and arrival
    if (_navigationInstructionsController.navigationStatus !=
            NavigationStatus.navigating &&
        _navigationInstructionsController.navigationStatus !=
            NavigationStatus.arrived) {
      _instructionLeg = null;
      _instructionStep = null;
      _audioStage = AudioStage.newStage;
      return;
    }

    // No audio cues if navigation is underway but position is not snapped
    if (!_navigationInstructionsController
            .routingController
            .isCurrentPositionSnapped &&
        (_navigationInstructionsController.instructionStep == null ||
            _navigationInstructionsController
                    .instructionStep!
                    .relativeDirection !=
                RelativeDirection.DEPART)) {
      return;
    }

    // If no leg and step was snapped to, skip audio
    if (_navigationInstructionsController.instructionLeg == null ||
        _navigationInstructionsController.instructionStep == null) {
      return;
    }

    final leg_schema.LegDetailed? newLeg =
        _navigationInstructionsController.instructionLeg;
    final leg_schema.Step? newStep =
        _navigationInstructionsController.instructionStep;

    final bool legStepChanged =
        _instructionLeg != newLeg ||
        (_instructionStep!.lat != newStep!.lat &&
            _instructionStep!.lon != newStep.lon);

    // Determine best audio stage for distance to next instruction
    AudioStage newAudioStage = _getBestAudioStageForDistance(
      _navigationInstructionsController.instructionStep!.distance,
    );
    final bool stageChanged = newAudioStage != _audioStage;

    if (!legStepChanged && !stageChanged) {
      return;
    }

    _instructionLeg = newLeg;
    _instructionStep = newStep;
    _audioStage = newAudioStage;
    notifyListeners();
  }

  AudioStage _getBestAudioStageForDistance(double distance) {
    if (distance <= Settings.navigationAudioStages[AudioStage.near]!) {
      return AudioStage.near;
    } else if (distance <= Settings.navigationAudioStages[AudioStage.medium]!) {
      return AudioStage.medium;
    } else if (distance <= Settings.navigationAudioStages[AudioStage.far]!) {
      return AudioStage.far;
    } else {
      return AudioStage.newStage;
    }
  }

  @override
  void dispose() {
    _navigationInstructionsController.removeListener(
      _refreshNavigationAudioControllerState,
    );
    super.dispose();
  }
}

class NavigationDigressingController extends ChangeNotifier {
  late RoutingController _routingController;

  RoutingControllerState? _routingControllerState;
  RoutingControllerState? get routingControllerState => _routingControllerState;

  NavigationDigressingController(RoutingController routingController) {
    _routingController = routingController;
    _routingController.addListener(_refreshNavigationDigressingControllerState);
  }

  void _refreshNavigationDigressingControllerState() {
    // Compare with cached state
    if (_routingControllerState == _routingController.state) {
      return;
    }

    _routingControllerState = _routingController.state;
    notifyListeners();
  }

  @override
  void dispose() {
    _routingController.removeListener(
      _refreshNavigationDigressingControllerState,
    );
    super.dispose();
  }
}
