import 'package:injectable/injectable.dart';
import 'package:wahda_bank/features/messaging/application/facade/messaging_facade.dart';
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/message.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart';

/// DDD facade implementation that delegates to domain repository
/// adhering to header-first strategy in P2.
@LazySingleton()
class DddMailServiceImpl implements MessagingFacade {
  final MessageRepository _repo;
  DddMailServiceImpl(this._repo);

  @override
  Future<List<dom.Message>> fetchInbox({
    required dom.Folder folder,
    int limit = 50,
    int offset = 0,
  }) {
    return _repo.fetchInbox(folder: folder, limit: limit, offset: offset);
  }
}

