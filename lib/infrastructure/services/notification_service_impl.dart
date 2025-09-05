import '../../domain/repositories/notifications_repository.dart';

class NotificationServiceImpl implements INotificationsRepository {
  @override
  Future<void> show({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    // TODO: bridge to existing flutter_local_notifications service, preserving channel config
  }
}
