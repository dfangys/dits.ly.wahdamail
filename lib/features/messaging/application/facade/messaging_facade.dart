/// Application facade for messaging features used by presentation.
/// No SDK or Flutter imports here.
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/message.dart' as dom;

abstract class MessagingFacade {
  /// Headers-only inbox fetch for P2.
  Future<List<dom.Message>> fetchInbox({
    required dom.Folder folder,
    int limit = 50,
    int offset = 0,
  });
}

