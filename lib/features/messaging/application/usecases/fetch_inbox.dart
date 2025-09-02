import '../../domain/entities/message.dart';
import '../../domain/entities/folder.dart';
import '../../domain/repositories/folder_repository.dart';
import '../../domain/repositories/message_repository.dart';

/// Use case: FetchInbox
class FetchInbox {
  final FolderRepository folderRepo;
  final MessageRepository messageRepo;

  const FetchInbox(this.folderRepo, this.messageRepo);

  /// Fetch headers for the inbox (or provided folder).
  Future<List<Message>> call({Folder? folder, int limit = 50, int offset = 0}) async {
    final target = folder ?? (await folderRepo.getInbox());
    if (target == null) return <Message>[];
    return messageRepo.fetchInbox(folder: target, limit: limit, offset: offset);
  }
}

