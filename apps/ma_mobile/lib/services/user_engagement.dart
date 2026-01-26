import 'package:dio/dio.dart';
import 'package:smartroots/schemas/user_engagement/user_engagement_event.dart';
import 'package:smartroots/services/api.dart';

class UserEngagementService extends APIService {
  Future<UserEngagementEvent?> getEvent() async {
    Response response = await apiClient.get('/user-engagement/event');

    if (response.statusCode != 200) {
      return null;
    }

    try {
      UserEngagementEvent event = UserEngagementEvent.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      if (event.eventValidUntil != null &&
          event.eventValidUntil!.isBefore(DateTime.now())) {
        return null;
      }

      return event;
    } catch (_) {
      return null;
    }
  }
}
