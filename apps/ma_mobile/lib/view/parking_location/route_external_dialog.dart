import 'package:flutter/material.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:smartroots/core/theme/colors.dart';
import 'package:smartroots/l10n/app_localizations.dart';
import 'package:smartroots/view/common/selection_tile.dart';
import 'package:smartroots/view/common/sheet_button.dart';

class RouteExternalDialog extends StatelessWidget {
  final List<AvailableMap> availableMaps;
  final void Function(AvailableMap) onConfirm;
  final VoidCallback onCancel;

  const RouteExternalDialog({
    super.key,
    required this.availableMaps,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setStateDialog) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Text(
                  AppLocalizations.of(
                    context,
                  )!.parkingLocationButtonRouteExternal,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: SmartRootsColors.maBlueExtraExtraDark,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final map = availableMaps[index];
                    return SelectionTile(
                      leadingSvg: map.icon,
                      title: map.mapName,
                      isSelected: false,
                      onTap: () {
                        onConfirm(map);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                  separatorBuilder: (context, index) => SizedBox(height: 8),
                  itemCount: availableMaps.length,
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SheetButton(
                      label: AppLocalizations.of(
                        context,
                      )!.routingScreenReroutingDialogCancelButton,
                      onTap: onCancel,
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
