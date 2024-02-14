import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wahda_bank/views/view/screens/home/home.dart';
import 'package:wahda_bank/views/view/screens/splash.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'app/bindings/home_binding.dart';

class Lang extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': {
          'hello': 'Hello World',
          'no_subject': "No Subject",
          'language': 'Language',
          'english': 'English',
          'arabic': 'Arabic',
          'are_you_u_wtd': 'Are you sure to delete?',
          'delete': 'Delete',
          'cancel': 'Cancel',
          'mark_as_read': 'Mark as read',
          'readreceipt': 'Read receipts',
          'security': 'Security',
          'swipe_gestures': 'Swipe Gestures',
          'signature': 'Signature',
          'logout': 'Logout',
          'Off': 'Off',
          'set_your_swipe_preferences': 'Set your swipe preferences',
          'set_your_sig': 'Set your signature',
          'starred': 'Starred',
          'search': 'Search',
          'login': 'Login',
          'email': 'Email',
          'inbox': 'Inbox',
          'reset_password': 'Reset Password',
          'attach_file': 'Attach File',
          'from_files': 'From File',
          'from_gallery': 'From File',
          'more_options': 'More Options',
          'save_as_draft': 'Save as Draft',
          'request_read_receipt': 'Request Read Receipt',
          'convert_to_plain_text': 'Convert to plain text',
          'from': 'From',
          'to': 'To',
          'cc': 'CC',
          'edit': 'Edit',
          'bcc': 'Bcc',
          'subject': 'Subject',
          'send': 'Send',
          'reply': 'Reply',
          'forward': 'Forward',
          'new_message': 'New Message',
          'account_name': 'Account Name',
          'trash': 'Trash',
          'compose': 'Compose',
          'settings': 'Settings',
          'accounts': 'Accounts',
          'undo': 'Undo',
          'contact_us': 'Contact Us',
          'terms_and_condition': 'Terms and Condition',
        },
        'ar': {
          'hello': 'مرحبا بالعالم',
          'no_subject': "بدون موضوع",
          'language': 'لغة',
          'english': 'الإنجليزية',
          'arabic': 'عربى',
          'are_you_u_wtd': 'عربى',
          'delete': 'عربى',
          'cancel': 'عربى',
          'readreceipt': 'عربى',
          'mark_as_read': 'Mark as read',
          'security': 'عربى',
          'swipe_gestures': 'عربى',
          'signature': 'عربى',
          'logout': 'عربى',
          'Off': 'عربى',
          'set_your_swipe_preferences': 'عربى',
          'set_your_sig': 'عربى',
          'starred': 'عربى',
          'search': 'عربى',
          'login': 'عربى',
          'email': 'عربى',
          'reset_password': 'عربى',
          'attach_file': 'عربى',
          'from_files': 'عربى',
          'from_gallery': 'عربى',
          'more_options': 'عربى',
          'save_as_draft': 'عربى',
          'request_read_receipt': 'عربى',
          'convert_to_plain_text': 'عربى',
          'from': 'عربى',
          'to': 'عربى',
          'cc': 'عربى',
          'bcc': 'عربى',
          'subject': 'عربى',
          'send': 'عربى',
          'edit': 'عربى',
          'reply': 'عربى',
          'forward': 'عربى',
          'new_message': 'عربى',
          'account_name': 'عربى',
          'trash': 'عربى',
          'compose': 'عربى',
          'settings': 'عربى',
          'contact_us': 'عربى',
          'terms_and_condition': 'عربى',
          'undo': 'عربى',
          'accounts': 'عربى',
          'inbox': 'عربى',
        },
      };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  String get locale => GetStorage().read('language') ?? 'en';

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wahda Bank',
      translations: Lang(),
      locale: Locale(locale),
      theme: ThemeData(
        // fontFamily: 'sfp',
        textTheme: GoogleFonts.poppinsTextTheme(),
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
