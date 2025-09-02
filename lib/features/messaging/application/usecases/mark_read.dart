import '../../domain/entities/folder.dart';
import '../../domain/repositories/message_repository.dart';

/// Use case: MarkRead
class MarkRead {
  final MessageRepository repo;

  const MarkRead(this.repo);

  Future<void> call({
    required Folder folder,
    required String messageId,
    required bool read,
  }) async {
    if (messageId.isEmpty) return;
    await repo.markRead(folder: folder, messageId: messageId, read: read);
  }
}

