import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_engagement_event.freezed.dart';
part 'user_engagement_event.g.dart';

@freezed
abstract class UserEngagementEvent with _$UserEngagementEvent {
  const factory UserEngagementEvent({
    @JsonKey(name: 'event_id') required String eventId,
    @JsonKey(name: 'event_title') required String eventTitle,
    @JsonKey(name: 'event_description') required String eventDescription,
    @JsonKey(name: 'event_url') String? eventUrl,
    @JsonKey(name: 'event_valid_until') DateTime? eventValidUntil,
    @JsonKey(name: 'decline_button_text')
    @Default('Cancel')
    String declineButtonText,
    @JsonKey(name: 'accept_button_text')
    @Default('Continue')
    String acceptButtonText,
  }) = _UserEngagementEvent;

  factory UserEngagementEvent.fromJson(Map<String, Object?> json) =>
      _$UserEngagementEventFromJson(json);
}
