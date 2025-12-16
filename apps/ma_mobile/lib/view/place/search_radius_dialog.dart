import 'package:flutter/material.dart';
import 'package:smartroots/core/config.dart';
import 'package:smartroots/core/theme/colors.dart';
import 'package:smartroots/l10n/app_localizations.dart';
import 'package:smartroots/view/common/accessible_icon_button.dart';
import 'package:smartroots/view/common/sheet_button.dart';

class SearchRadiusDialog extends StatefulWidget {
  final int selectedRadius;
  final void Function(int changedRadius) onConfirm;
  final VoidCallback onCancel;

  const SearchRadiusDialog({
    super.key,
    required this.selectedRadius,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<SearchRadiusDialog> createState() => _SearchRadiusDialogState();
}

class _SearchRadiusDialogState extends State<SearchRadiusDialog> {
  late int _changedRadius;

  @override
  void initState() {
    super.initState();
    _changedRadius = widget.selectedRadius;
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setStateDialog) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Semantics(
          label: AppLocalizations.of(context)!.placeScreenChangeRadiusButton,
          focused: true,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Semantics(
                    excludeSemantics: true,
                    child: Text(
                      AppLocalizations.of(
                        context,
                      )!.placeScreenChangeRadiusButton,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: SmartRootsColors.maBlueExtraExtraDark,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 32),
                Semantics(
                  label: AppLocalizations.of(
                    context,
                  )!.placeScreenDialogRadiusSemantic(_changedRadius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AccessibleIconButton(
                          icon: Icons.remove_rounded,
                          onTap: () {
                            setStateDialog(() {
                              if (_changedRadius > Settings.searchRadiusMin) {
                                _changedRadius -= 100;
                              }
                            });
                          },
                          semanticLabel: AppLocalizations.of(
                            context,
                          )!.placeScreenDialogRadiusDecrementSemantic,
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 64.0,
                          child: Semantics(
                            excludeSemantics: true,
                            child: Text(
                              '$_changedRadius m',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: SmartRootsColors.maBlueExtraExtraDark,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        AccessibleIconButton(
                          icon: Icons.add_rounded,
                          onTap: () {
                            setStateDialog(() {
                              if (_changedRadius < Settings.searchRadiusMax) {
                                _changedRadius += 100;
                              }
                            });
                          },
                          semanticLabel: AppLocalizations.of(
                            context,
                          )!.placeScreenDialogRadiusIncrementSemantic,
                        ),
                      ],
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
                        )!.placeScreenChangeRadiusCancel,
                        onTap: () {
                          widget.onCancel();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: SheetButton(
                        label: AppLocalizations.of(
                          context,
                        )!.placeScreenChangeRadiusConfirm,
                        onTap: () {
                          setState(() {
                            widget.onConfirm(_changedRadius);
                            Navigator.of(context).pop();
                          });
                        },
                      ),
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
