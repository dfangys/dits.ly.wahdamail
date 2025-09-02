import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/widgets/search/controllers/mail_search_controller.dart';
import 'package:wahda_bank/services/feature_flags.dart';
import 'package:wahda_bank/shared/ddd_ui_wiring.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/services/mail_service.dart';

/// Presentation adapter for search orchestrations.
/// - Respects kill-switch precedence and P12 routing
/// - Delegates to DDD search when enabled, otherwise legacy search via MailClient
@lazySingleton
class SearchViewModel extends GetxController with StateMixin<List<MimeMessage>> {
  // State owned by the ViewModel in P12.2
  final List<MimeMessage> searchMessages = <MimeMessage>[];
  MailSearchResult? searchResults;
  final MailClient client = MailService.instance.client;

  Future<void> runSearch(MailSearchController controller, {required String requestId}) async {
    final sw = Stopwatch()..start();

    // Try DDD first when eligible
    if (!FeatureFlags.instance.dddKillSwitchEnabled &&
        FeatureFlags.instance.dddSearchEnabled) {
      final handled = await DddUiWiring.maybeSearch(controller: controller);
      if (handled) {
        // Copy results from controller into VM state for UI to observe
        try {
          searchMessages
            ..clear()
            ..addAll(controller.searchMessages);
          if (searchMessages.isEmpty) {
            change(null, status: RxStatus.empty());
          } else {
            change(searchMessages, status: RxStatus.success());
          }
          Telemetry.event('search_success', props: {
            'request_id': requestId,
            'op': 'search',
            'lat_ms': sw.elapsedMilliseconds,
          });
        } catch (_) {}
        return;
      }
    }

    // Legacy fallback handled directly by VM
    try {
      final results = await client.searchMessages(
        MailSearch(
          controller.searchController.text,
          SearchQueryType.allTextHeaders,
          messageType: SearchMessageType.all,
        ),
      );
      searchResults = results;
      searchMessages
        ..clear()
        ..addAll(results.messages);
      if (searchMessages.isEmpty) {
        change(null, status: RxStatus.empty());
      } else {
        change(searchMessages, status: RxStatus.success());
      }
      Telemetry.event('search_success', props: {
        'request_id': requestId,
        'op': 'search',
        'lat_ms': sw.elapsedMilliseconds,
      });
    } catch (e) {
      try {
        Telemetry.event('search_failure', props: {
          'request_id': requestId,
          'op': 'search',
          'lat_ms': sw.elapsedMilliseconds,
          'error_class': e.runtimeType.toString(),
        });
      } catch (_) {}
      change(null, status: RxStatus.error(e.toString()));
    }
  }
}

