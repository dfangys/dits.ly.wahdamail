import '../../domain/repositories/notifications_repository.dart';

class ShowNotificationUseCase {
  final INotificationsRepository notificationsRepository;
  const ShowNotificationUseCase(this.notificationsRepository);

  Future<void> call({required String title, required String body, Map<String, dynamic>? payload}) async {
    await notificationsRepository.show(title: title, body: body, payload: payload);
  }
}
