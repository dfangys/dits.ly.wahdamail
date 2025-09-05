import '../../domain/entities/message.dart';
import '../../domain/entities/folder.dart';
import '../../domain/repositories/message_repository.dart';

/// Use case: FetchMessageBody
class FetchMessageBody {
  final MessageRepository repo;

  const FetchMessageBody(this.repo);

  Future<Message?> call({
    required Folder folder,
    required String messageId,
  }) async {
    if (messageId.isEmpty) return null;
    return repo.fetchMessageBody(folder: folder, messageId: messageId);
  }
}
