import 'dart:async';
import 'dart:math' as math;
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wahda_bank/app/controllers/mail_count_controller.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/services/background_service.dart';
import 'package:flutter/foundation.dart';

import 'contact_controller.dart';
import 'email_storage_controller.dart';
import 'mailbox_list_controller.dart';

/// Controller responsible for fetching emails from server and local storage
class EmailFetchController extends GetxController {
  final Logger logger = Logger();
  final getStoarage = GetStorage();

  // Loading states
  final RxBool isBusy = true.obs;
  final RxBool isBoxBusy = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isRefreshing = false.obs;

  // Email data
  final RxMap<Mailbox, List<MimeMessage>> emails = <Mailbox, List<MimeMessage>>{}.obs;

  // Enhanced stream controller for reactive updates
  final _emailsSubject = BehaviorSubject<Map<Mailbox, List<MimeMessage>>>();
  Stream<Map<Mailbox, List<MimeMessage>>> get emailsStream => _emailsSubject.stream;

  // Track last fetched UID for each mailbox
  final Map<Mailbox, int> _lastFetchedUids = {};

  // Track if initial load has been done for each mailbox
  final Map<Mailbox, bool> _initialLoadDone = {};

  // Track pagination for each mailbox
  final Map<Mailbox, int> _currentPage = {};
  final int pageSize = 20;

  // Debounce timer for UI updates
  Timer? _debounceTimer;

  // Services and controllers
  late MailService mailService;

  @override
  void onInit() async {
    try {
      mailService = MailService.instance;

      // Initialize the emails subject
      if (!_emailsSubject.hasValue) {
        _emailsSubject.add(emails);
      }

      isBusy(false);
      super.onInit();
    } catch (e) {
      logger.e(e);
    }
  }

  /// Get emails for a specific mailbox
  List<MimeMessage> getEmailsForMailbox(Mailbox mailbox) {
    return emails[mailbox] ?? [];
  }

  /// Get emails for the currently selected mailbox
  List<MimeMessage> get boxMails =>
      emails[mailService.client.selectedMailbox] ?? [];

  /// Load emails for a specific mailbox
  Future<void> loadEmailsForBox(Mailbox mailbox) async {
    if (!mailService.client.isConnected) {
      await mailService.connect();
    }
    await mailService.client.selectMailbox(mailbox);

    // Check if this is the first load or a refresh
    if (!(_initialLoadDone[mailbox] ?? false)) {
      await fetchMailbox(mailbox);
      _initialLoadDone[mailbox] = true;
    } else {
      // For subsequent loads, only fetch new emails
      await fetchNewEmails(mailbox);
    }
  }

  /// Load more emails when scrolling down (pagination)
  Future<void> loadMoreEmails(Mailbox mailbox) async {
    if (isLoadingMore.value || isBoxBusy.value) return;

    isLoadingMore(true);

    try {
      final currentPage = _currentPage[mailbox] ?? 1;
      final nextPage = currentPage + 1;

      // Calculate start and end indices for this page
      final startIndex = (nextPage - 1) * pageSize + 1;
      final endIndex = startIndex + pageSize - 1;

      // Check if we've reached the end
      if (startIndex > mailbox.messagesExists) {
        isLoadingMore(false);
        return;
      }

      // Create sequence for this page
      final sequence = MessageSequence.fromRange(
          mailbox.messagesExists - endIndex + 1 > 0 ? mailbox.messagesExists - endIndex + 1 : 1,
          mailbox.messagesExists - startIndex + 1 > 0 ? mailbox.messagesExists - startIndex + 1 : 1
      );

      // Fetch messages for this page
      final messages = await queue(sequence);

      if (messages.isNotEmpty) {
        // Sort by date (newest first)
        messages.sort((a, b) {
          final dateA = a.decodeDate() ?? DateTime.now();
          final dateB = b.decodeDate() ?? DateTime.now();
          return dateB.compareTo(dateA);
        });

        // Add to emails list
        if (emails[mailbox] == null) {
          emails[mailbox] = <MimeMessage>[];
        }

        // Check for duplicates before adding
        final existingUids = emails[mailbox]!.map((m) => m.uid).toSet();
        final newMessages = messages.where((m) => !existingUids.contains(m.uid)).toList();

        if (newMessages.isNotEmpty) {
          emails[mailbox]!.addAll(newMessages);

          // Sort all messages by date
          emails[mailbox]!.sort((a, b) {
            final dateA = a.decodeDate() ?? DateTime.now();
            final dateB = b.decodeDate() ?? DateTime.now();
            return dateB.compareTo(dateA);
          });

          emails.refresh(); // Force UI update
          notifyEmailsChanged(); // Update stream with debouncing

          // Save to local storage in background
          if (Get.isRegistered<EmailStorageController>()) {
            Get.find<EmailStorageController>().saveMessagesInBackground(newMessages, mailbox);
          }
        }

        // Update current page
        _currentPage[mailbox] = nextPage;
      }
    } catch (e) {
      logger.e("Error loading more emails: $e");
    } finally {
      isLoadingMore(false);
    }
  }

