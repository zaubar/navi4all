import 'package:flutter/material.dart';
import 'package:smartroots/core/theme/icons.dart';
import 'package:smartroots/l10n/app_localizations.dart';
import 'package:smartroots/schemas/routing/leg.dart' as leg_schema;
import 'package:smartroots/schemas/routing/mode.dart';
import 'package:smartroots/view/routing/step_tile.dart';

class LegTile extends StatelessWidget {
  final leg_schema.LegDetailed leg;
  final leg_schema.LegDetailed? activeLeg;
  final List<leg_schema.Step> steps;
  final leg_schema.Step? activeStep;
  final bool isPrimaryLeg;

  const LegTile({
    super.key,
    required this.leg,
    this.activeLeg,
    required this.steps,
    this.activeStep,
    this.isPrimaryLeg = false,
  });

  Widget _buildTransitWidget(BuildContext context) {
    return (leg.mode != Mode.WALK &&
            leg.mode != Mode.BICYCLE &&
            leg.mode != Mode.CAR)
        ? Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 12.0,
                  ),
                  child: Text(
                    leg.route!.shortName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(
                      context,
                    )!.routingScreenLegTransitDirection(leg.headsign!),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          )
        : SizedBox.shrink();
  }

  List<StepTile> _buildStepTiles(
    List<leg_schema.Step> steps,
    leg_schema.Step? activeStep,
  ) {
    List<StepTile> stepTiles = [];
    for (leg_schema.Step step in steps) {
      stepTiles.add(
        StepTile(step: step, activeStep: activeStep, mode: leg.mode),
      );
    }
    return stepTiles;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          !isPrimaryLeg
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(
                            context,
                          ).textTheme.displayMedium?.color,
                        ),
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          ModeIcons.get(leg.mode),
                          color: Theme.of(context).colorScheme.surface,
                          size: 20.0,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        getModeTextMapping(leg.mode, context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : SizedBox.shrink(),
          !isPrimaryLeg ? SizedBox(height: 16) : SizedBox.shrink(),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                !isPrimaryLeg ? SizedBox(width: 16) : SizedBox.shrink(),
                !isPrimaryLeg
                    ? _VerticalRouteLine(
                        color:
                            Theme.of(context).textTheme.displayMedium?.color ??
                            Theme.of(context).colorScheme.primary,
                        dashed: leg.mode == Mode.WALK,
                      )
                    : SizedBox.shrink(),
                !isPrimaryLeg ? SizedBox(width: 12) : SizedBox.shrink(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTransitWidget(context),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildStepTiles(steps, activeStep),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalRouteLine extends StatelessWidget {
  final Color color;
  final bool dashed;

  const _VerticalRouteLine({required this.color, required this.dashed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 4,
      child: CustomPaint(
        painter: _VerticalRouteLinePainter(color: color, dashed: dashed),
      ),
    );
  }
}

class _VerticalRouteLinePainter extends CustomPainter {
  final Color color;
  final bool dashed;

  _VerticalRouteLinePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round;

    if (!dashed) {
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        paint,
      );
      return;
    }

    const double dashLength = 1.0;
    const double gapLength = 16.0;
    double startY = 0;

    while (startY < size.height) {
      final double endY = (startY + dashLength).clamp(0, size.height);
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, endY),
        paint,
      );
      startY += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalRouteLinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.dashed != dashed;
  }
}
