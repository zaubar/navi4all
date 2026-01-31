import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:navi4all/controllers/itinerary_controller.dart';
import 'package:navi4all/controllers/profile_controller.dart';
import 'package:navi4all/core/theme/colors.dart';
import 'package:navi4all/core/theme/icons.dart';
import 'package:navi4all/core/theme/values.dart';
import 'package:navi4all/l10n/app_localizations.dart';
import 'package:navi4all/schemas/routing/mode.dart';
import 'package:navi4all/schemas/routing/place.dart';
import 'package:navi4all/view/common/accessible_icon_button.dart';
import 'package:navi4all/view/common/sheet_button.dart';
import 'package:navi4all/view/canvas/sliding_bottom_sheet.dart';
import 'package:navi4all/view/itinerary/itinerary_options.dart';
import 'package:navi4all/view/itinerary/map.dart';
import 'package:navi4all/view/routing/routing.dart';
import 'package:navi4all/view/common/itinerary_widget.dart';
import 'package:navi4all/view/search/search.dart';
import 'package:provider/provider.dart';
import 'package:navi4all/view/alt/routing/routing.dart' as routing_alt;

class ItineraryScreen extends StatefulWidget {
  final Place origin;
  final Place destination;
  const ItineraryScreen({
    super.key,
    required this.origin,
    required this.destination,
  });

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  final Map<Mode, IconData> _modes = {
    Mode.WALK: ModeIcons.get(Mode.WALK),
    Mode.TRANSIT: ModeIcons.get(Mode.TRANSIT),
  };

  @override
  void initState() {
    super.initState();

    // Initialize itinerary controller
    Provider.of<ItineraryController>(context, listen: false).setParameters(
      context: context,
      originPlace: widget.origin,
      destinationPlace: widget.destination,
      primaryMode: _modes.keys.first,
    );
  }

