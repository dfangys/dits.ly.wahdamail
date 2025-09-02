import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/widgets/search/controllers/mail_search_controller.dart';
import 'package:wahda_bank/services/feature_flags.dart';
import 'package:wahda_bank/shared/ddd_ui_wiring.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';
import 'package:enough_mail/enough_mail.dart';

/// Presentation adapter for search orchestrations.
/// - Respects kill-switch precedence and P12 routing
/// - Delegates to DDD search when enabled, otherwise legacy search via MailClient
@lazySingleton
class SearchViewModel {
  Future<void> runSearch(MailSearchController controller, {required String requestId}) async {
    final sw = Stopwatch()..start();

    // Try DDD first when eligible
    if (!FeatureFlags.instance.dddKillSwitchEnabled &&
        FeatureFlags.instance.dddSearchEnabled) {
      final handled = await DddUiWiring.maybeSearch(controller: controller);
      if (handled) {
        // success handled by DDD; emit operation telemetry
        try {
          Telemetry.event('search_success', props: {
            'request_id': requestId,
            'op': 'search',
            'lat_ms': sw.elapsedMilliseconds,
          });
        } catch (_) {}
        return;
      }
    }

    // Legacy fallback
    try {
      final results = await controller.client.searchMessages(
        MailSearch(
          controller.searchController.text,
          SearchQueryType.allTextHeaders,
          messageType: SearchMessageType.all,
        ),
      );
      controller.searchResults = results;
      controller.searchMessages
        ..clear()
        ..addAll(results.messages);
      if (controller.searchMessages.isEmpty) {
        controller.change(null, status: RxStatus.empty());
      } else {
        controller.change(controller.searchMessages, status: RxStatus.success());
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
      controller.change(null, status: RxStatus.error(e.toString()));
    }
  }
}

