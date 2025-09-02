import 'package:injectable/injectable.dart';
import 'package:wahda_bank/features/messaging/application/facade/messaging_facade.dart';
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/message.dart' as dom;

/// Legacy adapter facade used when DDD messaging is disabled.
/// P2 scope: return empty result; actual legacy behavior remains in legacy services.
@LazySingleton()
class LegacyMessagingFacade implements MessagingFacade {
  @override
  Future<List<dom.Message>> fetchInbox({
    required dom.Folder folder,
    int limit = 50,
    int offset = 0,
  }) async {
    return const <dom.Message>[];
  }
}