  Future<void> _showJourneyTimePicker() async {
    final itineraryController = Provider.of<ItineraryController>(
      context,
      listen: false,
    );
    final DateTime currentDateTime = itineraryController.time ?? DateTime.now();

    final TimeOfDay? newJourneyTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentDateTime),
    );

    if (newJourneyTime == null || !itineraryController.hasParametersSet) {
      return;
    }

    final DateTime updatedDateTime = DateTime(
      currentDateTime.year,
      currentDateTime.month,
      currentDateTime.day,
      newJourneyTime.hour,
      newJourneyTime.minute,
    );
    itineraryController.setParameters(
      context: context,
      originPlace: itineraryController.originPlace!,
      destinationPlace: itineraryController.destinationPlace!,
      primaryMode: itineraryController.primaryMode!,
      time: updatedDateTime,
      isArrivalTime: itineraryController.isArrivalTime!,
    );
  }

  Future<void> _showItineraryOptions() async {
    final ItineraryController itineraryController =
        Provider.of<ItineraryController>(context, listen: false);

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ItineraryOptions(altMode: false)),
    );

    if (!itineraryController.hasParametersSet) {
      return;
    }

    itineraryController.setParameters(
      context: context,
      originPlace: itineraryController.originPlace!,
      destinationPlace: itineraryController.destinationPlace!,
      time: itineraryController.time,
      primaryMode: itineraryController.primaryMode!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) =>
          Provider.of<ItineraryController>(
            context,
            listen: false,
          ).reset(context),
      child: Scaffold(
        body: Stack(
          children: [
            ItineraryMap(),
            SlidingBottomSheet(
              stickyHeader: Consumer<ItineraryController>(
                builder: (context, itineraryController, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          SheetButton(
                            icon: Icons.schedule_outlined,
                            label: itineraryController.hasParametersSet
                                ? itineraryController.time != null
                                      ? AppLocalizations.of(
                                          context,
                                        )!.itineraryDepartureTime(
                                          DateFormat(
                                            DateFormat.HOUR24_MINUTE,
                                          ).format(itineraryController.time!),
                                        )
                                      : AppLocalizations.of(
                                          context,
                                        )!.itineraryDepartureNow
                                : '...',
                            onTap: _showJourneyTimePicker,
                          ),
                          Spacer(),
                          SizedBox(width: 8),
                          Consumer<ProfileController>(
                            builder: (context, profileController, _) =>
                                AccessibleIconButton(
                                  icon: Icons.tune_rounded,
                                  onTap: _showItineraryOptions,
                                  hasNotification:
                                      profileController
                                          .getAssociatedRoutingProfile() ==
                                      null,
                                ),
                          ),
                          SizedBox(width: 8),
                          AccessibleIconButton(
                            icon: Icons.close_rounded,
                            onTap: () {
                              itineraryController.reset(context);
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    ),
                    DefaultTabController(
                      length: _modes.length,
                      initialIndex: itineraryController.hasParametersSet
                          ? _modes.keys.toList().indexOf(
                              itineraryController.primaryMode!,
                            )
                          : 0,
                      child: TabBar(
                        onTap: (index) {
                          itineraryController.setParameters(
                            context: context,
                            originPlace: itineraryController.originPlace!,
                            destinationPlace:
                                itineraryController.destinationPlace!,
                            primaryMode: _modes.keys.toList()[index],
                            time: itineraryController.time,
                            isArrivalTime: itineraryController.isArrivalTime!,
                          );
                        },
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        unselectedLabelColor: Theme.of(
                          context,
                        ).textTheme.displayMedium?.color,
                        labelColor: Theme.of(
                          context,
                        ).textTheme.displayMedium?.color,
                        indicatorColor: Theme.of(
                          context,
                        ).textTheme.displayMedium?.color,
                        splashBorderRadius: BorderRadius.all(
                          Radius.circular(16.0),
                        ),
                        dividerHeight: 0.0,
                        tabs: [
                          Tab(
                            icon: Icon(
                              Icons.directions_walk_rounded,
                              color: Theme.of(
                                context,
                              ).textTheme.displayMedium?.color,
                            ),
                            text: AppLocalizations.of(
                              context,
                            )!.itineraryModeTabWalking,
                          ),
                          Tab(
                            icon: Icon(
                              Icons.directions_transit_rounded,
                              color: Theme.of(
                                context,
                              ).textTheme.displayMedium?.color,
                            ),
                            text: AppLocalizations.of(
                              context,
                            )!.itineraryModeTabPublicTransport,
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 0,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ],
                ),
              ),
              listViewBuilder: (context, controller) =>
                  ItineraryList(scrollController: controller),
              initSize: 0.4,
              maxSize: 0.75,
            ),
            SafeArea(child: OrigDestPicker(altMode: false)),
          ],
        ),
      ),
    );
  }
}

class ItineraryList extends StatefulWidget {
  final ScrollController scrollController;
  final bool altMode;

  const ItineraryList({
    super.key,
    required this.scrollController,
    this.altMode = false,
  });

  @override
  State<ItineraryList> createState() => _ItineraryListState();
}

class _ItineraryListState extends State<ItineraryList> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ItineraryController>(
      builder: (context, itineraryController, _) =>
          itineraryController.state == ItineraryControllerState.idle &&
              itineraryController.itineraries.isNotEmpty
          ? ListView.separated(
              controller: widget.scrollController,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemBuilder: (context, index) => ItineraryWidget(
                itinerary: itineraryController.itineraries[index],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) {
                        if (!widget.altMode) {
                          return RoutingScreen(
                            originPlace: itineraryController.originPlace!,
                            destinationPlace:
                                itineraryController.destinationPlace!,
                            itinerarySummary:
                                itineraryController.itineraries[index],
                          );
                        }
                        return routing_alt.RoutingScreen(
                          originPlace: itineraryController.originPlace!,
                          destinationPlace:
                              itineraryController.destinationPlace!,
                          itinerarySummary:
                              itineraryController.itineraries[index],
                        );
                      },
                    ),
                  );
                },
              ),
              separatorBuilder: (_, __) => Divider(
                height: 0,
                color: Theme.of(context).colorScheme.secondary,
              ),
              itemCount: itineraryController.itineraries.length,
            )
          : ProgressWidget(state: itineraryController.state),
    );
  }
}

class ProgressWidget extends StatelessWidget {
  final ItineraryControllerState state;

  const ProgressWidget({super.key, required this.state});

  IconData get icon {
    switch (state) {
      case ItineraryControllerState.idle:
        return Icons.error_outline;
      case ItineraryControllerState.refreshing:
        return Icons.directions_outlined;
      case ItineraryControllerState.error:
        return Icons.error_outline;
    }
  }

