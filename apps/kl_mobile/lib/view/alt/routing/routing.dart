// Navi4All
// Copyright (C) Navi4All contributors
// Maintainer: Plan4Better GmbH
//
// SPDX-License-Identifier: AGPL-3.0-only
//
// Licensed under the GNU Affero General Public License, Version 3 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.gnu.org/licenses/agpl-3.0.en.html
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:navi4all/controllers/itinerary_controller.dart';
import 'package:navi4all/core/theme/icons.dart';
import 'package:navi4all/view/routing/rerouting_dialog.dart';
import 'package:navi4all/view/routing/routing.dart';
import 'package:provider/provider.dart';
import 'package:navi4all/controllers/routing_controller.dart';
import 'package:navi4all/core/theme/values.dart';
import 'package:navi4all/l10n/app_localizations.dart';
import 'package:navi4all/schemas/routing/audio_stage.dart';
import 'package:navi4all/view/common/accessible_icon_button.dart';
import 'package:navi4all/view/routing/leg_tile.dart';
import 'package:navi4all/view/common/sheet_button.dart';
import 'package:navi4all/schemas/routing/itinerary.dart';
import 'package:navi4all/core/processing_status.dart';
import 'package:navi4all/services/routing.dart';
import 'package:navi4all/schemas/routing/mode.dart';
import 'package:navi4all/schemas/routing/place.dart';
import 'package:navi4all/core/utils.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:navi4all/schemas/routing/leg.dart' as leg_schema;
import 'package:vibration/vibration.dart';

class RoutingScreen extends StatefulWidget {
  final Place originPlace;
  final Place destinationPlace;
  final ItinerarySummary itinerarySummary;

  const RoutingScreen({
    required this.originPlace,
    required this.destinationPlace,
    required this.itinerarySummary,
    super.key,
  });

  @override
  RoutingState createState() => RoutingState();
}

class RoutingState extends State<RoutingScreen> {
  late ItineraryController _itineraryController;
  late NavigationInstructionsController _navigationInstructionsController;
  late NavigationAudioController _navigationAudioController;
  late NavigationDigressingController _navigationDigressingController;
  bool disclaimerAccepted = false;
  final FlutterTts flutterTts = FlutterTts();
  ProcessingStatus _processingStatus = ProcessingStatus.idle;
  List<LegTile> _legTiles = [];

  @override
  void initState() {
    super.initState();

    _itineraryController = Provider.of<ItineraryController>(
      context,
      listen: false,
    );
    _itineraryController.addListener(_onItinerariesRefreshed);
    _navigationInstructionsController =
        Provider.of<NavigationInstructionsController>(context, listen: false);
    _navigationInstructionsController.addListener(_buildLegTiles);
    _navigationAudioController = Provider.of<NavigationAudioController>(
      context,
      listen: false,
    );
    _navigationAudioController.addListener(_triggerNavigationAudio);
    _navigationDigressingController =
        Provider.of<NavigationDigressingController>(context, listen: false);
    _navigationDigressingController.addListener(
      _watchNavigationDigressingState,
    );

    // Fetch itineraries
    _fetchItineraries();
  }

