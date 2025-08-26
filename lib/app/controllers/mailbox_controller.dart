import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart';
import 'package:wahda_bank/app/controllers/mail_count_controller.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/models/sqlite_draft_repository.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/services/cache_manager.dart';
import 'package:wahda_bank/services/realtime_update_service.dart';
import 'package:wahda_bank/services/background_service.dart';
import 'package:wahda_bank/views/compose/models/draft_model.dart';
import 'package:wahda_bank/widgets/progress_indicator_widget.dart';
import 'package:wahda_bank/views/box/mailbox_view.dart';
import 'package:wahda_bank/views/settings/data/swap_data.dart';
import 'package:workmanager/workmanager.dart';
import '../../services/mail_service.dart';
import '../../views/authantication/screens/login/login.dart';
import '../../views/view/models/box_model.dart';

class MailBoxController extends GetxController {
  late MailService mailService;
  final RxBool isBusy = true.obs;
  final RxBool isBoxBusy = true.obs;
  final getStoarage = GetStorage();

  // Performance optimization services
  final CacheManager cacheManager = CacheManager.instance;
  final RealtimeUpdateService realtimeService = RealtimeUpdateService.instance;

  // Replace Hive storage with SQLite storage
  final RxMap<Mailbox, SQLiteMailboxMimeStorage> mailboxStorage =
      <Mailbox, SQLiteMailboxMimeStorage>{}.obs;
  final RxMap<Mailbox, List<MimeMessage>> emails =
      <Mailbox, List<MimeMessage>>{}.obs;

  // Real-time update observables
  final RxMap<String, int> unreadCounts = <String, int>{}.obs;
  final RxSet<String> flaggedMessages = <String>{}.obs;

  // Track current mailbox to fix fetch error when switching
  final Rx<Mailbox?> _currentMailbox = Rx<Mailbox?>(null);
  Mailbox? get currentMailbox => _currentMailbox.value;
  set currentMailbox(Mailbox? value) => _currentMailbox.value = value;

  List<MimeMessage> get boxMails =>
      emails[currentMailbox ?? mailService.client.selectedMailbox] ?? [];

  SettingController settingController = Get.find<SettingController>();

  Mailbox mailBoxInbox = Mailbox(
    encodedName: 'inbox',
    encodedPath: 'inbox',
    flags: [],
    pathSeparator: '',
  );

  final Logger logger = Logger();
  RxList<Mailbox> mailboxes = <Mailbox>[].obs;

  // CRITICAL FIX: Add getter for drafts mailbox using proper enough_mail API
  Mailbox? get draftsMailbox {
    try {
      return mailboxes.firstWhere(
        (mailbox) => mailbox.isDrafts, // Use proper enough_mail API
      );
    } catch (e) {
      logger.w("Drafts mailbox not found: $e");
      return null;
    }
  }

