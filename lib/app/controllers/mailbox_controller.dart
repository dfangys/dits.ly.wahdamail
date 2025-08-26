import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    try {
      // Show progress indicator
      if (Get.isRegistered<EmailDownloadProgressController>()) {
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

      // Check connection with shorter timeout
      if (!mailService.client.isConnected) {
        if (Get.isRegistered<EmailDownloadProgressController>()) {
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
      if (Get.isRegistered<EmailDownloadProgressController>()) {
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
      if (Get.isRegistered<EmailDownloadProgressController>()) {
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
          if (Get.isRegistered<EmailDownloadProgressController>()) {
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
          
          await fetchMailbox(mailbox).timeout(
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
      
      // Hide progress indicator
      if (Get.isRegistered<EmailDownloadProgressController>()) {
        final progressController = Get.find<EmailDownloadProgressController>();
        progressController.hide();
      }
    }
  }

  // Pagination for emails
  int page = 1;
  int pageSize = 10; // Reduced from 20 to prevent timeouts

  Future<void> fetchMailbox(Mailbox mailbox) async {
    try {
      // Ensure we're working with the correct mailbox
      if (currentMailbox != mailbox) {
        currentMailbox = mailbox;
      }

      // Special handling for draft mailbox
      if (mailbox.name.toLowerCase() == 'drafts' || mailbox.name.toLowerCase() == 'draft') {
        await _loadDraftsFromLocal(mailbox);
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
        if (mailboxStorage[mailbox] != null) {
          await mailboxStorage[mailbox]!.saveMessageEnvelopes([]);
        }
        return;
      }
      
      if (emails[mailbox] == null) {
        emails[mailbox] = <MimeMessage>[];
      }
      page = 1;
      emails[mailbox]!.clear();

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

      // Load messages in smaller batches to avoid sequence issues and database locks
      int loaded = 0;
      int maxToLoad = max > 200 ? 200 : max; // Load up to 200 recent messages
      
      while (loaded < maxToLoad) {
        int batchSize = pageSize;
        if (loaded + batchSize > maxToLoad) {
          batchSize = maxToLoad - loaded;
        }
        
        // Load from the most recent messages (highest sequence numbers)
        int start = max - loaded - batchSize + 1;
        int end = max - loaded;
        
        // Create a safe sequence
        MessageSequence sequence;
        try {
          if (end > maxToLoad) {
            end = maxToLoad;
          }
          sequence = MessageSequence.fromRange(start, end);
        } catch (e) {
          logger.e("Error creating sequence for range $start:$end: $e");
          break;
        }
        
        try {
          // Add small delay to prevent database locking
          if (loaded > 0) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
          
          final messages = await mailboxStorage[mailbox]!.loadMessageEnvelopes(sequence).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException("Database load timeout", const Duration(seconds: 15));
            },
          );
          
          if (messages.isNotEmpty) {
            emails[mailbox]!.addAll(messages);
            loaded += messages.length;
          } else {
            List<MimeMessage> newMessages = await queue(sequence).timeout(
              const Duration(seconds: 20),
              onTimeout: () {
                throw TimeoutException("Network fetch timeout", const Duration(seconds: 20));
              },
            );
            
            if (newMessages.isNotEmpty) {
              emails[mailbox]!.addAll(newMessages);
              
              // Save with timeout and delay to prevent database locking
              await Future.delayed(const Duration(milliseconds: 50));
              await mailboxStorage[mailbox]!.saveMessageEnvelopes(newMessages).timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  logger.w("Database save timeout - continuing without saving");
                },
              );
              
              loaded += newMessages.length;
            } else {
              // No more messages to load
              break;
            }
          }
        } catch (e) {
          logger.e("Error loading messages for sequence $start:$end: $e");
          // Try to continue with next batch instead of failing completely
          loaded += batchSize;
          
          // Add delay before next attempt
          await Future.delayed(const Duration(milliseconds: 200));
        }
        
        // Prevent infinite loop
        if (loaded >= maxToLoad || batchSize == 0) {
          break;
        }
      }
      
      if (mailbox.isInbox) {
        BackgroundService.checkForNewMail(false);
      }
      
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
      
      // Clear current data
      if (emails[mailbox] != null) {
        emails[mailbox]!.clear();
      }
      
      // Reset pagination
      page = 1;
      
      // Reload emails
      await loadEmailsForBox(mailbox);
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

  Future<void> _loadDraftsFromLocal(Mailbox mailbox) async {
    try {
      // Initialize storage for drafts if not exists
      if (mailboxStorage[mailbox] == null) {
        mailboxStorage[mailbox] = SQLiteMailboxMimeStorage(
          mailAccount: mailService.account,
          mailbox: mailbox,
        );
        await mailboxStorage[mailbox]!.init();
      }

      // Check if MailService is available
      if (!Get.isRegistered<MailService>()) {
        logger.w("MailService not available for draft loading");
        return;
      }

      final draftRepository = SQLiteDraftRepository.instance;
      await draftRepository.init();
      
      final drafts = await draftRepository.getAllDrafts();
      logger.i("Found ${drafts.length} drafts in local database");

      if (drafts.isEmpty) {
        logger.i("No drafts found in local database");
        // Still update UI to show empty state
        update();
        return;
      }

      // Convert drafts to MimeMessage objects
      List<MimeMessage> draftMessages = [];
      for (var draft in drafts) {
        try {
          final mimeMessage = _convertDraftToMimeMessage(draft);
          draftMessages.add(mimeMessage);
        } catch (e) {
          logger.e("Error converting draft to MimeMessage: $e");
        }
      }

      emails[mailbox]!.addAll(draftMessages);
      
      // Save to storage and notify listeners
      await mailboxStorage[mailbox]!.saveMessageEnvelopes(draftMessages);
      
      // Force UI update by triggering the observable
      update();
      
      if (Get.isRegistered<MailCountController>()) {
        final countControll = Get.find<MailCountController>();
        String key = "${mailbox.name.toLowerCase()}_count";
        countControll.counts[key] = draftMessages.length;
      }
      
      logger.i("Loaded ${draftMessages.length} drafts for mailbox: ${mailbox.name}");
    } catch (e) {
      logger.e("Error loading drafts from local: $e");
      // Still update UI even on error
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
