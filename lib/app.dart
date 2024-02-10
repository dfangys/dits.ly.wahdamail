import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/view/screens/home/home.dart';
import 'package:wahda_bank/views/view/screens/splash.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'app/bindings/home_binding.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wahda Bank',
      theme: ThemeData(
        fontFamily: 'sfp',
        primaryColor: AppTheme.primaryColor,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: AppTheme.primaryColor,
          accentColor: AppTheme.primaryColor,
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