  // CRITICAL FIX: Add method to switch to drafts
  Future<void> switchToDrafts() async {
    final drafts = draftsMailbox;
    if (drafts != null) {
      currentMailbox = drafts;
      await loadEmailsForBox(drafts);
      update(); // Force UI update
    } else {
      logger.e("Cannot switch to drafts: mailbox not found");
      Get.snackbar(
        'Error',
        'Drafts mailbox not found',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // PROPER ENOUGH_MAIL API: Save draft using the correct API
  Future<bool> saveDraftMessage(MimeMessage message) async {
    try {
      final drafts = draftsMailbox;
      if (drafts == null) {
        logger.e("Cannot save draft: drafts mailbox not found");
        return false;
      }

      // Use proper enough_mail API to save draft
      final result = await mailService.client.saveDraftMessage(
        message,
        draftsMailbox: drafts,
      );

      if (result != null) {
        logger.i("Draft saved successfully with target sequence: ${result.targetSequence}");
        
        // Refresh drafts to show the new draft
        if (currentMailbox?.isDrafts == true) {
          await loadEmailsForBox(drafts);
        }
        
        return true;
      } else {
        logger.e("Failed to save draft: no response code returned");
        return false;
      }
    } catch (e) {
      logger.e("Error saving draft: $e");
      Get.snackbar(
        'Error Saving Draft',
        'Failed to save draft: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  List<String> predefinedOrder = [
    'inbox',
    'sent',
    'drafts',
    'trash',
    'junk',
    'spam',
    'archive',
    'outbox',
  ];

  final RxList<Mailbox> mailBoxes = <Mailbox>[].obs;

  void sortMailboxes() {
    mailBoxes.sort((a, b) {
      int indexA = predefinedOrder.indexOf(a.name.toLowerCase());
      int indexB = predefinedOrder.indexOf(b.name.toLowerCase());
        // Handle cases where the item is not in the predefined order
        if (indexA == -1) indexA = predefinedOrder.length;
        if (indexB == -1) indexB = predefinedOrder.length;
        // Compare based on the indices
        return indexA.compareTo(indexB);
      });
  }

  @override
  void onInit() async {
    try {
      mailService = MailService.instance;
      await mailService.init();
      await loadMailBoxes();
      super.onInit();
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> initInbox() async {
    try {
      mailBoxInbox = mailboxes.firstWhere(
            (element) => element.isInbox,
        orElse: () => mailboxes.first,
      );
      await loadEmailsForBox(mailBoxInbox);
    } catch (e) {
      logger.e("Error in initInbox: $e");
      // Reset loading state in case of error
      isBoxBusy(false);
    }
  }

  Future loadMailBoxes() async {
    try {
      List b = getStoarage.read('boxes') ?? [];
      if (b.isEmpty) {
        await mailService.connect();
        mailboxes(await mailService.client.listMailboxes());
      } else {
        mailboxes(
          b.map((e) => BoxModel.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
      for (var mailbox in mailboxes) {
        if (mailboxStorage[mailbox] != null) continue;
        mailboxStorage[mailbox] = SQLiteMailboxMimeStorage(
          mailAccount: mailService.account,
          mailbox: mailbox,
        );
        emails[mailbox] = <MimeMessage>[];
        await mailboxStorage[mailbox]!.init();
      }
      isBusy(false);
      await initInbox();
    } catch (e) {
      logger.e("Error in loadMailBoxes: $e");
      isBusy(false);
      // Show error to user
      Get.snackbar(
        'Error',
        'Failed to load mailboxes. Please check your connection and try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> loadEmailsForBox(Mailbox mailbox) async {
    // Check if we have cached emails first (moved outside try block for scope)
    final hasExistingEmails = emails[mailbox] != null && emails[mailbox]!.isNotEmpty;
    
    try {
      // Only show progress indicator if this is the first time loading (no cached emails)
      if (!hasExistingEmails && Get.isRegistered<EmailDownloadProgressController>()) {
        final progressController = Get.find<EmailDownloadProgressController>();
        progressController.show(
          title: 'Loading Emails',
          subtitle: 'Connecting to ${mailbox.name}...',
          indeterminate: true,
        );
      }

      isBoxBusy(true);
      
      // Set current mailbox to fix fetch error when switching
      currentMailbox = mailbox;

      // PERFORMANCE FIX: If emails already exist, just return them (use cache)
      if (hasExistingEmails) {
        logger.i("Using cached emails for ${mailbox.name} (${emails[mailbox]!.length} messages)");
        return;
      }

      // Check connection with shorter timeout
      if (!mailService.client.isConnected) {
        if (!hasExistingEmails && Get.isRegistered<EmailDownloadProgressController>()) {
          final progressController = Get.find<EmailDownloadProgressController>();
          progressController.updateStatus('Connecting to mail server...');
        }
        
        await mailService.connect().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException("Connection timeout", const Duration(seconds: 10));
          },
        );
      }

      // Select mailbox with timeout
      if (!hasExistingEmails && Get.isRegistered<EmailDownloadProgressController>()) {
        final progressController = Get.find<EmailDownloadProgressController>();
        progressController.updateStatus('Selecting mailbox ${mailbox.name}...');
      }
      
      await mailService.client.selectMailbox(mailbox).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException("Mailbox selection timeout", const Duration(seconds: 10));
        },
      );
      
      // Fetch mailbox with longer timeout but better error handling
      if (!hasExistingEmails && Get.isRegistered<EmailDownloadProgressController>()) {
        final progressController = Get.find<EmailDownloadProgressController>();
        progressController.updateStatus('Fetching emails from ${mailbox.name}...');
      }
      
      await fetchMailbox(mailbox).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          logger.e("Timeout while fetching mailbox: ${mailbox.name}");
          throw TimeoutException("Loading emails timed out", const Duration(seconds: 45));
        },
      );
    } catch (e) {
      logger.e("Error selecting mailbox: $e");
      
      // Only retry if it's not a timeout from our own operations
      if (e is! TimeoutException) {
        try {
          if (!hasExistingEmails && Get.isRegistered<EmailDownloadProgressController>()) {
            final progressController = Get.find<EmailDownloadProgressController>();
            progressController.updateStatus('Retrying connection...');
          }
          
          // Shorter retry timeout
          await mailService.connect().timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              throw TimeoutException("Reconnection timeout", const Duration(seconds: 8));
            },
          );
          
          await mailService.client.selectMailbox(mailbox).timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              throw TimeoutException("Mailbox selection timeout on retry", const Duration(seconds: 8));
            },
          );
          
          // PERFORMANCE FIX: Use forceRefresh on retry to ensure fresh data
          await fetchMailbox(mailbox, forceRefresh: true).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              logger.e("Timeout while fetching mailbox on retry: ${mailbox.name}");
              throw TimeoutException("Loading emails timed out on retry", const Duration(seconds: 30));
            },
          );
        } catch (retryError) {
          logger.e("Failed to reconnect and select mailbox: $retryError");
          // Show error to user
          Get.snackbar(
            'Connection Error',
            'Failed to load emails. Please check your connection and try again.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        // It's a timeout, show appropriate message
        Get.snackbar(
          'Timeout Error',
          'Loading emails is taking too long. Please try again.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      // Always reset loading state
      isBoxBusy(false);
      
      // Hide progress indicator only if it was shown (visible)
      if (Get.isRegistered<EmailDownloadProgressController>()) {
        final progressController = Get.find<EmailDownloadProgressController>();
        if (progressController.isVisible) {
          progressController.hide();
        }
      }
    }
  }

  // Pagination for emails
  int page = 1;
  int pageSize = 10; // Reduced from 20 to prevent timeouts

  Future<void> fetchMailbox(Mailbox mailbox, {bool forceRefresh = false}) async {
    try {
      // Ensure we're working with the correct mailbox
      if (currentMailbox != mailbox) {
        currentMailbox = mailbox;
      }

      // Special handling for draft mailbox using proper enough_mail API
      if (mailbox.isDrafts) {
        await _loadDraftsFromServer(mailbox);
        return;
      }

      int max = mailbox.messagesExists;
      if (mailbox.uidNext != null && mailbox.isInbox) {
        await GetStorage().write(
          BackgroundService.keyInboxLastUid,
          mailbox.uidNext,
        );
      }
      
      if (max == 0) {
        // No messages, but still update the storage to trigger UI update
        if (emails[mailbox] == null) {
          emails[mailbox] = <MimeMessage>[];
        }
        if (mailboxStorage[mailbox] != null) {
          await mailboxStorage[mailbox]!.saveMessageEnvelopes([]);
        }
        return;
      }
      
      // Initialize emails list if not exists
      if (emails[mailbox] == null) {
        emails[mailbox] = <MimeMessage>[];
      }

      // PERFORMANCE FIX: Only clear and refetch if forced or no emails cached
      if (!forceRefresh && emails[mailbox]!.isNotEmpty) {
        logger.i("Using cached emails for ${mailbox.name} (${emails[mailbox]!.length} messages)");
        return; // Use cached emails
      }

      // Clear only when actually refreshing
      if (forceRefresh) {
        emails[mailbox]!.clear();
        logger.i("Force refresh: cleared cached emails for ${mailbox.name}");
      }

      // Initialize storage with timeout
      if (mailboxStorage[mailbox] == null) {
        mailboxStorage[mailbox] = SQLiteMailboxMimeStorage(
          mailAccount: mailService.account,
          mailbox: mailbox,
        );
        await mailboxStorage[mailbox]!.init().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException("Database initialization timeout", const Duration(seconds: 10));
          },
        );
      }

      // PERFORMANCE OPTIMIZATION: Use larger batch sizes and fewer requests
      int loaded = 0;
      int maxToLoad = max > 100 ? 100 : max; // Load up to 100 recent messages
      int batchSize = 50; // Increased from 10 to 50 for better performance
      
      while (loaded < maxToLoad) {
        int currentBatchSize = batchSize;
        if (loaded + currentBatchSize > maxToLoad) {
          currentBatchSize = maxToLoad - loaded;
        }
        
        // Load from the most recent messages (highest sequence numbers)
        int start = max - loaded - currentBatchSize + 1;
        int end = max - loaded;
        
        // Ensure valid range
        if (start < 1) start = 1;
        if (end < start) break;
        
        MessageSequence sequence;
        try {
          sequence = MessageSequence.fromRange(start, end);
        } catch (e) {
          logger.e("Error creating sequence for range $start:$end: $e");
          break;
        }
        
        try {
          // PERFORMANCE FIX: Try database first, then network if needed
          List<MimeMessage> messages = [];
          
          // Try to load from database first
          try {
            messages = await mailboxStorage[mailbox]!.loadMessageEnvelopes(sequence).timeout(
              const Duration(seconds: 10),
            );
          } catch (e) {
            logger.w("Database load failed, trying network: $e");
          }
          
          // If not in database, fetch from network
          if (messages.isEmpty) {
            messages = await queue(sequence).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw TimeoutException("Network fetch timeout", const Duration(seconds: 30));
              },
            );
            
            // Save to database for future use (fire and forget)
            if (messages.isNotEmpty) {
              mailboxStorage[mailbox]!.saveMessageEnvelopes(messages).catchError((e) {
                logger.w("Database save failed: $e");
              });
            }
          }
          
          if (messages.isNotEmpty) {
            emails[mailbox]!.addAll(messages);
            loaded += messages.length;
            logger.i("Loaded batch: ${messages.length} messages (total: ${emails[mailbox]!.length})");
          } else {
            // No more messages to load
            break;
          }
        } catch (e) {
          logger.e("Error loading messages for sequence $start:$end: $e");
          // Continue with next batch instead of failing completely
          loaded += currentBatchSize;
        }
      }
      
      // Sort messages by date (newest first) for better UX
      if (emails[mailbox]!.isNotEmpty) {
        emails[mailbox]!.sort((a, b) {
          final dateA = a.decodeDate();
          final dateB = b.decodeDate();
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA); // Newest first
        });
      }
      
      logger.i("Finished loading ${emails[mailbox]!.length} emails for ${mailbox.name}");
      
      // Update background service for inbox
      if (mailbox.isInbox) {
        try {
          BackgroundService.checkForNewMail(false);
        } catch (e) {
          logger.w("Background service error: $e");
          // Continue without background service
        }
      }
      
      // Update unread count
      if (Get.isRegistered<MailCountController>()) {
        final countControll = Get.find<MailCountController>();
        String key = "${mailbox.name.toLowerCase()}_count";
        countControll.counts[key] =
            emails[mailbox]!.where((e) => !e.isSeen).length;
      }
      
      storeContactMails(emails[mailbox]!);
    } catch (e) {
      logger.e("Error in fetchMailbox: $e");
      // Don't rethrow, let the calling method handle the error
    }
  }

  // Enhanced refresh method for optimized loading
  Future<void> refreshMailbox(Mailbox mailbox) async {
    try {
      isBoxBusy(true);
      
      // Reset pagination
      page = 1;
      
      // PERFORMANCE FIX: Use forceRefresh parameter instead of manual clearing
      await fetchMailbox(mailbox, forceRefresh: true);
    } catch (e) {
      logger.e("Error refreshing mailbox: $e");
      Get.snackbar(
        'Refresh Error',
        'Failed to refresh emails. Please try again.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isBoxBusy(false);
    }
  }

  // Load more emails for pagination
  Future<void> loadMoreEmails(Mailbox mailbox, int pageNumber) async {
    try {
      if (isBoxBusy.value) return; // Prevent multiple simultaneous loads
      
      // Set current mailbox
      currentMailbox = mailbox;

      // Check connection
      if (!mailService.client.isConnected) {
        await mailService.connect().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException("Connection timeout", const Duration(seconds: 10));
          },
        );
      }

      // Select mailbox
      await mailService.client.selectMailbox(mailbox).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException("Mailbox selection timeout", const Duration(seconds: 10));
        },
      );

      // Load additional messages
      await _loadAdditionalMessages(mailbox, pageNumber);
      
    } catch (e) {
      logger.e("Error loading more emails: $e");
      // Don't show error for pagination failures to avoid disrupting UX
    }
  }

  // Load additional messages for pagination
  Future<void> _loadAdditionalMessages(Mailbox mailbox, int pageNumber) async {
    try {
      int max = mailbox.messagesExists;
      if (max == 0) return;

      int startIndex = pageNumber * pageSize;
      if (startIndex >= max) return; // No more messages

      int endIndex = startIndex + pageSize;
      if (endIndex > max) {
        endIndex = max;
      }

      // Create sequence for additional messages
      MessageSequence sequence;
      try {
        sequence = MessageSequence.fromRange(max - endIndex + 1, max - startIndex);
      } catch (e) {
        logger.e("Error creating sequence for pagination: $e");
        return;
      }

      // Load messages from storage first
      if (mailboxStorage[mailbox] != null) {
        final cachedMessages = await mailboxStorage[mailbox]!.loadMessageEnvelopes(sequence).timeout(
          const Duration(seconds: 10),
          onTimeout: () => <MimeMessage>[],
        );

        if (cachedMessages.isNotEmpty) {
          if (emails[mailbox] == null) {
            emails[mailbox] = <MimeMessage>[];
          }
          emails[mailbox]!.addAll(cachedMessages);
          return;
        }
      }

      // If not in cache, fetch from server
      List<MimeMessage> newMessages = await queue(sequence).timeout(
        const Duration(seconds: 20),
        onTimeout: () => <MimeMessage>[],
      );

      if (newMessages.isNotEmpty) {
        if (emails[mailbox] == null) {
          emails[mailbox] = <MimeMessage>[];
        }
        emails[mailbox]!.addAll(newMessages);

        // Save to cache
        if (mailboxStorage[mailbox] != null) {
          await Future.delayed(const Duration(milliseconds: 50));
          await mailboxStorage[mailbox]!.saveMessageEnvelopes(newMessages).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              logger.w("Cache save timeout during pagination");
            },
          );
        }
      }
    } catch (e) {
      logger.e("Error in _loadAdditionalMessages: $e");
    }
  }

  Future<void> _loadDraftsFromServer(Mailbox mailbox) async {
    try {
      // CRITICAL FIX: Initialize emails list for draft mailbox
      if (emails[mailbox] == null) {
        emails[mailbox] = <MimeMessage>[];
      }
      
      // Initialize storage for drafts if not exists
      if (mailboxStorage[mailbox] == null) {
        mailboxStorage[mailbox] = SQLiteMailboxMimeStorage(
          mailAccount: mailService.account,
          mailbox: mailbox,
        );
        await mailboxStorage[mailbox]!.init();
      }

      // PERFORMANCE FIX: Clear existing drafts before loading new ones
      emails[mailbox]!.clear();

      logger.i("Loading drafts from server for mailbox: ${mailbox.name}");

      // PROPER ENOUGH_MAIL API: Load drafts from server like regular emails
      int max = mailbox.messagesExists;
      if (max == 0) {
        logger.i("No draft messages exist in ${mailbox.name}");
        // Update storage with empty list to trigger UI update
        await mailboxStorage[mailbox]!.saveMessageEnvelopes([]);
        update();
        return;
      }

      // Load drafts using proper enough_mail API (they're just regular emails with \Draft flag)
      int start = math.max(1, max - 100); // Load last 100 drafts
      int end = max;
      
      logger.i("Fetching drafts from sequence $start:$end in ${mailbox.name}");
      
      final sequence = MessageSequence.fromRange(start, end);
      final draftMessages = await mailService.client.fetchMessageSequence(
        sequence,
        fetchPreference: FetchPreference.envelope,
      );

      if (draftMessages.isEmpty) {
        logger.i("No draft messages found in ${mailbox.name}");
        await mailboxStorage[mailbox]!.saveMessageEnvelopes([]);
        update();
        return;
      }

      // Sort drafts by date (newest first)
      draftMessages.sort((a, b) {
        final dateA = a.decodeDate();
        final dateB = b.decodeDate();
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

      // Add drafts to emails list
      emails[mailbox]!.addAll(draftMessages);
      
      // CRITICAL FIX: Save to storage and notify listeners properly
      await mailboxStorage[mailbox]!.saveMessageEnvelopes(draftMessages);
      
      // Update unread count for drafts
      if (Get.isRegistered<MailCountController>()) {
        final countController = Get.find<MailCountController>();
        String key = "${mailbox.name.toLowerCase()}_count";
        countController.counts[key] = draftMessages.length; // All drafts are "unread"
      }
      
      // Force UI update by triggering the observable
      update();
      
      logger.i("Successfully loaded ${draftMessages.length} drafts from server for ${mailbox.name}");
    } catch (e) {
      logger.e("Error loading drafts from server: $e");
      // Ensure UI shows empty state on error
      if (emails[mailbox] == null) {
        emails[mailbox] = <MimeMessage>[];
      }
      // Show error to user
      Get.snackbar(
        'Error Loading Drafts',
        'Failed to load draft emails: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      update();
    }
  }

  MimeMessage _convertDraftToMimeMessage(DraftModel draft) {
    final message = MimeMessage();
    
    // Set basic properties
    message.setHeader('subject', draft.subject);
    
    // Set recipients
    if (draft.to.isNotEmpty) {
      message.setHeader('to', draft.to.join(', '));
    }
    if (draft.cc.isNotEmpty) {
      message.setHeader('cc', draft.cc.join(', '));
    }
    if (draft.bcc.isNotEmpty) {
      message.setHeader('bcc', draft.bcc.join(', '));
    }
    
    // Set date
    message.setHeader('date', draft.createdAt.toIso8601String());
    
    // Set content using the correct MimePart API
    if (draft.body.isNotEmpty) {
      final part = MimePart();
      if (draft.isHtml) {
        part.addHeader('Content-Type', 'text/html; charset=utf-8');
      } else {
        part.addHeader('Content-Type', 'text/plain; charset=utf-8');
      }
      part.addHeader('Content-Transfer-Encoding', 'quoted-printable');
      part.mimeData = TextMimeData(draft.body, containsHeader: false);
      message.addPart(part);
    }
    
    // Mark as draft with custom headers
    message.setHeader('x-draft-id', draft.id?.toString() ?? '');
    message.setHeader('x-is-draft', 'true');
    
    return message;
  }

  Future<List<MimeMessage>> queue(MessageSequence sequence) async {
    try {
      return await mailService.client.fetchMessageSequence(
        sequence,
        fetchPreference: FetchPreference.envelope,
      );
    } catch (e) {
      logger.e("Error in queue method: $e");
      return <MimeMessage>[];
    }
  }

  // Operations on emails
  Future markAsReadUnread(List<MimeMessage> messages, Mailbox box,
      [bool isSeen = true]) async {
    for (var message in messages) {
      message.isSeen = isSeen;
      if (mailboxStorage[box] != null) {
        await mailboxStorage[box]!.saveMessageEnvelopes([message]);
      }
    }
    if (!mailService.client.isConnected) {
      return;
    }
    // set on server
    if (mailService.client.isConnected) {
      for (var message in messages) {
        await mailService.client.flagMessage(message, isSeen: isSeen);
      }
    }
  }

  //
  DeleteResult? deleteResult;
  Map<Mailbox, List<MimeMessage>> deletedMessages = {};

  Future deleteMails(List<MimeMessage> messages, Mailbox mailbox) async {
    for (var message in messages) {
      if (mailboxStorage[mailbox] != null) {
        await mailboxStorage[mailbox]!.deleteMessage(message);
      }
    }
    deletedMessages[mailbox] = messages;
    // set on server
    if (mailService.client.isConnected) {
      deleteResult = await mailService.client.deleteMessages(
        MessageSequence.fromMessages(messages),
        messages: messages,
        expunge: false,
      );
    }
    if (deleteResult != null && deleteResult!.canUndo) {
      Get.showSnackbar(
        GetSnackBar(
          message: 'messages_deleted'.tr,
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
          mainButton: TextButton(
            onPressed: () async {
              await undoDelete();
            },
            child: Text('undo'.tr),
          ),
        ),
      );
    }
  }

  Future undoDelete() async {
    if (deleteResult != null) {
      await mailService.client.undoDeleteMessages(deleteResult!);
      deleteResult = null;
      for (var mailbox in deletedMessages.keys) {
        await mailboxStorage[mailbox]!
            .saveMessageEnvelopes(deletedMessages[mailbox]!);
      }
      deletedMessages.clear();
    }
  }

  Future moveMails(List<MimeMessage> messages, Mailbox from, Mailbox to) async {
    for (var message in messages) {
      if (mailboxStorage[from] != null) {
        await mailboxStorage[from]!.deleteMessage(message);
      }
      if (mailboxStorage[to] != null) {
        await mailboxStorage[to]!.saveMessageEnvelopes([message]);
      }
    }
    // set on server
    if (mailService.client.isConnected) {
      for (var message in messages) {
        await mailService.client.moveMessage(message, to);
      }
    }
  }

  // update flage on messages on server
  Future updateFlag(List<MimeMessage> messages, Mailbox mailbox) async {
    for (var message in messages) {
      message.isFlagged = !message.isFlagged;
      if (mailboxStorage[mailbox] != null) {
        await mailboxStorage[mailbox]!.saveMessageEnvelopes([message]);
      }
    }
    // set on server
    if (mailService.client.isConnected) {
      for (var message in messages) {
        await mailService.client.flagMessage(
          message,
          isFlagged: message.isFlagged,
        );
      }
    }
  }

  // Operations on emails
  Future deleteAccount() async {
    for (var mailbox in MailService.instance.client.mailboxes ?? []) {
      if (mailboxStorage[mailbox] != null) {
        await mailboxStorage[mailbox]!.onAccountRemoved();
      }
    }
  }

  Future ltrTap(MimeMessage message, Mailbox mailbox) async {
    SwapAction action =
    getSwapActionFromString(settingController.swipeGesturesLTR());
    _doSwapAction(
      action,
      message,
      mailbox,
    );
  }

  Future rtlTap(MimeMessage message, Mailbox mailbox) async {
    SwapAction action =
    getSwapActionFromString(settingController.swipeGesturesRTL());
    _doSwapAction(
      action,
      message,
      mailbox,
    );
  }

  Future _doSwapAction(
      SwapAction action, MimeMessage message, Mailbox box) async {
    if (action == SwapAction.readUnread) {
      await markAsReadUnread([message], box, !message.isSeen);
    } else if (action == SwapAction.delete) {
      await deleteMails([message], box);
    } else if (action == SwapAction.archive) {
      Mailbox? archive = mailboxes.firstWhereOrNull((e) => e.isArchive);
      if (archive != null) {
        await moveMails([message], box, archive);
      }
    } else if (action == SwapAction.toggleFlag) {
      await updateFlag([message], box);
    } else if (action == SwapAction.markAsJunk) {
      Mailbox? junk = mailboxes.firstWhereOrNull((e) => e.isJunk);
      if (junk != null) {
        await moveMails([message], box, junk);
      }
    }
  }

  Future handleIncomingMail(MimeMessage message) async {
    // detect the mailbox from the message
    Mailbox? mailbox = mailboxes.firstWhereOrNull(
          (element) => element.flags.any((e) => message.hasFlag(e.name)),
    );
    if (mailbox != null) {
      await mailboxStorage[mailbox]!.saveMessageEnvelopes([message]);
    }
  }

  Future vanishMails(List<MimeMessage> msgs) async {
    for (var message in msgs) {
      if (message.isDeleted) {
        for (var element in mailboxStorage.values) {
          await element.deleteMessage(message);
        }
      }
    }
  }

  Future navigatToMailBox(Mailbox mailbox) async {
    try {
      // Reset current mailbox before navigation to fix fetch error
      currentMailbox = null;

      Get.to(() => MailBoxView(mailBox: mailbox));
      await loadEmailsForBox(mailbox);
    } catch (e) {
      logger.e("Error in navigatToMailBox: $e");
      // Reset loading state in case of error
      isBoxBusy(false);
    }
  }

  void storeContactMails(List<MimeMessage> messages) {
    Set<String> mails = {};
    mails.addAll((getStoarage.read('mails') ?? []).cast<String>());
    for (var msg in messages) {
      if (msg.from != null) {
        for (var e in msg.from!) {
          try {
            mails.add(e.email);
          } catch (e) {
            logger.e(e);
          }
        }
      }
    }
    getStoarage.write('mails', mails.cast<String>().toList());
  }

  Future sendMail(MimeMessage message, MimeMessage? msg) async {
    try {
      await mailService.client.sendMessage(message);
      if (msg != null) {
        await mailService.client.deleteMessage(msg);
      }
    } catch (e) {
      logger.e(e);
    }
  }

  Future logout() async {
    try {
      await GetStorage().erase();
      MailService.instance.client.disconnect();
      MailService.instance.dispose();
      await deleteAccount();
      await Workmanager().cancelAll();
      Get.offAll(() => LoginScreen());
    } catch (e) {
      logger.e(e);
    }
  }

  @override
  void dispose() {
    MailService.instance.dispose();
    super.dispose();
  }
}
