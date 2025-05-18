import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/compose/compose.dart';
import 'package:wahda_bank/widgets/search/search.dart';

class MailMetaTile extends StatelessWidget {
  const MailMetaTile({super.key, required this.message, required this.isShow});
  final MimeMessage message;
  final ValueNotifier<bool> isShow;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return ValueListenableBuilder(
      valueListenable: isShow,
      builder: (context, value, child) => AnimatedCrossFade(
        firstChild: const SizedBox.shrink(),
        secondChild: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(isTablet ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section title with animation
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 10),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Email Details",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 16 : 14,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Divider with animation
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.scale(
                    scaleX: value,
                    alignment: Alignment.centerLeft,
                    child: child,
                  );
                },
                child: Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
              ),
              const SizedBox(height: 16),

              // Email metadata fields with staggered animation
              _buildAnimatedMailInfo(
                context,
                "From",
                message.from != null
                    ? message.from!.map((e) => e.email).toList()
                    : [],
                Icons.person_outline_rounded,
                delay: 100,
                isTablet: isTablet,
              ),
              _buildAnimatedMailInfo(
                context,
                "To",
                message.to != null
                    ? message.to!.map((e) => e.email).toList()
                    : [],
                Icons.people_outline_rounded,
                delay: 200,
                isTablet: isTablet,
              ),
              _buildAnimatedMailInfo(
                context,
                "Cc",
                message.cc != null
                    ? message.cc!.map((e) => e.email).toList()
                    : [],
                Icons.person_add_alt_outlined,
                delay: 300,
                isTablet: isTablet,
              ),
              _buildAnimatedMailInfo(
                context,
                "Bcc",
                message.bcc != null
                    ? message.bcc!.map((e) => e.email).toList()
                    : [],
                Icons.visibility_off_outlined,
                delay: 400,
                isTablet: isTablet,
              ),
              _buildAnimatedMailInfo(
                context,
                "Date",
                [
                  DateFormat("EEEE, MMMM d, yyyy 'at' h:mm a").format(
                    message.decodeDate() ?? DateTime.now(),
                  ),
                ],
                Icons.calendar_today_outlined,
                delay: 500,
                isTablet: isTablet,
              ),
            ],
          ),
        ),
        crossFadeState:
        value ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 200),
        sizeCurve: Curves.easeInOutCubic,
        firstCurve: Curves.easeOut,
        secondCurve: Curves.easeIn,
      ),
    );
  }

  Widget _buildAnimatedMailInfo(
      BuildContext context,
      String title,
      List<String> data,
      IconData icon, {
        required int delay,
        required bool isTablet,
      }) {
    if (data.isEmpty) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: buildMailInfo(
        context,
        title,
        data,
        icon,
        isTablet: isTablet,
      ),
    );
  }
}

Widget buildMailInfo(
    BuildContext context,
    String title,
    List<String> data,
    IconData icon, {
      required bool isTablet,
    }) {
  if (data.isEmpty) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon with container
        Container(
          width: isTablet ? 36 : 32,
          height: isTablet ? 36 : 32,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: isTablet ? 18 : 16,
            color: AppTheme.primaryColor,
          ),
        ),

        SizedBox(width: isTablet ? 16 : 12),

        // Label
        SizedBox(
          width: isTablet ? 50 : 40,
          child: Text(
            "$title:",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 15 : 14,
              color: AppTheme.textPrimaryColor,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Values
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (title == 'Date') {
                return;
              }

              // Show action sheet for email addresses
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Title
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "Options for ${data.join(', ')}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const Divider(),

                      // Actions
                      _buildActionButton(
                        icon: Icons.copy_rounded,
                        text: "Copy to Clipboard",
                        onTap: () {
                          Clipboard.setData(ClipboardData(
                            text: data.join(', '),
                          ));
                          Navigator.pop(context);

                          // Show confirmation
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle_outline, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text("Copied to clipboard"),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                      ),

                      _buildActionButton(
                        icon: Icons.edit_outlined,
                        text: "new_message".tr,
                        onTap: () {
                          Get.back();
                          Get.to(
                                () => const ComposeScreen(),
                            arguments: {"to": data.join(', ')},
                            duration: AppTheme.mediumAnimationDuration,
                          );
                        },
                      ),

                      _buildActionButton(
                        icon: Icons.search,
                        text: "search".tr,
                        onTap: () {
                          Get.back();
                          Get.to(
                                () => SearchView(),
                            arguments: {"terms": data.join(' ')},
                            duration: AppTheme.mediumAnimationDuration,
                          );
                        },
                      ),

                      // Cancel button
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: AppTheme.textPrimaryColor,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      // Safe area padding
                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: data.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    e,
                    style: TextStyle(
                      fontSize: isTablet ? 15 : 14,
                      color: title != 'Date'
                          ? AppTheme.primaryColor.withOpacity(0.8)
                          : AppTheme.textSecondaryColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        )
      ],
    ),
  );
}

Widget _buildActionButton({
  required IconData icon,
  required String text,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 16),
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textPrimaryColor,
            ),
          ),
        ],
      ),
    ),
  );
}
