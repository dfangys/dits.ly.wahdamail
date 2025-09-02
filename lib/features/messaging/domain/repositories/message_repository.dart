import '../entities/message.dart';
import '../entities/folder.dart';
import '../entities/attachment.dart';
import '../entities/body.dart';

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
  /// Returns the updated domain Message with body populated and/or a BodyContent value if needed.
  Future<Message> fetchMessageBody({
    required Folder folder,
    required String messageId,
  });

  /// List attachments for a message.
  Future<List<Attachment>> listAttachments({
    required Folder folder,
    required String messageId,
  });

  /// Download attachment content. Idempotent: returns cached bytes if already downloaded.
  Future<List<int>> downloadAttachment({
    required Folder folder,
    required String messageId,
    required String partId,
  });

  /// Mark a message read/unread.
  Future<void> markRead({
    required Folder folder,
    required String messageId,
    required bool read,
  });
}

