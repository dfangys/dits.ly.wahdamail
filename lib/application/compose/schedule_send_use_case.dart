import '../../domain/entities/draft.dart';

class ScheduleSendUseCase {
  const ScheduleSendUseCase();

  Future<void> call(Draft draft, DateTime scheduledFor) async {
    // Scheduling policy orchestration goes here
    // Delegates to background scheduler infrastructure
  }
}
