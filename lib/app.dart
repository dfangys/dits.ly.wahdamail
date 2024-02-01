import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/features/view/screens/splash.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Demo',
        theme: ThemeData(
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
          ),
        ),
        home: const SplashScreen());
  }
}
