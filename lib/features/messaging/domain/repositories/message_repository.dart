import '../entities/message.dart';
import '../entities/folder.dart';

/// Domain repository interface for message operations.
/// No SDK/infra types should appear here.
abstract class MessageRepository {
  /// Fetch inbox (or any folder) messages with header-first strategy.
  Future<List<Message>> fetchInbox({
    required Folder folder,
    int limit = 50,
    int offset = 0,
  });

  /// Fetch the message body (plain/html) for a given message id in a folder.
  Future<Message> fetchMessageBody({
    required Folder folder,
    required String messageId,
  });

  /// Mark a message read/unread.
  Future<void> markRead({
    required Folder folder,
    required String messageId,
    required bool read,
  });
}

