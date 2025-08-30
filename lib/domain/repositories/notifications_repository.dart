abstract class INotificationsRepository {
  Future<void> show({required String title, required String body, Map<String, dynamic>? payload});
}
