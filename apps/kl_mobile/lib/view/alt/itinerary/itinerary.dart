import 'package:flutter/material.dart';
import 'package:navi4all/controllers/itinerary_controller.dart';
import 'package:navi4all/l10n/app_localizations.dart';
import 'package:navi4all/schemas/routing/mode.dart';
import 'package:navi4all/schemas/routing/place.dart';
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
    var _ = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ItineraryOptions(altMode: true)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Semantics(
        focused: true,
        label: AppLocalizations.of(context)!.itinerariesScreenSemantic,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            children: [
              OrigDestPicker(altMode: true),
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
  );
}