  void _showDisclaimerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    AppLocalizations.of(context)!.routingDisclaimerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      AppLocalizations.of(context)!.routingDisclaimerMessage,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: SheetButton(
                        label: AppLocalizations.of(
                          context,
                        )!.routingDisclaimerCancelButton,
                        onTap: () {
                          disclaimerAccepted = false;
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: SheetButton(
                        label: AppLocalizations.of(
                          context,
                        )!.routingDisclaimerAcceptButton,
                        onTap: () {
                          disclaimerAccepted = true;
                          _toggleNavigationState();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchItineraries() async {
    setState(() {
      _processingStatus = ProcessingStatus.processing;
    });

    // Delay allows map to initialize
    await Future.delayed(Duration(milliseconds: 500));

    // Initialise TTS
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);

    try {
      await _fetchItineraryDetails(widget.itinerarySummary.itineraryId);
    } catch (e) {
      setState(() {
        _processingStatus = ProcessingStatus.error;
      });
    }
  }

  Future<void> _fetchItineraryDetails(String itineraryId) async {
    RoutingService routingService = RoutingService();
    try {
      final itineraryDetails = await routingService.getItineraryDetails(
        itineraryId: itineraryId,
      );

      // Initialize routing controller
      Provider.of<RoutingController>(
        context,
        listen: false,
      ).setParameters(itineraryDetails: itineraryDetails);

      setState(() {
        _processingStatus = ProcessingStatus.completed;
      });
    } catch (e) {
      setState(() {
        _processingStatus = ProcessingStatus.error;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.errorUnableToFetchItineraries,
          ),
        ),
      );
    }
  }

  void _toggleNavigationState() {
    NavigationStatus navigationStatus = Provider.of<RoutingController>(
      context,
      listen: false,
    ).navigationStatus;

    switch (navigationStatus) {
      case NavigationStatus.idle:
        if (!disclaimerAccepted) {
          _showDisclaimerDialog();
          break;
        }
        Provider.of<RoutingController>(
          context,
          listen: false,
        ).startNavigation(context);
        break;
      case NavigationStatus.paused:
        Provider.of<RoutingController>(
          context,
          listen: false,
        ).resumeNavigation(context);
        break;
      case NavigationStatus.navigating:
        Provider.of<RoutingController>(
          context,
          listen: false,
        ).pauseNavigation();
        break;
      case NavigationStatus.arrived:
        Provider.of<RoutingController>(context, listen: false).stopNavigation();
        Navigator.of(context).pop();
        break;
    }
  }

  void _toggleAudioStatus() {
    AudioStatus audioStatus = Provider.of<RoutingController>(
      context,
      listen: false,
    ).audioStatus;
    if (audioStatus == AudioStatus.muted) {
      Provider.of<RoutingController>(context, listen: false).unmuteAudio();
    } else {
      Provider.of<RoutingController>(context, listen: false).muteAudio();
    }
  }

  void _watchNavigationDigressingState() {
    // Check if user is digressing
    if (_navigationDigressingController.routingControllerState ==
        RoutingControllerState.digressing) {
      // Play a sound to indicate rerouting
      flutterTts.speak(
        AppLocalizations.of(context)!.routingScreenReroutingDialogTitle,
      );

      // Show rerouting dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return ReroutingDialog(
            onCancel: () {
              Navigator.of(context).pop();
            },
            onConfirm: () {
              Navigator.of(context).pop();

              // Refresh itineraries
              if (_itineraryController.hasParametersSet) {
                _itineraryController.setParameters(
                  context: context,
                  originPlace: _itineraryController.originPlace!,
                  destinationPlace: _itineraryController.destinationPlace!,
                  primaryMode: _itineraryController.primaryMode!,
                );
              }

              Navigator.of(context).pop();
            },
          );
        },
      );
    }
  }

  Future<void> _onItinerariesRefreshed() async {
    // Confirm itinerary controller has completed refreshing
    if (_itineraryController.state != ItineraryControllerState.idle) {
      return;
    }

    // Confirm this refrsh is the result of digressing
    if (_navigationDigressingController.routingControllerState !=
        RoutingControllerState.digressing) {
      return;
    }

    // Ensure new itineraries were found
    if (_itineraryController.itineraries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.navigationNoRouteFound),
        ),
      );
      flutterTts.speak(AppLocalizations.of(context)!.navigationNoRouteFound);
      return;
    }

    // Stop navigation
    RoutingController routingController = Provider.of<RoutingController>(
      context,
      listen: false,
    );
    routingController.stopNavigation();

    // Prepare navigation with new itinerary
    await _fetchItineraryDetails(
      _itineraryController.itineraries.first.itineraryId,
    );

    // Restart navigation
    routingController.startNavigation(context);
  }

  void _buildLegTiles() {
    List<LegTile> legTiles = [];
    _navigationInstructionsController.upcomingInstructions.forEach((
      MapEntry instruction,
    ) {
      legTiles.add(
        LegTile(
          leg: instruction.key,
          activeLeg: _navigationInstructionsController.instructionLeg,
          steps: instruction.value,
          activeStep: _navigationInstructionsController.instructionStep,
          isPrimaryLeg:
              _navigationInstructionsController.upcomingInstructions.length ==
              1,
        ),
      );
    });

    setState(() {
      _legTiles = legTiles;
    });
  }

  String _getStepVoiceInstruction(leg_schema.Step step) {
    if (step.voiceInstruction != null && step.voiceInstruction!.isNotEmpty) {
      return step.voiceInstruction!;
    } else if (step.textInstruction != null &&
        step.textInstruction!.isNotEmpty) {
      return step.textInstruction!;
    } else {
      return getRelativeDirectionTextMapping(step.relativeDirection, context);
    }
  }

  Future<void> _triggerNavigationAudio() async {
    if (_navigationAudioController.audioStatus == AudioStatus.muted ||
        _navigationAudioController.instructionStep == null) {
      return;
    }

    // Make text-to-speech announcement for new active step
    String stepAnnouncement = "";
    if (_navigationAudioController.audioStage != AudioStage.near) {
      // Exclude distance for final audio stage
      if (_navigationAudioController.instructionStep!.distance >= 1000) {
        stepAnnouncement += AppLocalizations.of(context)!
            .navigationStepDistanceToActionKilometres(
              '${TextFormatter.formatKilometersDistanceFromMeters(_navigationAudioController.instructionStep!.distance)}. ',
            );
      } else {
        stepAnnouncement +=
            '${AppLocalizations.of(context)!.navigationStepDistanceToActionMetres(TextFormatter.formatMetersDistanceFromMeters(_navigationAudioController.instructionStep!.distance).toString())}. ';
      }
    } else {
      // Haptic feedback to indicate action
      Vibration.hasVibrator().then((_) => Vibration.vibrate(duration: 1000));
    }
    stepAnnouncement += _getStepVoiceInstruction(
      _navigationAudioController.instructionStep!,
    );

    flutterTts.speak(stepAnnouncement);
  }

  @override
  void dispose() {
    _itineraryController.removeListener(_onItinerariesRefreshed);
    _navigationInstructionsController.removeListener(_buildLegTiles);
    _navigationAudioController.removeListener(_triggerNavigationAudio);
    _navigationDigressingController.removeListener(
      _watchNavigationDigressingState,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        Provider.of<RoutingController>(context, listen: false).stopNavigation();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 32.0,
                ),
                child: Consumer<RoutingController>(
                  builder: (context, routingController, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: AppLocalizations.of(context)!
                            .origDestPickerDestinationSemantic(
                              widget.destinationPlace.id ==
                                      Navi4AllValues.userLocation
                                  ? AppLocalizations.of(
                                      context,
                                    )!.origDestCurrentLocation
                                  : widget.destinationPlace.name,
                            ),
                        excludeSemantics: true,
                        button: false,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(64),
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(64),
                              color: Theme.of(context).colorScheme.surface,
                            ),
                            child: Row(
                              children: [
                                SizedBox(width: 16),
                                Icon(
                                  Icons.navigation,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.displayMedium?.color,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.destinationPlace.id ==
                                            Navi4AllValues.userLocation
                                        ? AppLocalizations.of(
                                            context,
                                          )!.origDestCurrentLocation
                                        : widget.destinationPlace.name,
                                    style: const TextStyle(fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                SizedBox(width: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Consumer<RoutingController>(
                  builder: (context, routingController, _) =>
                      _processingStatus != ProcessingStatus.processing &&
                          _processingStatus != ProcessingStatus.error
                      ? ListView(children: _legTiles)
                      : NavigationProcessingTile(
                          processingStatus: _processingStatus,
                        ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(
                    height: 0.0,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Material(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Consumer<NavigationStatsController>(
                              builder:
                                  (
                                    context,
                                    navigationStatsController,
                                    _,
                                  ) => Row(
                                    children: [
                                      Icon(
                                        widget.itinerarySummary.legs.length > 1
                                            ? Icons.directions_transit
                                            : ModeIcons.get(
                                                widget
                                                    .itinerarySummary
                                                    .legs
                                                    .first
                                                    .mode,
                                              ),
                                        color: Theme.of(
                                          context,
                                        ).textTheme.displayMedium?.color,
                                      ),
                                      SizedBox(width: 12.0),
                                      navigationStatsController.timeToArrival !=
                                              null
                                          ? Text(
                                              TextFormatter.formatDurationText(
                                                navigationStatsController
                                                    .timeToArrival!,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 16),
                                            )
                                          : SizedBox.shrink(),
                                      SizedBox(width: 6.0),
                                      Icon(
                                        Icons.circle,
                                        size: 6,
                                        color: Theme.of(
                                          context,
                                        ).textTheme.displayMedium?.color,
                                      ),
                                      SizedBox(width: 6.0),
                                      navigationStatsController
                                                  .distanceToArrival !=
                                              null
                                          ? Text(
                                              TextFormatter.formatDistanceValueText(
                                                navigationStatsController
                                                    .distanceToArrival!,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 16),
                                            )
                                          : SizedBox.shrink(),
                                    ],
                                  ),
                            ),
                          ),
                          SizedBox(height: 12.0),
                          Consumer<RoutingController>(
                            builder: (context, routingController, _) => Row(
                              children: [
                                Expanded(
                                  child: SheetButton(
                                    icon:
                                        routingController.navigationStatus ==
                                            NavigationStatus.idle
                                        ? Icons.play_arrow
                                        : routingController.navigationStatus ==
                                              NavigationStatus.navigating
                                        ? Icons.pause
                                        : routingController.navigationStatus ==
                                              NavigationStatus.arrived
                                        ? Icons.check
                                        : Icons.play_arrow,
                                    label:
                                        routingController.navigationStatus ==
                                            NavigationStatus.idle
                                        ? AppLocalizations.of(
                                            context,
                                          )!.routingScreenNavigationStartButton
                                        : routingController.navigationStatus ==
                                              NavigationStatus.navigating
                                        ? AppLocalizations.of(
                                            context,
                                          )!.routingScreenNavigationPauseButton
                                        : routingController.navigationStatus ==
                                              NavigationStatus.arrived
                                        ? AppLocalizations.of(
                                            context,
                                          )!.routingScreenNavigationDoneButton
                                        : AppLocalizations.of(
                                            context,
                                          )!.routingScreenNavigationResumeButton,
                                    semanticLabel:
                                        routingController.navigationStatus ==
                                            NavigationStatus.idle
                                        ? AppLocalizations.of(
                                            context,
                                          )!.routingScreenNavigationStartButton
                                        : routingController.navigationStatus ==
                                              NavigationStatus.navigating
                                        ? AppLocalizations.of(
                                            context,
                                          )!.routingScreenNavigationPauseButton
                                        : routingController.navigationStatus ==
                                              NavigationStatus.arrived
                                        ? AppLocalizations.of(
                                            context,
                                          )!.routingScreenNavigationDoneButton
                                        : AppLocalizations.of(
                                            context,
                                          )!.routingScreenNavigationResumeButton,
                                    onTap: () => _toggleNavigationState(),
                                    shrinkWrap: false,
                                  ),
                                ),
                                SizedBox(width: 8),
                                AccessibleIconButton(
                                  icon:
                                      routingController.audioStatus ==
                                          AudioStatus.muted
                                      ? Icons.volume_off
                                      : Icons.volume_up,
                                  semanticLabel:
                                      routingController.audioStatus ==
                                          AudioStatus.muted
                                      ? AppLocalizations.of(
                                          context,
                                        )!.routeNavigationMuteButtonUnmuteText
                                      : AppLocalizations.of(
                                          context,
                                        )!.routeNavigationMuteButtonMuteText,
                                  onTap: () => _toggleAudioStatus(),
                                ),
                                SizedBox(width: 8),
                                AccessibleIconButton(
                                  icon: Icons.close,
                                  semanticLabel: AppLocalizations.of(
                                    context,
                                  )!.routingScreenExitRoutingButtonSemantic,
                                  onTap: () {
                                    routingController.stopNavigation();
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