  String message(BuildContext context) {
    switch (state) {
      case ItineraryControllerState.idle:
        return AppLocalizations.of(context)!.navigationNoRouteFound;
      case ItineraryControllerState.refreshing:
        return AppLocalizations.of(context)!.navigationGettingDirections;
      case ItineraryControllerState.error:
        return AppLocalizations.of(context)!.navigationNoRouteFound;
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Theme.of(context).textTheme.displayMedium?.color,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            message(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

class OrigDestPicker extends StatefulWidget {
  final bool altMode;

  const OrigDestPicker({super.key, required this.altMode});

  @override
  State<StatefulWidget> createState() => _OrigDestPickerState();
}

class _OrigDestPickerState extends State<OrigDestPicker> {
  Future<void> _onOriginTap() async {
    Place? originPlace = await Navigator.of(context).push(
      MaterialPageRoute<Place>(
        builder: (context) => SearchScreen(
          isOriginPlaceSearch: true,
          isSecondarySearch: true,
          altMode: widget.altMode,
        ),
      ),
    );

    if (originPlace == null) {
      return;
    }

    final itineraryController = Provider.of<ItineraryController>(
      context,
      listen: false,
    );

    itineraryController.setParameters(
      context: context,
      originPlace: originPlace,
      destinationPlace: itineraryController.destinationPlace!,
      primaryMode: itineraryController.primaryMode!,
      time: itineraryController.time,
      isArrivalTime: itineraryController.isArrivalTime!,
    );
  }

  Future<void> _onDestinationTap() async {
    Place? destinationPlace = await Navigator.of(context).push(
      MaterialPageRoute<Place>(
        builder: (context) => SearchScreen(
          isOriginPlaceSearch: false,
          isSecondarySearch: true,
          altMode: widget.altMode,
        ),
      ),
    );

    if (destinationPlace == null) {
      return;
    }

    final itineraryController = Provider.of<ItineraryController>(
      context,
      listen: false,
    );

    itineraryController.setParameters(
      context: context,
      originPlace: itineraryController.originPlace!,
      destinationPlace: destinationPlace,
      primaryMode: itineraryController.primaryMode!,
      time: itineraryController.time,
      isArrivalTime: itineraryController.isArrivalTime!,
    );
  }

  void _swapOriginDestination() {
    final itineraryController = Provider.of<ItineraryController>(
      context,
      listen: false,
    );
    final originPlace = itineraryController.originPlace;
    final destinationPlace = itineraryController.destinationPlace;

    itineraryController.setParameters(
      context: context,
      originPlace: destinationPlace!,
      destinationPlace: originPlace!,
      primaryMode: itineraryController.primaryMode!,
      time: itineraryController.time,
      isArrivalTime: itineraryController.isArrivalTime!,
    );
  }

  @override
  Widget build(BuildContext context) => Consumer<ItineraryController>(
    builder: (context, itineraryController, _) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
      child: Material(
        elevation: 4.0,
        color: !widget.altMode
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.tertiary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: _onOriginTap,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16.0),
                      topRight: Radius.circular(16.0),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16.0),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 8.0),
                          Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Material(
                              elevation: 2.0,
                              borderRadius: BorderRadius.circular(12.0),
                              child: Container(
                                width: 20.0,
                                height: 20.0,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.displayMedium?.color,
                                  border: Border.all(
                                    color: Navi4AllColors.klWhite,
                                    width: 3.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Semantics(
                              label: itineraryController.hasParametersSet
                                  ? AppLocalizations.of(
                                      context,
                                    )!.origDestPickerOriginSemantic(
                                      itineraryController.originPlace!.id ==
                                              Navi4AllValues.userLocation
                                          ? AppLocalizations.of(
                                              context,
                                            )!.origDestCurrentLocation
                                          : itineraryController
                                                .originPlace!
                                                .name,
                                    )
                                  : '',
                              button: true,
                              excludeSemantics: true,
                              child: Text(
                                itineraryController.hasParametersSet
                                    ? itineraryController.originPlace!.id ==
                                              Navi4AllValues.userLocation
                                          ? AppLocalizations.of(
                                              context,
                                            )!.origDestCurrentLocation
                                          : itineraryController
                                                .originPlace!
                                                .name
                                    : '...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 16.0),
                              ),
                            ),
                          ),
                          SizedBox(width: 48.0, height: 48.0),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: 0,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  InkWell(
                    onTap: _onDestinationTap,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16.0),
                      bottomRight: Radius.circular(16.0),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(16.0),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 12.0),
                          Icon(
                            Icons.place_rounded,
                            color: Theme.of(
                              context,
                            ).textTheme.displayMedium?.color,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Semantics(
                              label: AppLocalizations.of(context)!
                                  .origDestPickerDestinationSemantic(
                                    itineraryController.hasParametersSet
                                        ? itineraryController
                                                      .destinationPlace!
                                                      .id ==
                                                  Navi4AllValues.userLocation
                                              ? AppLocalizations.of(
                                                  context,
                                                )!.origDestCurrentLocation
                                              : itineraryController
                                                    .destinationPlace!
                                                    .name
                                        : '',
                                  ),
                              button: true,
                              excludeSemantics: true,
                              child: Text(
                                itineraryController.hasParametersSet
                                    ? itineraryController
                                                  .destinationPlace!
                                                  .id ==
                                              Navi4AllValues.userLocation
                                          ? AppLocalizations.of(
                                              context,
                                            )!.origDestCurrentLocation
                                          : itineraryController
                                                .destinationPlace!
                                                .name
                                    : '...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16.0),
                          AccessibleIconButton(
                            icon: Icons.swap_vert_rounded,
                            semanticLabel: AppLocalizations.of(
                              context,
                            )!.origDestPickerSwapButtonSemantic,
                            onTap: _swapOriginDestination,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
