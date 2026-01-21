import 'package:flutter/material.dart';
import 'package:navi4all/core/utils.dart';
import 'package:navi4all/l10n/app_localizations.dart';
import 'package:navi4all/schemas/routing/leg.dart' as leg_schema;
import 'package:navi4all/schemas/routing/mode.dart';

class StepTile extends StatelessWidget {
  final Mode mode;
  final leg_schema.Step step;
  final leg_schema.Step? activeStep;

  const StepTile({
    super.key,
    required this.step,
    this.activeStep,
    required this.mode,
  });

  IconData? get _actionIcon =>
      getRelativeDirectionIconMapping(step.relativeDirection);

  String _getStepTextInstruction(BuildContext context) {
    if (step.textInstruction != null && step.textInstruction!.isNotEmpty) {
      return step.textInstruction!;
    } else {
      return getRelativeDirectionTextMapping(
        step.relativeDirection,
        context,
        mode: mode,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        color: step == activeStep
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        children: [
          SizedBox(height: 16),
          Row(
            children: [
              _actionIcon != null
                  ? Icon(
                      _actionIcon,
                      color: step == activeStep
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.secondary,
                      size: 32,
                    )
                  : SizedBox(width: 32),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStepTextInstruction(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: step == activeStep
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    !step.bogusName
                        ? Text(
                            step.streetName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              color: step == activeStep
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          )
                        : SizedBox.shrink(),
                    step.relativeDirection != RelativeDirection.DEPART &&
                            step.distance > 0
                        ? Text(
                            AppLocalizations.of(
                              context,
                            )!.navigationStepDistanceToAction(
                              TextFormatter.formatDistanceValueText(
                                step.distance,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: step == activeStep
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          )
                        : SizedBox.shrink(),
                    step.timeOfStep != null
                        ? Text(
                            TextFormatter.formatTimeOfDay(step.timeOfStep!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: step == activeStep
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          )
                        : SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          step != activeStep
              ? Divider(
                  color: Theme.of(context).colorScheme.secondary,
                  height: 0.0,
                )
              : SizedBox.shrink(),
        ],
      ),
    );
  }
}
