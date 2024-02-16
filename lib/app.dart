import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wahda_bank/views/view/screens/home/home.dart';
import 'package:wahda_bank/views/view/screens/splash.dart';
import 'app/bindings/home_binding.dart';
import 'services/internet_service.dart';
import 'utills/constants/language.dart';
import 'package:timeago/timeago.dart' as timeago;

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
    if (locale == 'ar') {
      timeago.setLocaleMessages('ar', timeago.ArMessages());
      timeago.setDefaultLocale(locale);
    } else {
      timeago.setDefaultLocale(locale);
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: InternetService.instance.navigatorKey,
      title: 'Wahda Bank',
      translations: Lang(),
      locale: Locale(locale),
      theme: ThemeData(
        // fontFamily: 'sfp',
        textTheme: GoogleFonts.poppinsTextTheme(),
        primaryColor: Colors.green,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.green,
          accentColor: Colors.green,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F7FA),
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(color: Colors.black),
          iconTheme: IconThemeData(color: Colors.black),
          elevation: 0,
          centerTitle: true,
          color: Colors.transparent,
        ),
      ),
      home: const SplashScreen(),
      getPages: [
        GetPage(
          name: '/home',
          page: () => const HomeScreen(),
          binding: HomeBinding(),
        ),
      ],
    );
  }
}
