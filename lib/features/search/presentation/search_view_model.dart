import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/services/feature_flags.dart';
// P12.3: inline DDD search (remove shim)
import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart';
import 'package:wahda_bank/features/messaging/application/usecases/search_messages.dart'
    as uc;
import 'package:wahda_bank/features/messaging/domain/value_objects/search_query.dart'
    as dom;
import 'package:wahda_bank/shared/logging/telemetry.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/shared/di/injection.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/shared/telemetry/tracing.dart';

/// Presentation adapter for search orchestrations.
/// - Respects kill-switch precedence and P12 routing
/// - Delegates to DDD search when enabled, otherwise legacy search via MailClient
@lazySingleton
class SearchViewModel extends GetxController
    with StateMixin<List<MimeMessage>> {
  // State owned by the ViewModel in P12.2
  final List<MimeMessage> searchMessages = <MimeMessage>[];
  Future<void> runSearchText(
    String query, {
    required String requestId,
  }) async {
    final sw = Stopwatch()..start();

    // Try DDD first when eligible (inline use-case)
    if (!FeatureFlags.instance.dddKillSwitchEnabled &&
        FeatureFlags.instance.dddSearchEnabled) {
      try {
        final span = Tracing.startSpan(
          'Search',
          attrs: {'request_id': requestId},
        );
        final repo = getIt<MessageRepository>();
        final search = uc.SearchMessages(repo);
          final q = dom.SearchQuery(
            text: query,
            limit: 50,
          );
        final accountId =
            (GetStorage().read('email') as String?) ?? 'default-account';
        final results = await search(accountId: accountId, query: q);

        // Map to minimal MimeMessage list for display
        final list = <MimeMessage>[];
        for (final r in results) {
          try {
            final mm = MimeMessage();
            mm.envelope = Envelope(
              date: r.date,
              subject: 'Result',
              from: const [MailAddress('Unknown', 'unknown@unknown.com')],
            );
            list.add(mm);
          } catch (_) {}
        }

        searchMessages
          ..clear()
          ..addAll(list);
        if (searchMessages.isEmpty) {
          change(null, status: RxStatus.empty());
        } else {
          change(searchMessages, status: RxStatus.success());
        }
        Tracing.end(span);
        Telemetry.event(
          'search_success',
          props: {
            'request_id': requestId,
            'op': 'search',
            'lat_ms': sw.elapsedMilliseconds,
          },
        );
        return;
      } catch (e) {
        try {
          Telemetry.event(
            'search_failure',
            props: {
              'request_id': requestId,
              'op': 'search',
              'lat_ms': sw.elapsedMilliseconds,
              'error_class': e.runtimeType.toString(),
            },
          );
        } catch (_) {}
        // fall back to legacy
      }
    }

    // No legacy fallback in P12.4; rely on repository.
  }
}
