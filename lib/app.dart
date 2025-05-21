import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/view/screens/home/home.dart';
import 'package:wahda_bank/views/view/screens/splash.dart';
import 'package:wahda_bank/views/authantication/screens/auth_screen.dart';
import 'package:wahda_bank/middleware/auth_middleware.dart';
import 'package:wahda_bank/services/security_service.dart';
import 'package:wahda_bank/services/internet_service.dart';
import 'package:wahda_bank/utills/constants/language.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/date_symbol_data_local.dart';

// <-- import your global email binding
import 'package:wahda_bank/app/controllers/email_controller_binding.dart';

// import your Home‐specific binding
import 'package:wahda_bank/app/bindings/home_binding.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String get locale => GetStorage().read('language') ?? 'en';

  @override
  void initState() {
    super.initState();

    // Initialize connectivity and security
    InternetService.instance.init();
    _initSecurityService();

    // Locale + timeago setup
    if (locale == 'ar') {
      timeago.setLocaleMessages('ar', timeago.ArMessages());
      timeago.setDefaultLocale('ar');
      Intl.defaultLocale = 'ar';
      initializeDateFormatting('ar');
    } else {
      timeago.setDefaultLocale('en');
      Intl.defaultLocale = 'en';
      initializeDateFormatting('en');
    }
  }

  Future<void> _initSecurityService() async {
    // Wait for SecurityService to finish setup
    await Get.putAsync(() => SecurityService().init());
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,

      // 1️⃣ Run your global email controllers before anything else
      initialBinding: EmailControllerBinding(),

      navigatorKey: InternetService.instance.navigatorKey,
      title: 'Wahda Mail',
      translations: Lang(),
      locale: Locale(locale),
      theme: ThemeData(
        fontFamily: locale == 'en' ? 'sfp' : 'arb',
        primaryColor: AppTheme.primaryColor,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: AppTheme.primaryColor),
        useMaterial3: false,
        scaffoldBackgroundColor: const Color(0xFFF2F7FA),
        appBarTheme: AppBarTheme(
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontFamily: locale == 'en' ? 'sfp' : 'arb',
          ),
          iconTheme: const IconThemeData(color: Colors.black),
          elevation: 0,
          centerTitle: true,
          color: Colors.transparent,
        ),
      ),

      // 2️⃣ Show splash first
      home: const SplashScreen(),

      builder: EasyLoading.init(),

      // 3️⃣ Register pages; Home now only needs HomeBinding
      getPages: [
        GetPage(
          name: '/home',
          page: () => const HomeScreen(),
          binding: HomeBinding(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/auth',
          page: () => AuthScreen(),
        ),
      ],
    );
  }
}