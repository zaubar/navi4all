import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:navi4all/core/config.dart';
import 'package:navi4all/schemas/routing/place.dart';
import 'package:navi4all/view/alt/place/place.dart' as alt_place;
import 'package:navi4all/view/place/place.dart';
import 'package:navi4all/view/common/accessible_button.dart';
import 'package:navi4all/view/common/accessible_icon_button.dart';
import 'package:provider/provider.dart';
import 'package:navi4all/controllers/favorites_controller.dart';
import 'package:navi4all/l10n/app_localizations.dart';

class FavoritesScreen extends StatefulWidget {
  final bool altMode;

  const FavoritesScreen({super.key, this.altMode = false});

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

    // Start periodic data refresh
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    if (_refreshTimer == null || !_refreshTimer!.isActive) {
      _refreshTimer = Timer.periodic(
        Duration(seconds: Settings.dataRefreshIntervalSeconds),
        (_) => _refreshData(),
      );
    }
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _refreshData() async {
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
      _stopRefreshTimer();
    } else if (state == AppLifecycleState.resumed) {
      // Resume periodic data refresh
      _refreshData();
      _startRefreshTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopRefreshTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16),
              !widget.altMode ? SizedBox(height: 32) : SizedBox.shrink(),
              Row(
                children: [
                  widget.altMode
                      ? Semantics(
                          sortKey: OrdinalSortKey(1),
                          child: AccessibleIconButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () {
                              Navigator.of(context).pop();
                            },
                            semanticLabel: AppLocalizations.of(
                              context,
                            )!.commonBackButtonSemantic,
                          ),
                        )
                      : SizedBox.shrink(),
                  SizedBox(width: 16),
                  Semantics(
                    excludeSemantics: true,
                    focused: true,
                    sortKey: OrdinalSortKey(0),
                    label: AppLocalizations.of(context)!
                        .favoritesScreenSemantic(
                          Provider.of<FavoritesController>(
                            context,
                            listen: false,
                          ).favorites.length,
                        ),
                    child: Text(
                      AppLocalizations.of(context)!.favouritesTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Consumer<FavoritesController>(
                builder: (context, favoritesController, _) {
                  final List<Place> favorites = favoritesController.favorites
                      .toList();

                  return Expanded(
                    child: favorites.isNotEmpty
                        ? ReorderableListView.builder(
                            padding: EdgeInsets.all(16),
                            shrinkWrap: true,
                            itemCount: favorites.length,
                            itemBuilder: (context, index) {
                              final Place place = favorites[index];

                              return _FavoritesListItem(
                                key: ValueKey('${place.id}_${place.type}'),
                                place: place,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => widget.altMode
                                        ? alt_place.PlaceScreen(place: place)
                                        : PlaceScreen(place: place),
                                  ),
                                ),
                              );
                            },
                            proxyDecorator: (child, index, animation) {
                              return Material(
                                elevation: 4.0,
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: child,
                                ),
                              );
                            },
                            onReorder: _onReorder,
                            onReorderStart: (_) {
                              HapticFeedback.lightImpact();
                              _stopRefreshTimer();
                            },
                            onReorderEnd: (_) => _startRefreshTimer(),
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
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
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 32),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  );
                },
              ),
              SizedBox(height: 96),
              widget.altMode
                  ? Align(
                      alignment: Alignment.bottomCenter,
                      child: AccessibleButton(
                        label: AppLocalizations.of(
                          context,
                        )!.commonHomeScreenButton,
                        style: AccessibleButtonStyle.pink,
                        onTap: () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst),
                      ),
                    )
                  : SizedBox.shrink(),
              widget.altMode ? SizedBox(height: 32) : SizedBox.shrink(),
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
    borderRadius: BorderRadius.circular(16),
    child: Semantics(
      label: place.name,
      excludeSemantics: true,
      button: true,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 12,
              ),
              child: Row(
                children: [
                  SizedBox(width: 4),
                  Icon(
                    Icons.place_rounded,
                    color: Theme.of(context).textTheme.displayMedium?.color,
                  ),
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
                  Icon(
                    Icons.drag_handle,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 20.0,
                  ),
                ],
              ),
            ),
            SizedBox(height: 4),
            Divider(color: Theme.of(context).colorScheme.secondary, height: 0),
          ],
        ),
      ),
    ),
  );
}
