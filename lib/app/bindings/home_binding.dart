import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/auth_controller.dart';
import 'package:wahda_bank/models/sqlite_draft_repository.dart';
import 'package:wahda_bank/services/cache_manager.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/services/realtime_update_service.dart';
import 'package:wahda_bank/widgets/progress_indicator_widget.dart';
import 'package:wahda_bank/shared/di/injection.dart';
import 'package:wahda_bank/features/messaging/presentation/mailbox_view_model.dart';
import 'package:wahda_bank/features/messaging/presentation/compose_view_model.dart';
import 'package:wahda_bank/features/search/presentation/search_view_model.dart';

import '../controllers/mailbox_controller.dart';
import '../controllers/selection_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Register MailService first as it's required by other services
    Get.put<MailService>(MailService.instance, permanent: true);

    // Register SQLiteDraftRepository for draft functionality
    Get.put<SQLiteDraftRepository>(
      SQLiteDraftRepository.instance,
      permanent: true,
    );

    // Register performance optimization services
    Get.put<CacheManager>(CacheManager(), permanent: true);
    Get.put<RealtimeUpdateService>(
      RealtimeUpdateService.instance,
      permanent: true,
    );

    // Register progress controller
    Get.put<EmailDownloadProgressController>(
      EmailDownloadProgressController(),
      permanent: true,
    );

    // P12.2: Pre-register presentation ViewModels via DI for UI consumption
    Get.put<MailboxViewModel>(getIt<MailboxViewModel>(), permanent: true);
    Get.put<ComposeViewModel>(getIt<ComposeViewModel>(), permanent: true);
    Get.put<SearchViewModel>(getIt<SearchViewModel>(), permanent: true);

    Get.lazyPut<MailBoxController>(() => MailBoxController(), fenix: true);
    Get.lazyPut<SelectionController>(() => SelectionController());
    // P12.4c: MailCountController removed; counts served via MailboxViewModel/UseCase
    Get.lazyPut<AuthController>(() => AuthController(), fenix: true);
    // Get.put<AuthController>(AuthController(), permanent: true);

    // 👇 this line is the important change
    // Get.putAsync<SqliteMimeStorage>(() async {
    //   final storage = SqliteMimeStorage.instance;
    //   await storage.database;          // warm-up
    //   return storage;
    // });
  }
}