  /// Fetch only new emails since last fetch
  Future<void> fetchNewEmails(Mailbox mailbox) async {
    isBoxBusy(true);
    isRefreshing(true); // Set refreshing state to true

    try {
      int lastUid = _lastFetchedUids[mailbox] ?? 0;

      if (mailbox.uidNext != null && mailbox.isInbox) {
        await GetStorage().write(
          BackgroundService.keyInboxLastUid,
          mailbox.uidNext,
        );
      }

      // If we have no last UID, do a full fetch
      if (lastUid == 0) {
        await fetchMailbox(mailbox);
        return;
      }

      logger.d('Fetching new emails since UID $lastUid for ${mailbox.name}');

      // First try to load from local storage
      if (Get.isRegistered<EmailStorageController>()) {
      }

      // Then fetch from server
      if (mailService.client.isConnected) {
        // Create a sequence for UIDs greater than lastUid
        final sequence = MessageSequence();

        // Add UIDs from lastUid+1 to uidNext
        if (mailbox.uidNext != null && mailbox.uidNext! > lastUid) {
          for (int uid = lastUid + 1; uid < mailbox.uidNext!; uid++) {
            sequence.add(uid);
          }
        }

        if (sequence.isNotEmpty) {
          final newServerMessages = await mailService.client.fetchMessageSequence(
            sequence,
            fetchPreference: FetchPreference.envelope,
          );

          if (newServerMessages.isNotEmpty) {
            // Sort by date (newest first)
            newServerMessages.sort((a, b) {
              final dateA = a.decodeDate() ?? DateTime.now();
              final dateB = b.decodeDate() ?? DateTime.now();
              return dateB.compareTo(dateA);
            });

            // Update last fetched UID
            for (var msg in newServerMessages) {
              if (msg.uid != null && msg.uid! > lastUid) {
                lastUid = msg.uid!;
              }
            }
            _lastFetchedUids[mailbox] = lastUid;

            // Save to local storage in background
            if (Get.isRegistered<EmailStorageController>()) {
              Get.find<EmailStorageController>().saveMessagesInBackground(newServerMessages, mailbox);
            }

            // Add to emails list
            if (emails[mailbox] == null) {
              emails[mailbox] = <MimeMessage>[];
            }

            // Check for duplicates before adding
            final existingUids = emails[mailbox]!.map((m) => m.uid).toSet();
            final uniqueNewMessages = newServerMessages.where((m) => !existingUids.contains(m.uid)).toList();

            if (uniqueNewMessages.isNotEmpty) {
              emails[mailbox]!.insertAll(0, uniqueNewMessages); // Insert at beginning (newest first)

              // Re-sort all messages by date
              emails[mailbox]!.sort((a, b) {
                final dateA = a.decodeDate() ?? DateTime.now();
                final dateB = b.decodeDate() ?? DateTime.now();
                return dateB.compareTo(dateA);
              });

              emails.refresh(); // Force UI update
              notifyEmailsChanged(); // Update stream with debouncing

              // Show notification of new emails
              if (uniqueNewMessages.isNotEmpty) {
                Get.showSnackbar(
                  GetSnackBar(
                    message: 'Received ${uniqueNewMessages.length} new email(s)',
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          }
        }
      }

      if (mailbox.isInbox) {
        // Use platform-safe background service check
        _safeCheckForNewMail(false);
      }

      // Update unread count
      updateUnreadCount(mailbox);

      // Store contact emails
      if (Get.isRegistered<ContactController>()) {
        await Get.find<ContactController>().storeContactMails(emails[mailbox]!);
      }
    } catch (e) {
      logger.e("Error fetching new emails: $e");
      // Show error message to user
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error refreshing emails: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      isBoxBusy(false);
      isRefreshing(false); // Set refreshing state to false when done
    }
  }

  /// Fetch mailbox contents
  Future<void> fetchMailbox(Mailbox mailbox) async {
    isBoxBusy(true);
    isRefreshing(true); // Set refreshing state to true

    try {
      int max = mailbox.messagesExists;
      if (mailbox.uidNext != null && mailbox.isInbox) {
        await GetStorage().write(
          BackgroundService.keyInboxLastUid,
          mailbox.uidNext,
        );
      }

      if (max == 0) {
        isBoxBusy(false);
        isRefreshing(false); // Set refreshing state to false
        return;
      }

      if (emails[mailbox] == null) {
        emails[mailbox] = <MimeMessage>[];
      }

      // Only clear emails on first load, not on refresh
      if (!(_initialLoadDone[mailbox] ?? false)) {
        _currentPage[mailbox] = 1;
        emails[mailbox]!.clear();
        emails.refresh(); // Force UI update
        notifyEmailsChanged(); // Update stream with debouncing
      }

      // Initialize storage for this mailbox if needed
      if (Get.isRegistered<EmailStorageController>()) {
        await Get.find<EmailStorageController>().initializeMailboxStorage(mailbox);
      }

      // Load messages in smaller batches to prevent UI blocking
      const int batchSize = 20; // Define constant batch size
      int loadedCount = 0;
      int highestUid = 0;

      // Calculate how many messages to load initially (first page)
      // For initial load, fetch more messages to ensure we have enough data
      final initialLoadCount = (_initialLoadDone[mailbox] ?? false)
          ? math.min(batchSize, max)
          : math.min(batchSize * 3, max); // Load more on first fetch

      // Load messages from newest to oldest
      final startIndex = max - initialLoadCount + 1 > 0 ? max - initialLoadCount + 1 : 1;
      final endIndex = max;

      // Always fetch from server first to ensure we have data
      List<MimeMessage> newMessages = await queue(
          MessageSequence.fromRange(startIndex, endIndex)
      );

      if (newMessages.isNotEmpty) {
        // Sort by date (newest first)
        newMessages.sort((a, b) {
          final dateA = a.decodeDate() ?? DateTime.now();
          final dateB = b.decodeDate() ?? DateTime.now();
          return dateB.compareTo(dateA);
        });

        // Track highest UID for incremental fetching
        for (var msg in newMessages) {
          if (msg.uid != null && msg.uid! > highestUid) {
            highestUid = msg.uid!;
          }
        }

        // Update last fetched UID for incremental updates
        if (highestUid > (_lastFetchedUids[mailbox] ?? 0)) {
          _lastFetchedUids[mailbox] = highestUid;
        }

        // Add messages to the list
        // Check for duplicates before adding
        final existingUids = emails[mailbox]!.map((m) => m.uid).toSet();
        final uniqueNewMessages = newMessages.where((m) => !existingUids.contains(m.uid)).toList();

        if (uniqueNewMessages.isNotEmpty) {
          emails[mailbox]!.addAll(uniqueNewMessages);

          // Sort all messages by date
          emails[mailbox]!.sort((a, b) {
            final dateA = a.decodeDate() ?? DateTime.now();
            final dateB = b.decodeDate() ?? DateTime.now();
            return dateB.compareTo(dateA);
          });

          emails.refresh(); // Force UI update
          notifyEmailsChanged(); // Update stream with debouncing

          // Save to local storage in background
          if (Get.isRegistered<EmailStorageController>()) {
            Get.find<EmailStorageController>().saveMessagesInBackground(uniqueNewMessages, mailbox);
          }

          loadedCount += uniqueNewMessages.length;
        }
      }

      // Try to load additional messages from local storage if needed
      if (loadedCount < initialLoadCount && Get.isRegistered<EmailStorageController>()) {
        final messages = await Get.find<EmailStorageController>().loadMessageEnvelopes(
            mailbox,
            MessageSequence.fromRange(startIndex, endIndex)
        );

        if (messages.isNotEmpty) {
          // Sort by date (newest first)
          messages.sort((a, b) {
            final dateA = a.decodeDate() ?? DateTime.now();
            final dateB = b.decodeDate() ?? DateTime.now();
            return dateB.compareTo(dateA);
          });

          // Check for duplicates before adding
          final existingUids = emails[mailbox]!.map((m) => m.uid).toSet();
          final uniqueMessages = messages.where((m) => !existingUids.contains(m.uid)).toList();

          if (uniqueMessages.isNotEmpty) {
            emails[mailbox]!.addAll(uniqueMessages);
            emails.refresh(); // Force UI update
            notifyEmailsChanged(); // Update stream with debouncing
          }
        }
      }

      if (mailbox.isInbox) {
        // Use platform-safe background service check
        _safeCheckForNewMail(false);
      }

      // Update unread count
      updateUnreadCount(mailbox);

      // Store contact emails
      if (Get.isRegistered<ContactController>()) {
        await Get.find<ContactController>().storeContactMails(emails[mailbox]!);
      }
    } catch (e) {
      logger.e("Error fetching mailbox: $e");
      // Show error message to user
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error loading emails: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      isBoxBusy(false);
      isRefreshing(false); // Set refreshing state to false when done
    }
  }

  /// Platform-safe method to check for new mail
  void _safeCheckForNewMail(bool isBackground) {
    try {
      // Skip background service on iOS and web
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          kIsWeb) {
        logger.d("Skipping background service on unsupported platform");
        return;
      }

      // Only call on Android
      if (defaultTargetPlatform == TargetPlatform.android) {
        BackgroundService.checkForNewMail(isBackground);
      }
    } catch (e) {
      logger.e("Error checking for new mail: $e");
    }
  }

  /// Queue message fetch with retry
  Future<List<MimeMessage>> queue(MessageSequence sequence) async {
    try {
      return await mailService.client.fetchMessageSequence(
        sequence,
        fetchPreference: FetchPreference.envelope,
      );
    } catch (e) {
      logger.e("Error fetching message sequence: $e");

      // Retry once after reconnecting
      try {
        await mailService.connect();
        return await mailService.client.fetchMessageSequence(
          sequence,
          fetchPreference: FetchPreference.envelope,
        );
      } catch (e) {
        logger.e("Error retrying fetch: $e");
        return [];
      }
    }
  }

  /// Update unread count for a mailbox
  void updateUnreadCount(Mailbox mailbox) {
    if (Get.isRegistered<MailCountController>()) {
      final countController = Get.find<MailCountController>();
      String key = "${mailbox.name.toLowerCase()}_count";
      countController.counts[key] =
          emails[mailbox]?.where((e) => !e.isSeen).length ?? 0;
    }
  }

  /// Handle incoming mail (for push notifications)
  Future<void> handleIncomingMail(MimeMessage message, [Mailbox? mailbox]) async {
    // If mailbox is not provided, use the inbox
    final targetMailbox = mailbox ?? Get.find<MailboxListController>().mailBoxInbox;

    // Add new message to the mailbox
    if (emails[targetMailbox] == null) {
      emails[targetMailbox] = <MimeMessage>[];
    }

    // Check for duplicates
    final existingUids = emails[targetMailbox]!.map((m) => m.uid).toSet();
    if (!existingUids.contains(message.uid)) {
      emails[targetMailbox]!.add(message);

      // Sort by date
      emails[targetMailbox]!.sort((a, b) {
        final dateA = a.decodeDate() ?? DateTime.now();
        final dateB = b.decodeDate() ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      emails.refresh();
      notifyEmailsChanged(); // Update stream with debouncing

      // Update unread count
      updateUnreadCount(targetMailbox);

      // Save to storage
      if (Get.isRegistered<EmailStorageController>()) {
        Get.find<EmailStorageController>().saveMessagesInBackground([message], targetMailbox);
      }
    }
  }

  /// Notify listeners with debouncing to prevent UI jank
  void notifyEmailsChanged() {
    // Cancel existing timer
    _debounceTimer?.cancel();

    // Set new timer
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (!_emailsSubject.isClosed) {
        _emailsSubject.add(emails);
      }
    });
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    _emailsSubject.close();
    super.onClose();
  }
}
