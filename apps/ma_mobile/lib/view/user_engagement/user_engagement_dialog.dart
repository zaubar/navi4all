import 'package:flutter/material.dart';
import 'package:smartroots/schemas/user_engagement/user_engagement_event.dart';
import 'package:smartroots/view/common/sheet_button.dart';
import 'package:url_launcher/url_launcher.dart';

class UserEngagementDialog extends StatelessWidget {
  final UserEngagementEvent event;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const UserEngagementDialog({
    super.key,
    required this.event,
    this.onConfirm,
    this.onCancel,
  });

  Future<void> _handleConfirm(BuildContext context) async {
    onConfirm?.call();

    final String? eventUrl = event.eventUrl;
    if (eventUrl != null && eventUrl.trim().isNotEmpty) {
      final Uri url = Uri.parse(eventUrl);
      await launchUrl(url);
    }

    Navigator.of(context).pop();
  }

  void _handleCancel(BuildContext context) {
    onCancel?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: OrientationBuilder(
        builder: (context, orientation) => Container(
          width: orientation == Orientation.portrait
              ? double.infinity
              : MediaQuery.of(context).size.width * 0.5,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Text(
                  event.eventTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    event.eventDescription,
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: SheetButton(
                      label: event.declineButtonText,
                      onTap: () => _handleCancel(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SheetButton(
                      label: event.acceptButtonText,
                      onTap: () => _handleConfirm(context),
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
