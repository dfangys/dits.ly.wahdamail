import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/utills/constants/text_strings.dart';

class TermsAndCondition extends StatelessWidget {
  const TermsAndCondition({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Terms And Conditions",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.primary,
        leading: IconButton(
          onPressed: Get.back,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with explanation
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.gavel,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Please read these terms and conditions carefully before using our services.',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha : 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Terms and conditions content
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1
                  _buildTermsSection(
                    context,
                    title: "Aliquma fringla nisi non lectus feugiat molestie",
                    content: WText.policyText,
                    sectionNumber: "1",
                  ),

                  const SizedBox(height: 24),

                  // Section 2
                  _buildTermsSection(
                    context,
                    title: "Aliquma fringla nisi non lectus feugiat molestie",
                    content: WText.policyText2,
                    sectionNumber: "2",
                  ),

                  const SizedBox(height: 24),

                  // Section 3 - Privacy Policy
                  _buildTermsSection(
                    context,
                    title: "Privacy Policy",
                    content: "Your privacy is important to us. It is Wahda Bank's policy to respect your privacy regarding any information we may collect from you across our website and mobile applications.\n\nWe only ask for personal information when we truly need it to provide a service to you. We collect it by fair and lawful means, with your knowledge and consent.",
                    sectionNumber: "3",
                  ),

                  const SizedBox(height: 24),

                  // Section 4 - Security
                  _buildTermsSection(
                    context,
                    title: "Security",
                    content: "We value your trust in providing us your personal information, thus we are striving to use commercially acceptable means of protecting it. But remember that no method of transmission over the internet, or method of electronic storage is 100% secure and reliable, and we cannot guarantee its absolute security.",
                    sectionNumber: "4",
                  ),

                  const SizedBox(height: 24),

                  // Last updated date
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.update,
                          size: 20,
                          color: theme.colorScheme.onSurface.withValues(alpha : 0.6),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Last updated: May 18, 2025",
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha : 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Accept button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "I Accept",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsSection(
      BuildContext context, {
        required String title,
        required String content,
        required String sectionNumber,
      }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with number
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  sectionNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Section content
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha : 0.7),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
