import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:timeago/timeago.dart' as timeago;

class LanguagePage extends GetView<SettingController> {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'language'.tr,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.primary,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with explanation
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.language,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Choose your preferred language for the app interface',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Language options section
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Text(
              'available_languages'.tr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),

          // Language options card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.dividerColor.withOpacity(0.1),
              ),
            ),
            child: Column(
              children: [
                // English option
                Obx(() => _buildLanguageOption(
                  context,
                  language: 'en',
                  title: 'english'.tr,
                  subtitle: 'English',
                  flagEmoji: '🇺🇸',
                  isSelected: controller.language() == 'en',
                  onTap: () {
                    controller.language('en');
                    timeago.setDefaultLocale('en');
                    Get.updateLocale(const Locale('en'));
                    Intl.defaultLocale = 'en';
                    initializeDateFormatting('en');
                  },
                )),

                Divider(height: 1, indent: 70, color: theme.dividerColor.withOpacity(0.1)),

                // Arabic option
                Obx(() => _buildLanguageOption(
                  context,
                  language: 'ar',
                  title: 'arabic'.tr,
                  subtitle: 'العربية',
                  flagEmoji: '🇱🇾',
                  isSelected: controller.language() == 'ar',
                  onTap: () {
                    controller.language('ar');
                    timeago.setLocaleMessages('ar', timeago.ArMessages());
                    timeago.setDefaultLocale('ar');
                    Get.updateLocale(const Locale('ar'));
                    Intl.defaultLocale = 'ar';
                    initializeDateFormatting('ar');
                  },
                )),
              ],
            ),
          ),

          // Language info section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.amber[800],
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Changing the language will restart the app interface',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.amber[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
      BuildContext context, {
        required String language,
        required String title,
        required String subtitle,
        required String flagEmoji,
        required bool isSelected,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            flagEmoji,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      trailing: isSelected
          ? Icon(
        Icons.check_circle,
        color: theme.colorScheme.primary,
      )
          : Icon(
        Icons.circle_outlined,
        color: theme.colorScheme.onSurface.withOpacity(0.3),
      ),
      onTap: onTap,
    );
  }
}
