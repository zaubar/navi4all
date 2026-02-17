import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:navi4all/controllers/itinerary_controller.dart';
import 'package:navi4all/core/theme/values.dart';
import 'package:navi4all/core/utils.dart';
import 'package:navi4all/schemas/routing/coordinates.dart';
import 'package:navi4all/schemas/routing/itinerary.dart';
import 'package:navi4all/schemas/routing/mode.dart';
import 'package:navi4all/view/itinerary/itinerary.dart';
import 'package:navi4all/view/common/sliding_bottom_sheet.dart';
import 'package:navi4all/view/common/accessible_icon_button.dart';
import 'package:navi4all/view/place/map.dart';
import 'package:navi4all/view/search/search.dart';
// import 'package:matomo_tracker/matomo_tracker.dart';
import 'package:provider/provider.dart';
import 'package:navi4all/controllers/favorites_controller.dart';
// import 'package:navi4all/core/analytics/events.dart';
import 'package:navi4all/l10n/app_localizations.dart';
import 'package:navi4all/schemas/routing/place.dart';
import 'package:navi4all/view/common/sheet_button.dart';
import 'dart:core';

class PlaceScreen extends StatefulWidget {
  final Place place;
  const PlaceScreen({super.key, required this.place});

  @override
  State<StatefulWidget> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends State<PlaceScreen> {
  bool _isFavorite = false;
  ItinerarySummary? _itinerarySummary;

  @override
  void initState() {
    super.initState();

    // Initialize favorite status
    _checkIfFavorite(widget.place);

    // Initialize itinerary summary
    _initializeItinerarySummary();
  }

  Future<void> _checkIfFavorite(Place place) async {
    _isFavorite = await Provider.of<FavoritesController>(
      context,
      listen: false,
    ).checkIsFavorite(place);
    setState(() {});
  }

  Future<void> _toggleFavorite(Place place) async {
    if (_isFavorite) {
      await Provider.of<FavoritesController>(
        context,
        listen: false,
      ).removeFavorite(place);
    } else {
      await Provider.of<FavoritesController>(
        context,
        listen: false,
      ).addFavorite(place);

      // Analytics event
      /* MatomoTracker.instance.trackEvent(
        eventInfo: EventInfo(
          category: EventCategory.parkingLocationScreen.toString(),
          action: EventAction.parkingLocationScreenFavouriteAdded.toString(),
        ),
      ); */
    }
    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  Future<(Place, bool)> _getOriginPlace(BuildContext context) async {
    Position? userLocation;

    // Check location permission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      // Fetch user location (lazy)
      userLocation = await Geolocator.getLastKnownPosition();
    }

    return (
      Place(
        id: Navi4AllValues.userLocation,
        name: '',
        type: PlaceType.address,
        description: '',
        address: '',
        coordinates: Coordinates(
          lat: userLocation?.latitude ?? 0.0,
          lon: userLocation?.longitude ?? 0.0,
        ),
      ),
      userLocation != null,
    );
  }

  Future<void> _initializeItinerarySummary() async {
    // Build origin and destination places
    Place originPlace;
    bool userLocationAvailable;
    (originPlace, userLocationAvailable) = await _getOriginPlace(context);

    Place destinationPlace = widget.place;

    // Only attempt to fetch itineraries if user location is available
    if (!userLocationAvailable) {
      return;
    }

    // Fetch itineraries
    List<ItinerarySummary> itineraries =
        await Provider.of<ItineraryController>(
          context,
          listen: false,
        ).fetchItinerariesOnce(
          context: context,
          origin: originPlace,
          destination: destinationPlace,
          primaryMode: Mode.TRANSIT,
        );
    if (itineraries.isNotEmpty) {
      setState(() {
        _itinerarySummary = itineraries.first;
      });
    }
  }

  Future<void> _onRouteTap() async {
    // Build origin and destination places
    Place originPlace;
    (originPlace, _) = await _getOriginPlace(context);

    Place destinationPlace = widget.place;

    // Navigate to itinerary screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ItineraryScreen(origin: originPlace, destination: destinationPlace),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PlaceMap(place: widget.place),
          SlidingBottomSheet(
            stickyHeader: Row(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: [
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.place.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      height: 1.25,
                                    ),
                                  ),
                                  Text(
                                    widget.place.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            AccessibleIconButton(
                              icon: _isFavorite
                                  ? Icons.star
                                  : Icons.star_border,
                              onTap: () => _toggleFavorite(widget.place),
                            ),
                            SizedBox(width: 8),
                            AccessibleIconButton(
                              icon: Icons.close_rounded,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Flexible(
                              flex: 1,
                              child: SheetButton(
                                icon: Icons.directions_outlined,
                                label: AppLocalizations.of(
                                  context,
                                )!.placeScreenRouteButton,
                                onTap: _onRouteTap,
                                shrinkWrap: false,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        _itinerarySummary != null
                            ? Row(
                                children: [
                                  Icon(
                                    _itinerarySummary!.legs.length > 1
                                        ? Icons.directions_transit_outlined
                                        : Icons.directions_walk_outlined,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.displayMedium?.color,
                                  ),
                                  SizedBox(width: 8.0),
                                  Text(
                                    TextFormatter.formatDurationText(
                                      _itinerarySummary!.duration,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  SizedBox(width: 6.0),
                                  Icon(
                                    Icons.circle,
                                    size: 6,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.displayMedium?.color,
                                  ),
                                  SizedBox(width: 6.0),
                                  Text(
                                    TextFormatter.formatDistanceText(
                                      _itinerarySummary!,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              )
                            : SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            body: SizedBox.shrink(),
            initSize: 0.3,
            maxSize: 0.4,
          ),
          SafeArea(child: PlaceSearchBar(place: widget.place, altMode: false)),
        ],
      ),
    );
  }
}

class PlaceSearchBar extends StatelessWidget {
  final Place place;
  final bool altMode;

  const PlaceSearchBar({super.key, required this.place, required this.altMode});

  Future<void> _search(BuildContext context) async {
    Place? result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            SearchScreen(isSecondarySearch: true, altMode: altMode),
      ),
    );
    if (result != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => PlaceScreen(place: result)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 32, left: 16, right: 16),
          child: Semantics(
            button: true,
            excludeSemantics: true,
            label: AppLocalizations.of(context)!.placeScreenSearchBarSemantic,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                onTap: () => _search(context),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    color: !altMode
                        ? Theme.of(context).colorScheme.surface
                        : Theme.of(context).colorScheme.tertiary,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: Theme.of(context).textTheme.displayMedium?.color,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          place.name,
                          style: const TextStyle(fontSize: 16),
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
      ),
    );
  }
}
