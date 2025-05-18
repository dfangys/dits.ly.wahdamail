import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/utills/constants/text_strings.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class TermsAndCondition extends StatelessWidget {
  const TermsAndCondition({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          onPressed: Get.back,
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            size: 20,
          ),
          splashRadius: 24,
        ),
        title: Text(
          "Terms and Conditions",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppTheme.surfaceColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Wahda Bank Email Service",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Last Updated: May 17, 2025",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section 1
              _buildSection(
                title: "1. Acceptance of Terms",
                content: WText.policyText,
              ),

              const SizedBox(height: 24),

              // Section 2
              _buildSection(
                title: "2. Privacy and Data Protection",
                content: WText.policyText2,
              ),

              const SizedBox(height: 24),

              // Section 3
              _buildSection(
                title: "3. User Responsibilities",
                content: "Users are responsible for maintaining the confidentiality of their account information and for all activities that occur under their account. Users agree not to use the service for any illegal or unauthorized purpose. Any misuse of the service may result in immediate termination of access.",
              ),

              const SizedBox(height: 24),

              // Section 4
              _buildSection(
                title: "4. Service Limitations",
                content: "Wahda Bank reserves the right to modify, suspend, or discontinue the email service, either temporarily or permanently, at any time without notice. Wahda Bank shall not be liable to you or any third party for any modification, suspension, or discontinuance of the service.",
              ),

              const SizedBox(height: 24),

              // Section 5
              _buildSection(
                title: "5. Intellectual Property",
                content: "All content, design, graphics, compilation, magnetic translation, digital conversion, and other matters related to the email service are protected under applicable copyrights, trademarks, and other proprietary rights.",
              ),

              const SizedBox(height: 32),

              // Agreement button
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    Get.snackbar(
                      'Terms Accepted',
                      'You have accepted the terms and conditions',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.green.withOpacity(0.9),
                      colorText: Colors.white,
                      margin: const EdgeInsets.all(16),
                      borderRadius: 12,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "I Agree to Terms",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }
}
