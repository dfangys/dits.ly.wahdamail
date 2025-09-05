import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/design_system/theme/app_theme.dart' as ds;
import 'package:wahda_bank/views/view/screens/home/home.dart';
import 'package:wahda_bank/features/messaging/presentation/screens/compose/redesigned_compose_screen.dart';
import 'package:wahda_bank/views/view/screens/splash.dart';
import 'package:wahda_bank/views/authantication/screens/auth_screen.dart';
import 'package:wahda_bank/middleware/auth_middleware.dart';
import 'package:wahda_bank/services/security_service.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'app/bindings/home_binding.dart';
import 'services/internet_service.dart';
import 'package:wahda_bank/services/scheduled_send_service.dart';
import 'utills/constants/language.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/date_symbol_data_local.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String get locale => GetStorage().read('language') ?? 'en';
  @override
  void initState() {
    InternetService.instance.init();

    // Initialize SettingController first, before SecurityService
    Get.put(SettingController());

    // Then initialize SecurityService
    _initSecurityService();

    // Initialize scheduled send foreground service (checks due drafts every minute)
    try {
      ScheduledSendService.instance.init();
    } catch (_) {}

    if (locale == 'ar') {
      timeago.setLocaleMessages('ar', timeago.ArMessages());
      timeago.setDefaultLocale(locale);
      Intl.defaultLocale = 'ar';
      initializeDateFormatting('ar');
    } else {
      timeago.setDefaultLocale(locale);
      Intl.defaultLocale = 'en';
      initializeDateFormatting('en');
    }
    super.initState();
  }

  Future<void> _initSecurityService() async {
    await Get.putAsync(() => SecurityService().init());
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: InternetService.instance.navigatorKey,
      title: 'Wahda Mail',
      translations: Lang(),
      locale: Locale(locale),
      theme: ds.AppThemeDS.light.copyWith(
        // Keep locale-specific font selection
        textTheme: ds.AppThemeDS.light.textTheme.apply(
          fontFamily: locale == 'en' ? 'sfp' : 'arb',
        ),
      ),
      darkTheme: ds.AppThemeDS.dark.copyWith(
        textTheme: ds.AppThemeDS.dark.textTheme.apply(
          fontFamily: locale == 'en' ? 'sfp' : 'arb',
        ),
      ),
      home: const SplashScreen(),
      builder: EasyLoading.init(),
      getPages: [
        GetPage(
          name: '/home',
          page: () => const HomeScreen(),
          binding: HomeBinding(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(name: '/auth', page: () => AuthScreen()),
        // Mobile full-screen compose route used by ComposeModal launcher
        GetPage(
          name: '/compose-full',
          page: () => const RedesignedComposeScreen(),
        ),
      ],
    );
  }
}
