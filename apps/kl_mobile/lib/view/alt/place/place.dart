import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:navi4all/controllers/favorites_controller.dart';
import 'package:navi4all/controllers/itinerary_controller.dart';
import 'package:navi4all/core/theme/values.dart';
import 'package:navi4all/l10n/app_localizations.dart';
import 'package:navi4all/schemas/routing/coordinates.dart';
import 'package:navi4all/schemas/routing/mode.dart';
import 'package:navi4all/schemas/routing/place.dart';
import 'package:navi4all/view/alt/itinerary/itinerary.dart';
import 'package:provider/provider.dart';
import 'package:navi4all/view/common/accessible_button.dart';

class PlaceScreen extends StatefulWidget {
  final Place place;
  const PlaceScreen({super.key, required this.place});

  @override
  State<PlaceScreen> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends State<PlaceScreen> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();

    // Initialize favorite status
    _checkIfFavorite(widget.place);
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

  Future<void> _onRouteTap(Mode primaryMode) async {
    // Build origin and destination places
    Place originPlace;
    (originPlace, _) = await _getOriginPlace(context);

    Place destinationPlace = widget.place;

    // Navigate to itinerary screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ItineraryScreen(
          origin: originPlace,
          destination: destinationPlace,
          primaryMode: primaryMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Semantics(
        focused: true,
        label: AppLocalizations.of(
          context,
        )!.placeScreenSemantic(widget.place.name, widget.place.description),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SizedBox(height: 128),
                Align(
                  alignment: Alignment.topLeft,
                  child: Semantics(
                    excludeSemantics: true,
                    child: Text(
                      widget.place.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: Semantics(
                    excludeSemantics: true,
                    child: Text(
                      widget.place.description,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                SizedBox(height: 64),
                Column(
                  children: [
                    AccessibleButton(
                      label: AppLocalizations.of(
                        context,
                      )!.addressInfoWalkingRoutesButton,
                      semanticLabel: AppLocalizations.of(
                        context,
                      )!.addressInfoWalkingRoutesButtonSemantic,
                      style: AccessibleButtonStyle.red,
                      onTap: () => _onRouteTap(Mode.WALK),
                    ),
                    const SizedBox(height: 16),
                    AccessibleButton(
                      label: AppLocalizations.of(
                        context,
                      )!.addressInfoPublicTransportRoutesButton,
                      semanticLabel: AppLocalizations.of(
                        context,
                      )!.addressInfoPublicTransportRoutesButtonSemantic,
                      style: AccessibleButtonStyle.red,
                      onTap: () => _onRouteTap(Mode.TRANSIT),
                    ),
                    const SizedBox(height: 16),
                    AccessibleButton(
                      label: !_isFavorite
                          ? AppLocalizations.of(
                              context,
                            )!.addressInfoSaveAddressButton
                          : AppLocalizations.of(
                              context,
                            )!.addressInfoRemoveAddressButton,
                      semanticLabel: !_isFavorite
                          ? AppLocalizations.of(
                              context,
                            )!.addressInfoSaveAddressButton
                          : AppLocalizations.of(
                              context,
                            )!.addressInfoRemoveAddressButton,
                      style: AccessibleButtonStyle.pink,
                      onTap: () => _toggleFavorite(widget.place),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
