import 'dart:async';
import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:get_storage/get_storage.dart';

import 'background_task_controller.dart';

/// Controller responsible for managing email contacts
class ContactController extends GetxController {
  final Logger logger = Logger();
  final getStoarage = GetStorage();

  // List of contact emails
  final RxList<String> contactEmails = <String>[].obs;

  @override
  void onInit() {
    // Load contacts from storage
    loadContacts();
    super.onInit();
  }

  /// Load contacts from storage
  void loadContacts() {
    try {
      final storedMails = getStoarage.read('mails');
      if (storedMails != null) {
        contactEmails.value = (storedMails as List).cast<String>();
      }
    } catch (e) {
      logger.e("Error loading contacts: $e");
    }
  }

  /// Store contact emails from messages
  // Changed return type to void to match original implementation
  Future<void> storeContactMails(List<MimeMessage> messages) async {
    if (Get.isRegistered<BackgroundTaskController>()) {
      Get.find<BackgroundTaskController>().queueOperation(() async => _processContactsFromMessages(messages));
    } else {
      await Future.microtask(() {
        _processContactsFromMessages(messages);
      });
    }
  }

  /// Process contacts from messages
  void _processContactsFromMessages(List<MimeMessage> messages) {
    try {
      // Get existing contacts from storage
      Set<String> mails = {};
      mails.addAll(contactEmails);

      // Process new contacts from messages
      for (var message in messages) {
        if (message.from != null) {
          for (var from in message.from!) {
            try {
              if (from.email.isNotEmpty) {
                // Store with personal name if available for better display
                String formattedAddress = from.personalName != null && from.personalName!.isNotEmpty
                    ? "${from.personalName} <${from.email}>"
                    : from.email;
                mails.add(formattedAddress);
              }
            } catch (e) {
              logger.e("Error adding contact: $e");
            }
          }
        }
      }

      // Update contacts list
      contactEmails.value = mails.toList();

      // Save updated contacts back to storage
      getStoarage.write('mails', contactEmails.toList());
    } catch (e) {
      logger.e("Error processing contacts: $e");
    }
  }

  /// Get contact suggestions based on query
  List<String> getContactSuggestions(String query) {
    if (query.isEmpty) {
      return contactEmails.take(10).toList();
    }

    final lowercaseQuery = query.toLowerCase();
    return contactEmails
        .where((email) => email.toLowerCase().contains(lowercaseQuery))
        .take(10)
        .toList();
  }

  /// Add a new contact
  void addContact(String email, [String? name]) {
    try {
      String formattedAddress = name != null && name.isNotEmpty
          ? "$name <$email>"
          : email;

      if (!contactEmails.contains(formattedAddress)) {
        contactEmails.add(formattedAddress);
        getStoarage.write('mails', contactEmails.toList());
      }
    } catch (e) {
      logger.e("Error adding contact: $e");
    }
  }

  /// Remove a contact
  void removeContact(String email) {
    try {
      contactEmails.remove(email);
      getStoarage.write('mails', contactEmails.toList());
    } catch (e) {
      logger.e("Error removing contact: $e");
    }
  }
}
