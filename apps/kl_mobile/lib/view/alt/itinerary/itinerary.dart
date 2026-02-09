import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:navi4all/controllers/itinerary_controller.dart';
import 'package:navi4all/l10n/app_localizations.dart';
import 'package:navi4all/schemas/routing/mode.dart';
import 'package:navi4all/schemas/routing/place.dart';
import 'package:navi4all/view/common/accessible_icon_button.dart';
import 'package:navi4all/view/itinerary/itinerary.dart';
import 'package:navi4all/view/common/accessible_button.dart';
import 'package:navi4all/view/itinerary/itinerary_options.dart';
import 'package:provider/provider.dart';

class ItineraryScreen extends StatefulWidget {
  final Place origin;
  final Place destination;
  final Mode primaryMode;

  const ItineraryScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.primaryMode,
  });

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  @override
  void initState() {
    super.initState();

    // Initialize itinerary controller
    Provider.of<ItineraryController>(context, listen: false).setParameters(
      context: context,
      originPlace: widget.origin,
      destinationPlace: widget.destination,
      primaryMode: widget.primaryMode,
    );
  }

  Future<void> _showItineraryOptions() async {
    final ItineraryController itineraryController =
        Provider.of<ItineraryController>(context, listen: false);

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ItineraryOptions(altMode: true)),
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
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, result) =>
        Provider.of<ItineraryController>(context, listen: false).reset(context),
    child: Scaffold(
      body: SafeArea(
        child: Semantics(
          focused: true,
          label: AppLocalizations.of(context)!.itinerariesScreenSemantic,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 12.0),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Semantics(
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
                      ),
                    ),
                    Flexible(child: OrigDestPicker(altMode: true)),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ItineraryList(
                    scrollController: ScrollController(),
                    altMode: true,
                  ),
                ),
                SizedBox(height: 16),
                AccessibleButton(
                  label: AppLocalizations.of(
                    context,
                  )!.routeOptionsRouteSettingsButton,
                  style: AccessibleButtonStyle.pink,
                  onTap: _showItineraryOptions,
                ),
                SizedBox(height: 16),
                AccessibleButton(
                  label: AppLocalizations.of(context)!.commonHomeScreenButton,
                  style: AccessibleButtonStyle.pink,
                  onTap: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
