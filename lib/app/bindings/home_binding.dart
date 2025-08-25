import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/auth_controller.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';
import 'package:wahda_bank/services/cache_manager.dart';
import 'package:wahda_bank/services/realtime_update_service.dart';

import '../controllers/mail_count_controller.dart';
import '../controllers/mailbox_controller.dart';
import '../controllers/selection_controller.dart';
import '../controllers/settings_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Register performance optimization services first
    Get.put<CacheManager>(CacheManager(), permanent: true);
    Get.put<RealtimeUpdateService>(RealtimeUpdateService.instance, permanent: true);
    
    Get.lazyPut<MailBoxController>(() => MailBoxController(), fenix: true);
    Get.lazyPut<SelectionController>(() => SelectionController());
    Get.lazyPut<SettingController>(() => SettingController());
    Get.lazyPut<MailCountController>(() => MailCountController());
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
