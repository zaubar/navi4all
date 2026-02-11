import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartroots/controllers/favorites_controller.dart';
import 'package:smartroots/core/config.dart';
import 'package:smartroots/core/theme/colors.dart';
import 'package:smartroots/l10n/app_localizations.dart';
import 'package:smartroots/core/utils.dart';
import 'package:smartroots/schemas/routing/place.dart';
import 'package:smartroots/view/parking_location/parking_location.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<StatefulWidget> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start refresh after a delay since the controller is initialized anyway
    Future.delayed(
      Duration(seconds: Settings.dataRefreshIntervalSeconds),
      () => _refreshData(),
    );
  }

  Future<void> _refreshData() async {
    // Schedule periodic data refresh
    if (_refreshTimer == null || !_refreshTimer!.isActive) {
      _refreshTimer = Timer.periodic(
        Duration(seconds: Settings.dataRefreshIntervalSeconds),
        (_) => _refreshData(),
      );
    }

    // Refresh favorites data
    await Provider.of<FavoritesController>(context, listen: false).refresh();
  }

  void _onReorder(int oldIndex, int newIndex) {
    Provider.of<FavoritesController>(
      context,
      listen: false,
    ).reorderFavorite(oldIndex, newIndex);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Cancel periodic data refresh
      _refreshTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Semantics(
          focused: true,
          label: AppLocalizations.of(context)!.favoritesScreenSemantic(
            Provider.of<FavoritesController>(
              context,
              listen: false,
            ).favorites.length,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 96),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Semantics(
                  excludeSemantics: true,
                  child: Text(
                    AppLocalizations.of(context)!.favouritesTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Consumer<FavoritesController>(
                builder: (context, favoritesController, _) => Expanded(
                  child: favoritesController.favorites.isNotEmpty
                      ? ReorderableListView.builder(
                          padding: EdgeInsets.all(16),
                          shrinkWrap: true,
                          itemCount: favoritesController.favorites.length,
                          itemBuilder: (context, index) => _FavoritesListItem(
                            key: ValueKey(
                              '${favoritesController.favorites[index].id}_${favoritesController.favorites[index].type}',
                            ),
                            place: favoritesController.favorites[index],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ParkingLocationScreen(
                                  parkingLocation:
                                      favoritesController.favorites[index],
                                  showAlternatives: true,
                                ),
                              ),
                            ),
                          ),
                          onReorder: _onReorder,
                        )
                      : Center(
                          child: SingleChildScrollView(
                            child: Semantics(
                              excludeSemantics: true,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 72,
                                    color: SmartRootsColors.maBlue,
                                  ),
                                  SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                    ),
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.favouritesScreenPrompt,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: SmartRootsColors.maBlue,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              SizedBox(height: 96),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesListItem extends StatelessWidget {
  final Place place;
  final Function onTap;

  const _FavoritesListItem({
    super.key,
    required this.place,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onTap(),
    child: Semantics(
      excludeSemantics: true,
      button: true,
      label: AppLocalizations.of(context)!.favoritesListItemSemantic(
        place.name,
        place.description,
        TextFormatter.getOccupancyText(context, place),
      ),
      child: Column(
        children: [
          SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12),
            child: Row(
              children: [
                WidgetGenerator.getParkingPlaceIcon(place),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        place.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  width: 92,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          TextFormatter.getOccupancyText(context, place),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.0),
                Icon(
                  Icons.drag_handle,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20.0,
                ),
              ],
            ),
          ),
          SizedBox(height: 4),
          Divider(color: SmartRootsColors.maBlue, height: 0),
        ],
      ),
    ),
  );
}
