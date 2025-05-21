import 'dart:async';
import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:get_storage/get_storage.dart';

import 'background_task_controller.dart';

/// Controller responsible for managing email contacts
class ContactController extends GetxController {
  final Logger logger = Logger();
  final getStorage = GetStorage(); // Fixed typo in variable name

  // List of contact emails
  final RxList<String> contactEmails = <String>[].obs;

  // Track processing state
  final RxBool isProcessing = false.obs;

  // Background task controller for async operations
  late BackgroundTaskController _backgroundTaskController;

  @override
  void onInit() {
    super.onInit();

    // Get background task controller if available
    if (Get.isRegistered<BackgroundTaskController>()) {
      _backgroundTaskController = Get.find<BackgroundTaskController>();
    }

    // Load contacts from storage
    loadContacts();
  }

  /// Load contacts from storage with improved error handling
  void loadContacts() {
    try {
      final storedMails = getStorage.read('mails');
      if (storedMails != null) {
        contactEmails.value = (storedMails as List).cast<String>();
        logger.d("Loaded ${contactEmails.length} contacts from storage");
      }
    } catch (e) {
      logger.e("Error loading contacts: $e");
      // Initialize with empty list if loading fails
      contactEmails.value = [];
    }
  }

  /// Store contact emails from messages with improved error handling and background processing
  Future<void> storeContactMails(List<MimeMessage> messages) async {
    if (messages.isEmpty) return;

    isProcessing(true);

    try {
      if (Get.isRegistered<BackgroundTaskController>()) {
        if (_backgroundTaskController == null) {
          _backgroundTaskController = Get.find<BackgroundTaskController>();
        }

        _backgroundTaskController.queueOperation(
                () async => _processContactsFromMessages(messages),
            priority: Priority.low
        );
      } else {
        // If background task controller is not available, process directly
        await Future.microtask(() {
          _processContactsFromMessages(messages);
        });
      }
    } catch (e) {
      logger.e("Error queuing contact processing: $e");
    } finally {
      isProcessing(false);
    }
  }

  /// Process contacts from messages with improved error handling and deduplication
  void _processContactsFromMessages(List<MimeMessage> messages) {
    try {
      // Get existing contacts from storage
      Set<String> mails = {};
      mails.addAll(contactEmails);

      // Process new contacts from messages
      for (var message in messages) {
        _extractContactsFromMessage(message, mails);
      }

      // Update contacts list
      contactEmails.value = mails.toList();

      // Save updated contacts back to storage
      getStorage.write('mails', contactEmails.toList());

      logger.d("Processed contacts from ${messages.length} messages, total contacts: ${contactEmails.length}");
    } catch (e) {
      logger.e("Error processing contacts: $e");
    }
  }

  /// Extract contacts from a single message
  void _extractContactsFromMessage(MimeMessage message, Set<String> contactSet) {
    try {
      // Process From addresses
      if (message.from != null) {
        for (var from in message.from!) {
          _addMailAddressToSet(from, contactSet);
        }
      }

      // Process To addresses
      if (message.to != null) {
        for (var to in message.to!) {
          _addMailAddressToSet(to, contactSet);
        }
      }

      // Process CC addresses
      if (message.cc != null) {
        for (var cc in message.cc!) {
          _addMailAddressToSet(cc, contactSet);
        }
      }

      // Process Reply-To addresses
      if (message.replyTo != null) {
        for (var replyTo in message.replyTo!) {
          _addMailAddressToSet(replyTo, contactSet);
        }
      }
    } catch (e) {
      logger.e("Error extracting contacts from message: $e");
    }
  }

  /// Add a mail address to the contact set
  void _addMailAddressToSet(MailAddress address, Set<String> contactSet) {
    try {
      if (address.email.isNotEmpty) {
        // Store with personal name if available for better display
        String formattedAddress = address.personalName != null && address.personalName!.isNotEmpty
            ? "${address.personalName} <${address.email}>"
            : address.email;
        contactSet.add(formattedAddress);
      }
    } catch (e) {
      logger.e("Error adding contact address: $e");
    }
  }

  /// Get contact suggestions based on query with improved matching
  List<String> getContactSuggestions(String query) {
    if (query.isEmpty) {
      return contactEmails.take(10).toList();
    }

    final lowercaseQuery = query.toLowerCase();

    // First try exact matches at the beginning of the string (higher priority)
    final exactMatches = contactEmails
        .where((email) => email.toLowerCase().startsWith(lowercaseQuery))
        .toList();

    // If we have enough exact matches, return those
    if (exactMatches.length >= 5) {
      return exactMatches.take(10).toList();
    }

    // Otherwise, add partial matches
    final partialMatches = contactEmails
        .where((email) => email.toLowerCase().contains(lowercaseQuery) &&
        !exactMatches.contains(email))
        .take(10 - exactMatches.length)
        .toList();

    // Combine both lists
    return [...exactMatches, ...partialMatches];
  }

  /// Add a new contact with validation
  void addContact(String email, [String? name]) {
    try {
      // Basic email validation
      if (!email.contains('@') || !email.contains('.')) {
        logger.w("Invalid email format: $email");
        return;
      }

      String formattedAddress = name != null && name.isNotEmpty
          ? "$name <$email>"
          : email;

      if (!contactEmails.contains(formattedAddress)) {
        contactEmails.add(formattedAddress);
        getStorage.write('mails', contactEmails.toList());
        logger.d("Added new contact: $formattedAddress");
      }
    } catch (e) {
      logger.e("Error adding contact: $e");
    }
  }

  /// Remove a contact
  void removeContact(String email) {
    try {
      contactEmails.remove(email);
      getStorage.write('mails', contactEmails.toList());
      logger.d("Removed contact: $email");
    } catch (e) {
      logger.e("Error removing contact: $e");
    }
  }

  /// Clear all contacts
  void clearContacts() {
    try {
      contactEmails.clear();
      getStorage.write('mails', []);
      logger.d("Cleared all contacts");
    } catch (e) {
      logger.e("Error clearing contacts: $e");
    }
  }

  /// Import contacts from a list of strings
  void importContacts(List<String> emails) {
    try {
      Set<String> uniqueEmails = Set.from(contactEmails);
      uniqueEmails.addAll(emails);

      contactEmails.value = uniqueEmails.toList();
      getStorage.write('mails', contactEmails.toList());

      logger.d("Imported ${emails.length} contacts, total contacts: ${contactEmails.length}");
    } catch (e) {
      logger.e("Error importing contacts: $e");
    }
  }
}
