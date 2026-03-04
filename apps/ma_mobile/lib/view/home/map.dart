import 'dart:async';
import 'dart:math';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import 'package:provider/provider.dart';
import 'package:smartroots/controllers/theme_controller.dart';
import 'package:smartroots/core/analytics/events.dart';
import 'package:smartroots/core/config.dart';
import 'package:smartroots/core/persistence/preference_helper.dart';
import 'package:smartroots/core/theme/base_map_style.dart';
import 'package:smartroots/core/theme/values.dart';
import 'package:smartroots/l10n/app_localizations.dart';
import 'package:smartroots/schemas/routing/place.dart';
import 'package:smartroots/services/poi_parking.dart';
import 'package:smartroots/view/common/selection_tile.dart';
import 'package:smartroots/view/common/sheet_button.dart';
import 'package:smartroots/view/parking_location/parking_location.dart';
import 'package:geolocator/geolocator.dart';

class HomeMap extends StatefulWidget {
  const HomeMap({super.key});

  @override
  State<StatefulWidget> createState() => _HomeMapState();
}

class _HomeMapState extends State<HomeMap> with WidgetsBindingObserver {
  late MapLibreMapController _mapController;
  Timer? _refreshTimer;
  bool _canInteractWithMap = false;
  List<Place> _parkingLocations = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _onStyleLoaded() async {
    // Clear existing markers and listeners
    _mapController.onFeatureTapped.clear();

    // Load custom marker icons
    String assetMarkerMiniParkingYes =
        SmartRootsValues.assetMarkerMiniParkingYesGeneral;
    _mapController.addImage(
      'assetMarkerMiniParkingYes',
      (await rootBundle.load(assetMarkerMiniParkingYes)).buffer.asUint8List(),
    );
    String assetMarkerMiniParkingNo =
        SmartRootsValues.assetMarkerMiniParkingNoGeneral;
    _mapController.addImage(
      'assetMarkerMiniParkingNo',
      (await rootBundle.load(assetMarkerMiniParkingNo)).buffer.asUint8List(),
    );
    String assetMarkerMiniParkingUnknown =
        SmartRootsValues.assetMarkerMiniParkingUnknownGeneral;
    _mapController.addImage(
      'assetMarkerMiniParkingUnknown',
      (await rootBundle.load(
        assetMarkerMiniParkingUnknown,
      )).buffer.asUint8List(),
    );

    await Future.delayed(const Duration(milliseconds: 250));
    setState(() => _canInteractWithMap = true);

    // Fetch and display parking locations
    _refreshData(isAutoRefresh: false).then((_) {
      // Pan to user location by default if location access was granted
      Geolocator.checkPermission().then((permission) {
        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever) {
          _panToUserLocation();
        }
      });
    });
  }

  Future<void> _refreshData({required bool isAutoRefresh}) async {
    // Schedule periodic data refresh
    if (_refreshTimer == null || !_refreshTimer!.isActive) {
      _refreshTimer = Timer.periodic(
        Duration(seconds: Settings.dataRefreshIntervalSeconds),
        (_) => _refreshData(isAutoRefresh: true),
      );
    }

    if (!_canInteractWithMap) {
      return;
    }

    // Fetch and display parking locations
    await _fetchParkingLocations(isAutoRefresh: isAutoRefresh);

    // Add feature tap listener
    _mapController.onFeatureTapped.clear();
    _mapController.onFeatureTapped.add(_onFeatureTapped);
  }

  Future<void> _fetchParkingLocations({required bool isAutoRefresh}) async {
    POIParkingService parkingService = POIParkingService();
    try {
      List<Place> parkingLocations;
      Map<String, dynamic> geoJson;
      (parkingLocations, geoJson) = await parkingService.getParkingLocations();
      setState(() {
        _parkingLocations = parkingLocations;
      });
      _updateMarkers(geoJson, isAutoRefresh: isAutoRefresh);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.errorUnableToFetchParkingSites,
          ),
        ),
      );
    }
  }

  Future<void> _panToUserLocation() async {
    // Check location permission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      // User will need to enable permissions from app settings
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.userLocationDeniedSnackbarText,
          ),
        ),
      );
      return;
    }

    // Fetch user location and pan map
    final latLng = await Geolocator.getCurrentPosition();
    _mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(latLng.latitude, latLng.longitude),
          zoom: 14,
        ),
      ),
      duration: const Duration(seconds: 2),
    );
  }

  void _onLayersButtonPressed() {
    BaseMapStyle selectedBaseMapStyle = Provider.of<ThemeController>(
      context,
      listen: false,
    ).baseMapStyle;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => Dialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            child: Semantics(
              label: AppLocalizations.of(context)!.homeChangeBaseMapTitle,
              focused: true,
              child: OrientationBuilder(
                builder: (context, orientation) => Container(
                  width: orientation == Orientation.portrait
                      ? double.infinity
                      : MediaQuery.of(context).size.width * 0.5,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: Semantics(
                          excludeSemantics: true,
                          child: Text(
                            AppLocalizations.of(
                              context,
                            )!.homeChangeBaseMapTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              SelectionTile(
                                title: getBaseMapStyleTitle(
                                  context,
                                  BaseMapStyle.light,
                                ),
                                isSelected:
                                    selectedBaseMapStyle == BaseMapStyle.light,
                                leadingImage:
                                    'assets/base_map_light_thumbnail.png',
                                onTap: () {
                                  _setNewBaseMapStyle(BaseMapStyle.light);
                                  Navigator.of(context).pop();
                                },
                              ),
                              SizedBox(height: 8),
                              SelectionTile(
                                title: getBaseMapStyleTitle(
                                  context,
                                  BaseMapStyle.dark,
                                ),
                                isSelected:
                                    selectedBaseMapStyle == BaseMapStyle.dark,
                                leadingImage:
                                    'assets/base_map_dark_thumbnail.png',
                                onTap: () {
                                  _setNewBaseMapStyle(BaseMapStyle.dark);
                                  Navigator.of(context).pop();
                                },
                              ),
                              SizedBox(height: 8),
                              SelectionTile(
                                title: getBaseMapStyleTitle(
                                  context,
                                  BaseMapStyle.satellite,
                                ),
                                isSelected:
                                    selectedBaseMapStyle ==
                                    BaseMapStyle.satellite,
                                leadingImage:
                                    'assets/base_map_satellite_thumbnail.png',
                                onTap: () {
                                  _setNewBaseMapStyle(BaseMapStyle.satellite);
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SheetButton(
                              label: AppLocalizations.of(
                                context,
                              )!.placeScreenChangeRadiusCancel,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _setNewBaseMapStyle(BaseMapStyle baseMapStyle) async {
    await PreferenceHelper.setBaseMapStyle(baseMapStyle);
    Provider.of<ThemeController>(
      context,
      listen: false,
    ).setBaseMapStyle(baseMapStyle);

    // Analytics event
    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(
        category: EventCategory.homeMapScreen.toString(),
        action: EventAction.homeMapScreenBaseMapChanged.toString(),
        name: eventActionLabels[EventAction.homeMapScreenBaseMapChanged]!,
      ),
    );
  }

  Future<void> _onMapClicked(
    Point<double> point,
    LatLng latLng, {
    String? featureId,
    bool isCluster = false,
  }) async {
    CameraPosition? cameraPosition = _mapController.cameraPosition;
    if (cameraPosition == null) {
      return;
    }

    // If zoom level is below threshold, zoom in
    if ((cameraPosition.zoom < 15 && featureId == null) || isCluster) {
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: latLng,
            zoom: !isCluster ? 15 : _mapController.cameraPosition!.zoom + 1.5,
            tilt: cameraPosition.tilt,
            bearing: cameraPosition.bearing,
          ),
        ),
        duration: const Duration(milliseconds: 500),
      );
    } else {
      LatLngBounds visibleRegion = await _mapController.getVisibleRegion();

      // Find nearest feature ID to clicked point
      Place? selectedPlace;
      if (featureId == null) {
        double nearestDistance = double.infinity;
        for (var parkingLocation in _parkingLocations) {
          LatLng symbolLatLng = LatLng(
            parkingLocation.coordinates.lat,
            parkingLocation.coordinates.lon,
          );
          if (symbolLatLng.latitude >= visibleRegion.southwest.latitude &&
              symbolLatLng.latitude <= visibleRegion.northeast.latitude &&
              symbolLatLng.longitude >= visibleRegion.southwest.longitude &&
              symbolLatLng.longitude <= visibleRegion.northeast.longitude) {
            double distance = Geolocator.distanceBetween(
              latLng.latitude,
              latLng.longitude,
              symbolLatLng.latitude,
              symbolLatLng.longitude,
            );
            if (distance < 50.0 && distance < nearestDistance) {
              nearestDistance = distance;
              selectedPlace = parkingLocation;
            }
          }
        }
      } else {
        // Fetch selected place by feature ID, sorted by distance
        // This is necessary as feature IDs may not be unique
        List<Place> orderedParkingLocations = _parkingLocations.where((
          location,
        ) {
          return location.id == featureId;
        }).toList();
        orderedParkingLocations.sort((a, b) {
          double distanceA = Geolocator.distanceBetween(
            latLng.latitude,
            latLng.longitude,
            a.coordinates.lat,
            a.coordinates.lon,
          );
          double distanceB = Geolocator.distanceBetween(
            latLng.latitude,
            latLng.longitude,
            b.coordinates.lat,
            b.coordinates.lon,
          );
          return distanceA.compareTo(distanceB);
        });
        selectedPlace = orderedParkingLocations.isNotEmpty
            ? orderedParkingLocations.first
            : null;
      }

      if (selectedPlace != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ParkingLocationScreen(parkingLocation: selectedPlace!),
          ),
        );

        // Analytics event
        MatomoTracker.instance.trackEvent(
          eventInfo: EventInfo(
            category: EventCategory.homeMapScreen.toString(),
            action: EventAction.homeMapScreenParkingLocationMarkerClicked
                .toString(),
            name:
                eventActionLabels[EventAction
                    .homeMapScreenParkingLocationMarkerClicked]!,
          ),
        );
      }
    }
  }

  void _onFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    bool isCluster = false;
    if (layerId.contains('cluster')) {
      isCluster = true;
    }

    _onMapClicked(point, coordinates, featureId: id, isCluster: isCluster);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Cancel periodic data refresh
      _refreshTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _refreshData(isAutoRefresh: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _mapController.onFeatureTapped.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      focused: true,
      label: AppLocalizations.of(context)!.homeMapScreenSemantic,
      child: Stack(
        children: [
          Consumer<ThemeController>(
            builder: (context, themeController, _) => Semantics(
              excludeSemantics: true,
              child: MapLibreMap(
                myLocationEnabled: true,
                rotateGesturesEnabled: false,
                styleString:
                    Settings.baseMapStyleUrls[themeController.baseMapStyle]!,
                onMapCreated: (controller) => _mapController = controller,
                minMaxZoomPreference: MinMaxZoomPreference(5.0, null),
                cameraTargetBounds: CameraTargetBounds(
                  LatLngBounds(
                    southwest: LatLng(47.2701, 5.8663),
                    northeast: LatLng(55.0581, 15.0419),
                  ),
                ),
                initialCameraPosition: CameraPosition(
                  target: LatLng(49.487164933378104, 8.46624749208),
                  zoom: 13.0,
                ),
                onStyleLoadedCallback: _onStyleLoaded,
                compassViewMargins: const Point(16, 160),
                compassViewPosition: CompassViewPosition.topRight,
                attributionButtonPosition:
                    AttributionButtonPosition.bottomRight,
                attributionButtonMargins: const Point(12, 12),
                onMapClick: _onMapClicked,
                trackCameraPosition: true,
              ),
            ),
          ),
          // Fill screen with background while map is loading
          !_canInteractWithMap
              ? Container(color: Theme.of(context).colorScheme.surface)
              : SizedBox.shrink(),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 112),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      excludeSemantics: true,
                      label: AppLocalizations.of(
                        context,
                      )!.homeMapScreenLayersButtonSemantic,
                      child: FloatingActionButton(
                        shape: CircleBorder(),
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        onPressed: () => _onLayersButtonPressed(),
                        child: Icon(
                          Icons.layers,
                          color: Theme.of(
                            context,
                          ).textTheme.displayMedium!.color,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Semantics(
                      button: true,
                      excludeSemantics: true,
                      label: AppLocalizations.of(
                        context,
                      )!.homeMapScreenCurrentLocationButtonSemantic,
                      child: FloatingActionButton(
                        shape: CircleBorder(),
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        onPressed: () => _panToUserLocation(),
                        child: Icon(
                          Icons.my_location,
                          color: Theme.of(
                            context,
                          ).textTheme.displayMedium!.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateMarkers(
    Map<String, dynamic> geoJson, {
    required bool isAutoRefresh,
  }) async {
    // Remove existing parking layers and sources
    // except of static parking locations if this is an auto-refresh
    for (String layerId in (await _mapController.getLayerIds())) {
      if (layerId.startsWith('parking_')) {
        if (isAutoRefresh &&
            (layerId == 'parking_unknown_layer' ||
                layerId == 'parking_unknown_clusters' ||
                layerId == 'parking_unknown_cluster_count')) {
          continue;
        }
        await _mapController.removeLayer(layerId);
      }
    }
    for (String sourceId in (await _mapController.getSourceIds())) {
      if (sourceId.startsWith('parking_')) {
        if (isAutoRefresh && sourceId == 'parking_unknown') {
          continue;
        }
        await _mapController.removeSource(sourceId);
      }
    }

    // Separate features by availability status
    List<Map<String, dynamic>> unknownFeatures = [];
    List<Map<String, dynamic>> occupiedFeatures = [];
    List<Map<String, dynamic>> availableFeatures = [];

    for (var feature in geoJson['features']) {
      var properties = feature['properties'];
      if (properties['disabled_parking_available'] == true) {
        availableFeatures.add(feature);
      } else if (properties['has_realtime_data'] == true) {
        occupiedFeatures.add(feature);
      } else {
        unknownFeatures.add(feature);
      }
    }

    // Create separate GeoJSON for each group
    Map<String, dynamic> unknownGeoJson = {
      'type': 'FeatureCollection',
      'features': unknownFeatures,
    };
    Map<String, dynamic> occupiedGeoJson = {
      'type': 'FeatureCollection',
      'features': occupiedFeatures,
    };
    Map<String, dynamic> availableGeoJson = {
      'type': 'FeatureCollection',
      'features': availableFeatures,
    };

    // Add sources for each availability group
    // except of static parking locations if this is an auto-refresh
    if (!isAutoRefresh) {
      await _mapController.addSource(
        'parking_unknown',
        GeojsonSourceProperties(
          data: unknownGeoJson,
          cluster: true,
          clusterMaxZoom: 16,
          clusterRadius: 30,
        ),
      );
    }

    await _mapController.addSource(
      'parking_occupied',
      GeojsonSourceProperties(
        data: occupiedGeoJson,
        cluster: true,
        clusterMaxZoom: 16,
        clusterRadius: 30,
      ),
    );

    await _mapController.addSource(
      'parking_available',
      GeojsonSourceProperties(
        data: availableGeoJson,
        cluster: true,
        clusterMaxZoom: 16,
        clusterRadius: 30,
      ),
    );

    if (!isAutoRefresh) {
      // Add layer for unclustered points - Unknown (Blue)
      await _mapController.addLayer(
        'parking_unknown',
        'parking_unknown_layer',
        SymbolLayerProperties(
          iconImage: 'assetMarkerMiniParkingUnknown',
          iconSize: 0.3,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
        ),
        filter: [
          '!',
          ['has', 'point_count'],
        ],
      );

      // Add cluster circles - Unknown (Blue)
      await _mapController.addLayer(
        'parking_unknown',
        'parking_unknown_clusters',
        SymbolLayerProperties(
          iconImage: 'assetMarkerMiniParkingUnknown',
          iconSize: 0.7,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
        ),
        filter: ['has', 'point_count'],
      );

      await _mapController.addLayer(
        'parking_unknown',
        'parking_unknown_cluster_count',
        SymbolLayerProperties(
          textField: ['get', 'point_count_abbreviated'],
          textFont: ['Roboto Bold'],
          textSize: 12,
          textColor: '#FFFFFF',
          textIgnorePlacement: true,
          textAllowOverlap: true,
        ),
        filter: ['has', 'point_count'],
      );
    }

    // Add layer for unclustered points - Occupied (Red)
    await _mapController.addLayer(
      'parking_occupied',
      'parking_occupied_layer',
      SymbolLayerProperties(
        iconImage: 'assetMarkerMiniParkingNo',
        iconSize: 0.3,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
      filter: [
        '!',
        ['has', 'point_count'],
      ],
    );

    // Add cluster circles - Occupied (Red)
    await _mapController.addLayer(
      'parking_occupied',
      'parking_occupied_clusters',
      SymbolLayerProperties(
        iconImage: 'assetMarkerMiniParkingNo',
        iconSize: 0.7,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
      filter: ['has', 'point_count'],
    );

    await _mapController.addLayer(
      'parking_occupied',
      'parking_occupied_cluster_count',
      SymbolLayerProperties(
        textField: ['get', 'point_count_abbreviated'],
        textFont: ['Roboto Bold'],
        textSize: 12,
        textColor: '#FFFFFF',
        textIgnorePlacement: true,
        textAllowOverlap: true,
      ),
      filter: ['has', 'point_count'],
    );

    // Add layer for unclustered points - Available (Green)
    await _mapController.addLayer(
      'parking_available',
      'parking_available_layer',
      SymbolLayerProperties(
        iconImage: 'assetMarkerMiniParkingYes',
        iconSize: 0.3,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
      filter: [
        '!',
        ['has', 'point_count'],
      ],
    );

    // Add cluster circles - Available (Green)
    await _mapController.addLayer(
      'parking_available',
      'parking_available_clusters',
      SymbolLayerProperties(
        iconImage: 'assetMarkerMiniParkingYes',
        iconSize: 0.7,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
      filter: ['has', 'point_count'],
    );

    await _mapController.addLayer(
      'parking_available',
      'parking_available_cluster_count',
      SymbolLayerProperties(
        textField: ['get', 'point_count_abbreviated'],
        textFont: ['Roboto Bold'],
        textSize: 12,
        textColor: '#FFFFFF',
        textIgnorePlacement: true,
        textAllowOverlap: true,
      ),
      filter: ['has', 'point_count'],
    );
  }
}
