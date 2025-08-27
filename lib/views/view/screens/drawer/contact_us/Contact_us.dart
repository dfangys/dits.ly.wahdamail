// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:wahda_bank/widgets/custom_loading_button.dart';
import 'package:wahda_bank/views/compose/redesigned_compose_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatelessWidget {
  final CustomLoadingButtonController emailController = CustomLoadingButtonController();
  final CustomLoadingButtonController callController = CustomLoadingButtonController();

  ContactUsScreen({super.key});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $launchUri';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Contact Us",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.primary,
      ),
      body: SingleChildScrollView(
        child: Column(
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
                    Icons.support_agent,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'We\'re here to help! Reach out to us through any of the following methods.',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha : 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Email contact card
            Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha : 0.1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Email icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Iconsax.sms,
                        size: 40,
                        color: Colors.green,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Email address
                    const Text(
                      "Email Support",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "info@wahdabank.com",
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha : 0.7),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Email button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.email_outlined),
                        label: const Text("Send Email"),
                        onPressed: () {
                          Get.to(
                                () => const RedesignedComposeScreen(),
                            arguments: {'support': 'info@wahdabank.com'},
                          );
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
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Phone contact card
            Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha : 0.1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Phone icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Iconsax.call,
                        size: 40,
                        color: Colors.blue,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Phone number
                    const Text(
                      "Phone Support",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "+218 61 2224256",
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha : 0.7),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Call button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.call_outlined),
                        label: const Text("Call Now"),
                        onPressed: () {
                          _makePhoneCall('+21861222425');
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
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Office hours card
            Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha : 0.1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha : 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.access_time,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          "Office Hours",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _buildOfficeHoursRow("Sunday - Thursday", "8:00 AM - 3:00 PM"),
                    _buildOfficeHoursRow("Friday", "Closed"),
                    _buildOfficeHoursRow("Saturday", "9:00 AM - 1:00 PM"),
                  ],
                ),
              ),
            ),

            // Location card
            Card(
              elevation: 0,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha : 0.1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha : 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          "Head Office",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Text(
                      "Wahda Bank Headquarters\nTripoli, Libya",
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha : 0.7),
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Map button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.map_outlined),
                        label: const Text("View on Map"),
                        onPressed: () {
                          // Launch map with coordinates
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          side: BorderSide(color: theme.colorScheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficeHoursRow(String day, String hours) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          Text(
            hours,
            style: TextStyle(
              fontSize: 16,
              color: hours.contains("Closed") ? Colors.red : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
