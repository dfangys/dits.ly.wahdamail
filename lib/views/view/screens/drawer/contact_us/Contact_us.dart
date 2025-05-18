import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wahda_bank/views/authantication/screens/login/widgets/rounded_button.dart';
import 'package:wahda_bank/views/compose/compose.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class ContactUsScreen extends StatelessWidget {
  ContactUsScreen({super.key});

  final RoundedLoadingButtonController emailController = RoundedLoadingButtonController();
  final RoundedLoadingButtonController callController = RoundedLoadingButtonController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Contact Us",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppTheme.surfaceColor,
        iconTheme: IconThemeData(color: AppTheme.textPrimaryColor),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              // Header section
              Text(
                "Get in touch with us",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "We're here to help with any questions about your email service",
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Email contact card
              _buildContactCard(
                context,
                icon: WImages.contactMail,
                title: "Email Support",
                subtitle: "info@wahdabank.com",
                buttonText: "Send Email",
                buttonController: emailController,
                onPressed: () {
                  Get.to(
                        () => const ComposeScreen(),
                    arguments: {'support': 'info@wahdabank.com'},
                    transition: Transition.rightToLeft,
                    duration: const Duration(milliseconds: 300),
                  );
                  emailController.success();
                  Future.delayed(const Duration(seconds: 1), () {
                    emailController.reset();
                  });
                },
              ),

              const SizedBox(height: 20),

              // Phone contact card
              _buildContactCard(
                context,
                icon: WImages.contactPhone,
                title: "Phone Support",
                subtitle: "+218 61 2224256",
                buttonText: "Call Now",
                buttonController: callController,
                onPressed: () async {
                  final Uri phoneUri = Uri(scheme: 'tel', path: '+21861222456');
                  try {
                    if (await canLaunchUrl(phoneUri)) {
                      await launchUrl(phoneUri);
                      callController.success();
                    } else {
                      callController.error();
                      _showErrorSnackbar("Could not launch phone app");
                    }
                  } catch (e) {
                    callController.error();
                    _showErrorSnackbar("Error launching phone: $e");
                  }

                  Future.delayed(const Duration(seconds: 2), () {
                    callController.reset();
                  });
                },
              ),

              const SizedBox(height: 20),

              // Visit us card
              _buildContactCard(
                context,
                icon: WImages.contactMail, // Replace with appropriate location icon
                title: "Visit Us",
                subtitle: "Wahda Bank Headquarters, Tripoli, Libya",
                buttonText: "View on Map",
                buttonController: RoundedLoadingButtonController(),
                onPressed: () async {
                  // Open map with the bank's location
                  final Uri mapUri = Uri.parse('https://maps.google.com/?q=Wahda+Bank+Tripoli+Libya');
                  try {
                    if (await canLaunchUrl(mapUri)) {
                      await launchUrl(mapUri);
                    } else {
                      _showErrorSnackbar("Could not open maps");
                    }
                  } catch (e) {
                    _showErrorSnackbar("Error opening maps: $e");
                  }
                },
                showDivider: false,
              ),

              const SizedBox(height: 40),

              // Social media section
              Text(
                "Follow Us",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialButton(Icons.facebook, Colors.blue[700]!),
                  const SizedBox(width: 16),
                  _buildSocialButton(Icons.telegram, Colors.blue[400]!),
                  const SizedBox(width: 16),
                  _buildSocialButton(Icons.language, AppTheme.primaryColor),
                ],
              ),

              const SizedBox(height: 40),

              // Business hours
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      "Business Hours",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildBusinessHourRow("Sunday - Thursday", "8:00 AM - 3:00 PM"),
                    _buildBusinessHourRow("Friday - Saturday", "Closed"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard(
      BuildContext context, {
        required String icon,
        required String title,
        required String subtitle,
        required String buttonText,
        required RoundedLoadingButtonController buttonController,
        required VoidCallback onPressed,
        bool showDivider = true,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Icon
                Image.asset(
                  icon,
                  height: 80,
                  width: 80,
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Button
                SizedBox(
                  width: double.infinity,
                  child: WRoundedButton(
                    controller: buttonController,
                    onPress: onPressed,
                    text: buttonText,
                  ),
                ),
              ],
            ),
          ),

          // Optional divider
          if (showDivider)
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.withOpacity(0.1),
            ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, Color color) {
    return InkWell(
      onTap: () {
        // Handle social media tap
      },
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildBusinessHourRow(String day, String hours) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          Text(
            hours,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.withOpacity(0.9),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
  }
}
