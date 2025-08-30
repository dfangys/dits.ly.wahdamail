import 'dart:async';
import 'dart:math' as math;

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/app/controllers/mail_count_controller.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';
import 'package:wahda_bank/utils/indexed_cache.dart';
import 'package:wahda_bank/services/cache_manager.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/services/realtime_update_service.dart';
import 'package:wahda_bank/services/preview_service.dart';
import 'package:wahda_bank/services/feature_flags.dart';
import 'package:wahda_bank/services/message_content_store.dart';
import 'package:wahda_bank/services/html_enhancer.dart';
import 'package:wahda_bank/utils/perf/perf_tracer.dart';
import 'package:wahda_bank/services/optimized_idle_service.dart';
import 'package:wahda_bank/services/connection_manager.dart' as conn;
import 'package:wahda_bank/services/background_service.dart';
import 'package:rxdart/rxdart.dart' hide Rx;
import 'package:wahda_bank/views/compose/redesigned_compose_screen.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';
import 'package:wahda_bank/views/view/showmessage/show_message_pager.dart';
import 'package:wahda_bank/views/box/mailbox_view.dart';
import 'package:wahda_bank/views/settings/data/swap_data.dart';
import 'package:workmanager/workmanager.dart';
import 'package:wahda_bank/widgets/progress_indicator_widget.dart';
import '../../views/authantication/screens/login/login.dart';
import '../../views/view/models/box_model.dart';

class MailBoxController extends GetxController {
  // ENHANCED: Add IndexedCache for high-performance message caching
  late final IndexedCache<MimeMessage> _messageCache;
  static const int _maxCacheSize = 200; // Optimized for mobile devices
  late MailService mailService;
  // Progress controller for download/loading feedback
  final EmailDownloadProgressController progressController = Get.find<EmailDownloadProgressController>();
  // CRITICAL: Add navigation state preservation
  final RxBool _isNavigating = false.obs;
  bool get isNavigating => _isNavigating.value;
  
  final RxBool isBusy = true.obs;
  final RxBool isBoxBusy = true.obs;
  bool get isInboxInitialized => _hasInitializedInbox;
  bool _hasInitializedInbox = false;
  
  void setNavigating(bool value) {
    _isNavigating.value = value;
  }
  
  // CRITICAL: Prevent infinite loading loops
  final Map<Mailbox, bool> _isLoadingMore = {};
  final RxBool isLoadingEmails = false.obs;
  // Track prefetch life-cycle separately to keep progress visible
  final RxBool isPrefetching = false.obs;
  
  bool isLoadingMoreEmails(Mailbox mailbox) {
    return _isLoadingMore[mailbox] ?? false;
  }
  final getStoarage = GetStorage();

  // Performance optimization services
  final CacheManager cacheManager = CacheManager.instance;
  final RealtimeUpdateService realtimeService = RealtimeUpdateService.instance;
  final PreviewService previewService = PreviewService.instance;

  // Stream subscriptions for real-time updates
  StreamSubscription<List<MessageUpdate>>? _messageUpdateSubscription;
  StreamSubscription<MailboxUpdate>? _mailboxUpdateSubscription;

  // Foreground polling timer (quiet, app-lifecycle bound)
  Timer? _pollTimer;
  String? _pollingMailboxPath;
  Duration pollingInterval = const Duration(seconds: 90);

  // Optimized IDLE once-only guard
  bool _optimizedIdleStarted = false;

  // Replace Hive storage with SQLite storage
  final RxMap<Mailbox, SQLiteMailboxMimeStorage> mailboxStorage =
      <Mailbox, SQLiteMailboxMimeStorage>{}.obs;
  final RxMap<Mailbox, List<MimeMessage>> emails =
      <Mailbox, List<MimeMessage>>{}.obs;

  // Per-message meta notifiers (preview, flags, etc.) to enable fine-grained updates
  final Map<String, ValueNotifier<int>> _messageMeta = <String, ValueNotifier<int>>{};
  String _msgKey(Mailbox m, MimeMessage msg) {
    final id = msg.uid ?? msg.sequenceId;
    return '${m.encodedPath}:${id ?? 0}';
  }

  // Compute all reasonable alias keys for a message to ensure we can notify tiles
  // that subscribed before UID was known (e.g., using sequenceId).
  List<String> _allMsgKeys(Mailbox m, MimeMessage msg) {
    final keys = <String>{};
    final path = m.encodedPath;
    final uid = msg.uid;
    final seq = msg.sequenceId;
    if (uid != null) keys.add('$path:$uid');
    if (seq != null) keys.add('$path:$seq');
    // As an extreme fallback when both are null
    if (keys.isEmpty) keys.add('$path:0');
    return keys.toList(growable: false);
  }

  ValueNotifier<int> getMessageMetaNotifier(Mailbox mailbox, MimeMessage msg) {
    final key = _msgKey(mailbox, msg);
    return _messageMeta.putIfAbsent(key, () => ValueNotifier<int>(0));
  }

  // Bump all alias keys so any tile listening by UID or by sequenceId updates immediately.
  void bumpMessageMeta(Mailbox mailbox, MimeMessage msg) {
    for (final key in _allMsgKeys(mailbox, msg)) {
      final n = _messageMeta.putIfAbsent(key, () => ValueNotifier<int>(0));
      n.value = n.value + 1;
    }
  }

  // Real-time update observables
  final RxMap<String, int> unreadCounts = <String, int>{}.obs;
  final RxSet<String> flaggedMessages = <String>{}.obs;

  // Track current mailbox to fix fetch error when switching
  final Rxn<Mailbox> _currentMailbox = Rxn<Mailbox>();
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
      // ENHANCED: Initialize IndexedCache for high-performance message caching
      _messageCache = IndexedCache<MimeMessage>(maxCacheSize: _maxCacheSize);
      
      mailService = MailService.instance;
      await mailService.init();
      await loadMailBoxes();
      
      // CRITICAL FIX: Set up real-time update listeners
      _setupRealtimeListeners();
      
      // IMPORTANT: Do NOT start optimized IDLE before a mailbox is selected.
      // We'll start it after we select the mailbox in loadEmailsForBox().

      // Schedule a background DB backfill for derived fields across mailboxes
      try {
        BackgroundService.scheduleDerivedFieldsBackfill(perMailboxLimit: 5000, batchSize: 800);
      } catch (_) {}
      
      super.onInit();
    } catch (e) {
      logger.e(e);
    }
  }

  /// Set up real-time update listeners for UI refresh
  void _setupRealtimeListeners() {
    try {
      // Listen for message updates (new messages, read/unread changes, etc.)
      _messageUpdateSubscription = realtimeService.messageUpdateStream
          .bufferTime(const Duration(milliseconds: 100))
          .listen((updates) {
        try {
          if (updates.isEmpty) return;
          if (kDebugMode) {
            print('📧 Received ${updates.length} buffered message updates');
          }
          for (final update in updates) {
            switch (update.type) {
              case MessageUpdateType.received:
                _handleNewMessageReceived(update.message);
                break;
              case MessageUpdateType.readStatusChanged:
                _handleReadStatusChanged(update.message);
                break;
              case MessageUpdateType.flagged:
              case MessageUpdateType.unflagged:
                _handleFlagChanged(update.message);
                break;
              case MessageUpdateType.deleted:
                _handleMessageDeleted(update.message);
                break;
              case MessageUpdateType.statusChanged:
                _handleReadStatusChanged(update.message);
                break;
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('📧 Error handling buffered message updates: $e');
          }
        }
      });

      // Listen for mailbox updates (new messages added to mailbox)
      _mailboxUpdateSubscription = realtimeService.mailboxUpdateStream.listen((update) {
        try {
          if (kDebugMode) {
            print('📧 Received mailbox update: ${update.type}');
          }
          
          if (update.type == MailboxUpdateType.messagesAdded && update.messages != null) {
            _handleNewMessagesInMailbox(update.mailbox, update.messages!);
          }
        } catch (e) {
          if (kDebugMode) {
            print('📧 Error handling mailbox update: $e');
          }
        }
      });
      
      if (kDebugMode) {
        print('📧 Real-time listeners set up successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error setting up real-time listeners: $e');
      }
    }
  }

  /// Handle new message received
  void _handleNewMessageReceived(MimeMessage message) {
    try {
      // Add to inbox if it's the current mailbox
      if (currentMailbox?.isInbox == true) {
        final inboxMessages = emails[currentMailbox];
        if (inboxMessages != null) {
          // Check if message already exists
          final exists = inboxMessages.any((m) => 
            m.uid == message.uid || 
            (m.sequenceId == message.sequenceId && message.sequenceId != null)
          );
          
          if (!exists) {
            inboxMessages.insert(0, message); // Add to beginning
            update(); // Trigger UI update
            
            if (kDebugMode) {
              print('📧 Added new message to UI: ${message.decodeSubject()}');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error handling new message: $e');
      }
    }
  }

  /// Handle read status change
  void _handleReadStatusChanged(MimeMessage message) {
    try {
      // Find and update the message in current mailbox
      final currentMessages = emails[currentMailbox];
      if (currentMessages != null) {
        final index = currentMessages.indexWhere((m) => 
          m.uid == message.uid || 
          (m.sequenceId == message.sequenceId && message.sequenceId != null)
        );
        
        if (index != -1) {
          currentMessages[index] = message; // Update with new read status
          update(); // Trigger UI update
          
          if (kDebugMode) {
            print('📧 Updated message read status: ${message.isSeen ? "read" : "unread"}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error handling read status change: $e');
      }
    }
  }

  /// Handle flag change
  void _handleFlagChanged(MimeMessage message) {
    try {
      // Find and update the message in current mailbox
      final currentMessages = emails[currentMailbox];
      if (currentMessages != null) {
        final index = currentMessages.indexWhere((m) => 
          m.uid == message.uid || 
          (m.sequenceId == message.sequenceId && message.sequenceId != null)
        );
        
        if (index != -1) {
          currentMessages[index] = message; // Update with new flag status
          update(); // Trigger UI update
          
          if (kDebugMode) {
            print('📧 Updated message flag status: ${message.isFlagged ? "flagged" : "unflagged"}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error handling flag change: $e');
      }
    }
  }

  /// Handle message deletion
  void _handleMessageDeleted(MimeMessage message) {
    try {
      // Remove from current mailbox
      final currentMessages = emails[currentMailbox];
      if (currentMessages != null) {
        currentMessages.removeWhere((m) => 
          m.uid == message.uid || 
          (m.sequenceId == message.sequenceId && message.sequenceId != null)
        );
        update(); // Trigger UI update
        
        if (kDebugMode) {
          print('📧 Removed deleted message from UI');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error handling message deletion: $e');
      }
    }
  }

  /// Handle new messages added to mailbox
  void _handleNewMessagesInMailbox(Mailbox mailbox, List<MimeMessage> newMessages) {
    try {
      // Robust mailbox matching: by encodedPath (preferred), name (case-insensitive), or inbox flag
      bool isSameMailbox = false;
      final current = currentMailbox;
      if (current != null) {
        if (current.encodedPath.isNotEmpty && mailbox.encodedPath.isNotEmpty) {
          isSameMailbox = current.encodedPath.toLowerCase() == mailbox.encodedPath.toLowerCase();
        }
        if (!isSameMailbox) {
          isSameMailbox = current.name.toLowerCase() == mailbox.name.toLowerCase();
        }
        if (!isSameMailbox && current.isInbox && mailbox.isInbox) {
          isSameMailbox = true;
        }
      }

      // Only update if it's the current mailbox
      if (isSameMailbox) {
        final currentMessages = emails[current];
        if (currentMessages != null) {
          for (final message in newMessages) {
            // Check if message already exists
            final exists = currentMessages.any((m) => 
              m.uid == message.uid || 
              (m.sequenceId == message.sequenceId && message.sequenceId != null)
            );
            
            if (!exists) {
              currentMessages.insert(0, message); // Add to beginning
              try { bumpMessageMeta(current!, message); } catch (_) {}
            }
          }
          // Trigger reactive updates
          emails.refresh();
          update();

          // Kick off a very fast preview/backfill for the top few new messages
          unawaited(_fastPreviewForNewMessages(current!, newMessages.take(3).toList()));
          // Warm up envelopes for all new messages so tiles don't show Unknown/No Subject
          unawaited(_ensureEnvelopesForNewMessages(current!, newMessages));

          // Also queue background backfill for the whole batch
          final storage = mailboxStorage[current];
          if (storage != null && newMessages.isNotEmpty) {
            try {
              previewService.queueBackfillForMessages(
                mailbox: current!,
                messages: newMessages,
                storage: storage,
                maxJobs: 10,
              );
            } catch (_) {}
          }
          
          if (kDebugMode) {
            print('📧 Added ${newMessages.length} new messages to mailbox UI (${current?.name ?? 'unknown'})');
          }
        }
      } else {
        if (kDebugMode) {
          print("📧 Mailbox update ignored (current=${currentMailbox?.name}, update=${mailbox.name})");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error handling new messages in mailbox: $e');
      }
    }
  }

  Future<void> initInbox() async {
    try {
      // Ensure we have a mailbox list; avoid recursion with loadMailBoxes()
      if (mailboxes.isEmpty) {
        try {
          if (!mailService.client.isConnected) {
            await mailService.connect();
          }
          final listed = await mailService.client.listMailboxes();
          if (listed.isNotEmpty) {
            mailboxes(listed);
          }
        } catch (e) {
          logger.w('initInbox: listing mailboxes failed: $e');
        }
      }

      // Select INBOX or a sensible fallback
      final inbox = mailboxes.firstWhereOrNull((m) => m.isInbox) ??
          mailboxes.firstWhereOrNull((m) => m.name.toUpperCase() == 'INBOX') ??
          (mailboxes.isNotEmpty ? mailboxes.first : null);

      if (inbox == null) {
        logger.e('initInbox: No mailboxes available to initialize');
        return;
      }

      mailBoxInbox = inbox;
      await loadEmailsForBox(mailBoxInbox);
      _hasInitializedInbox = true; // Set initialization flag
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
      // CRITICAL FIX: Prevent infinite loading loops
      if (isLoadingEmails.value) {
        logger.i("Already loading emails, skipping duplicate request");
        return;
      }
      
      isLoadingEmails.value = true;
      
      // Show progress for first-time load when no cached emails are present
      if (!hasExistingEmails) {
        progressController.show(
          title: 'Loading ${mailbox.name} emails',
          subtitle: 'Connecting…',
          indeterminate: true,
        );
      }
      
      // CRITICAL FIX: Add comprehensive logging for mailbox context
      logger.i("Loading emails for mailbox: ${mailbox.name} (path: ${mailbox.path})");
      logger.i("Has existing emails: $hasExistingEmails");
      logger.i("Previous current mailbox: ${currentMailbox?.name}");
      
      // Only show progress indicator if this is the first time loading (no cached emails)
      // Removed progressController to avoid duplicate loading indicators

      isBoxBusy(true);
      
      // Stop any previous polling when switching mailboxes
      _stopForegroundPolling();

      // CRITICAL FIX: Set current mailbox FIRST to ensure proper context isolation
      currentMailbox = mailbox;
      logger.i("Set current mailbox to: ${currentMailbox?.name}");
      
      // CRITICAL FIX: Force UI update to reflect mailbox change immediately
      update();

      // Ensure connection and mailbox selection, then start optimized IDLE even when using cache
      try {
        if (!mailService.client.isConnected) {
          await mailService.connect().timeout(const Duration(seconds: 8));
        }
        if (mailService.client.selectedMailbox?.encodedPath != mailbox.encodedPath) {
          await mailService.client.selectMailbox(mailbox).timeout(const Duration(seconds: 8));
        }
        // NOTE: Defer starting optimized IDLE until after initial load/prefetch completes
      } catch (_) {}

      // PERFORMANCE FIX: If emails already exist, just return them (use cache)
      if (hasExistingEmails) {
        logger.i("Using cached emails for ${mailbox.name} (${emails[mailbox]!.length} messages)");
        // Kick off preview backfill for messages missing previews
        final storage = mailboxStorage[mailbox];
        if (storage != null) {
          previewService.queueBackfillForMessages(
            mailbox: mailbox,
            messages: emails[mailbox]!,
            storage: storage,
            maxJobs: 40,
          );
        }
        isLoadingEmails.value = false;
        // Still ensure current mailbox is set correctly even when using cache
        currentMailbox = mailbox;
        // Begin real-time updates via optimized IDLE (preferred) after cache hydration
        _initializeOptimizedIdleService();
        return;
      }

      // Check connection with shorter timeout
      if (!mailService.client.isConnected) {
        progressController.updateStatus('Connecting…');
        await mailService.connect().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException("Connection timeout", const Duration(seconds: 10));
          },
        );
      }

      // Select mailbox with timeout
      progressController.updateStatus('Selecting mailbox…');
      await mailService.client.selectMailbox(mailbox).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException("Mailbox selection timeout", const Duration(seconds: 10));
        },
      );
      
      // NOTE: Defer starting optimized IDLE until after first-time load/prefetch completes
      
      // Fetch mailbox with timeout adapted for first-time loads
      progressController.updateStatus('Loading emails…');
      final int outerTimeoutSeconds = hasExistingEmails ? 45 : 180;
      await fetchMailbox(mailbox).timeout(
        Duration(seconds: outerTimeoutSeconds),
        onTimeout: () {
          logger.e("Timeout while fetching mailbox: ${mailbox.name}");
          throw TimeoutException("Loading emails timed out", Duration(seconds: outerTimeoutSeconds));
        },
      );
    } catch (e) {
      logger.e("Error selecting mailbox: $e");
      
      // Only retry if it's not a timeout from our own operations
      if (e is! TimeoutException) {
        try {
          // Removed progressController updateStatus to avoid duplicate indicators
          
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
        // It's a timeout; if some emails are already loaded, suppress the error and let UI show partial results
        final partiallyLoaded = (emails[mailbox]?.isNotEmpty ?? false);
        if (!partiallyLoaded) {
          Get.snackbar(
            'Timeout Error',
            'Loading emails is taking too long. Please try again.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        } else {
          logger.w('Timeout occurred but emails are partially loaded; continuing without error.');
        }
      }
    } finally {
      // Always reset loading state
      isBoxBusy(false);
      isLoadingEmails.value = false;
      
      // Hide progress UI at the end only if no prefetch is active
      if (!isPrefetching.value) {
        progressController.hide();
      }
    }
  }

  // Allow user to trigger a full mailbox download
  Future<void> downloadAllEmails(Mailbox mailbox) async {
    try {
      final storage = mailboxStorage[mailbox];
      if (storage == null) return;
      isPrefetching.value = true;
      progressController.show(title: 'Downloading all emails', subtitle: 'Preparing…', indeterminate: true);
      // Sync envelopes for the entire mailbox
      await _enterpriseSync(mailbox, storage, maxToLoad: mailbox.messagesExists);
      // Switch to READY-based progress and prefetch full content for all loaded emails
      _updateReadyProgress(mailbox, emails[mailbox]?.length ?? 0);
      progressController.updateStatus('Prefetching message bodies and attachments…');
      await _prefetchFullContentForWindow(mailbox, limit: emails[mailbox]?.length ?? 0);
      _updateReadyProgress(mailbox, emails[mailbox]?.length ?? 0);
      progressController.updateProgress(
        current: emails[mailbox]?.length ?? 0,
        total: emails[mailbox]?.length ?? 0,
        progress: 1.0,
        subtitle: 'Done',
      );
    } catch (e) {
      logger.e('Download all failed: $e');
      Get.snackbar('Error', 'Failed to download all emails. Please try again.', backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isPrefetching.value = false;
      progressController.hide();
    }
  }

  // Pagination for emails
  int page = 1;
  int pageSize = 50; // Increased from 10 to 50 for better email loading performance

  Future<void> fetchMailbox(Mailbox mailbox, {bool forceRefresh = false}) async {
    final endTrace = PerfTracer.begin('controller.fetchMailbox', args: {
      'mailbox': mailbox.name,
      'forceRefresh': forceRefresh,
    });
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
        
        // CRITICAL FIX: Trigger reactive updates for empty mailbox
        emails.refresh();
        update();
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

      // PERFORMANCE OPTIMIZATION: Load only an initial window instead of entire mailbox
      int loaded = 0;
      int maxToLoad = math.min(max, 200); // Load up to 200 most recent for initial view
      int batchSize = 50; // Batch size for network fetch
      
      if (maxToLoad > 0) {
        progressController.updateProgress(
          current: 0,
          total: maxToLoad,
          progress: 0.0,
          subtitle: 'Preparing to load $maxToLoad emails…',
        );
      }

      // First, try to serve from local DB using page-based API
      final storage = mailboxStorage[mailbox]!;
      final localCount = await storage.countMessages();
      final fromDb = await storage
          .loadMessagePage(limit: maxToLoad, offset: 0)
          .timeout(const Duration(seconds: 8), onTimeout: () => <MimeMessage>[]);
      bool loadedFromDb = false;
      if (fromDb.isNotEmpty) {
        emails[mailbox]!.addAll(fromDb);
        // Stamp thread counts for visible window
        _computeAndStampThreadCounts(mailbox);
        // Queue preview backfill for this page
        previewService.queueBackfillForMessages(
          mailbox: mailbox,
          messages: fromDb,
          storage: storage,
          maxJobs: 20,
        );
        loaded = fromDb.length;
        loadedFromDb = true;
        logger.i("Loaded ${fromDb.length} messages from local DB for ${mailbox.name}");
      }
        
      // Enterprise-grade sync: resumable with explicit checkpoints
      final satisfied = await _enterpriseSync(mailbox, storage, maxToLoad: maxToLoad);
      if (satisfied) {
        // Sort and finish early
        if (emails[mailbox]!.isNotEmpty) {
          emails[mailbox]!.sort((a, b) {
            final dateA = a.decodeDate();
            final dateB = b.decodeDate();
            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateB.compareTo(dateA);
          });
        }
        emails.refresh();
        update();
        // Eagerly prefetch full message bodies and attachment metadata for initial window
        final bool quietPrefetch = loadedFromDb; // Quiet if page came from DB
        if (!quietPrefetch) {
          isPrefetching.value = true;
          progressController.updateStatus('Prefetching message bodies and attachments…');
          _updateReadyProgress(mailbox, maxToLoad);
        }
        await _prefetchFullContentForWindow(mailbox, limit: maxToLoad, quiet: quietPrefetch);
        if (!quietPrefetch) {
          isPrefetching.value = false;
          progressController.updateProgress(
            current: maxToLoad,
            total: maxToLoad,
            progress: 1.0,
            subtitle: 'Done',
          );
          progressController.hide();
        }
        // Start real-time updates via optimized IDLE (preferred) after initial load
        _initializeOptimizedIdleService();
        logger.i("Enterprise sync satisfied initial window for ${mailbox.name} (${emails[mailbox]!.length})");
        return;
      }
        
        // If we already have enough locally, finish early
        if (localCount >= maxToLoad) {
        // Sort messages by date (newest first) for better UX
        if (emails[mailbox]!.isNotEmpty) {
          emails[mailbox]!.sort((a, b) {
            final dateA = a.decodeDate();
            final dateB = b.decodeDate();
            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateB.compareTo(dateA);
          });
        }
        emails.refresh();
        update();
        // Quiet prefetch for local-only satisfaction (no overlay)
        await _prefetchFullContentForWindow(mailbox, limit: maxToLoad, quiet: true);
        // Start real-time updates via optimized IDLE (preferred) after DB load
        _initializeOptimizedIdleService();
        logger.i("Finished loading from local DB for ${mailbox.name} (${emails[mailbox]!.length} messages)");
        return;
      }

      // Otherwise, fetch the remaining from the server (starting from newest)
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
          // Fetch from network (envelope-only for speed); we already loaded local page above
          List<MimeMessage> messages = await mailService.client.fetchMessageSequence(
            sequence,
            fetchPreference: FetchPreference.envelope,
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException("Network fetch timeout", const Duration(seconds: 30));
            },
          );

          if (messages.isNotEmpty) {
            // De-duplicate by UID and sequenceId
            final existingUids = emails[mailbox]!
                .map((m) => m.uid)
                .whereType<int>()
                .toSet();
            final existingSeqIds = emails[mailbox]!
                .map((m) => m.sequenceId)
                .whereType<int>()
                .toSet();
            final unique = messages.where((m) {
              final uid = m.uid;
              final seq = m.sequenceId;
              final notByUid = uid == null || !existingUids.contains(uid);
              final notBySeq = seq == null || !existingSeqIds.contains(seq);
              return notByUid && notBySeq;
            }).toList();

            if (unique.isNotEmpty) {
              emails[mailbox]!.addAll(unique);
              // Update thread counts after adding new messages
              _computeAndStampThreadCounts(mailbox);
              // Queue preview backfill for this batch
              previewService.queueBackfillForMessages(
                mailbox: mailbox,
                messages: unique,
                storage: storage,
                maxJobs: 20,
              );

              // Save to database for future use (fire and forget)
              storage.saveMessageEnvelopes(unique).catchError((e) {
                logger.w("Database save failed: $e");
              });

              loaded += unique.length;
              progressController.updateProgress(
                current: loaded,
                total: maxToLoad,
                progress: (loaded / maxToLoad).clamp(0.0, 1.0),
                subtitle: 'Downloading emails… $loaded / $maxToLoad',
              );
              logger.i("Loaded network batch: ${unique.length} messages (total: ${emails[mailbox]!.length})");
            } else {
              // No unique messages in this range, stop to avoid infinite loop
              break;
            }
          } else {
            // No more messages to load
            break;
          }
        } catch (e) {
          logger.e("Error loading messages for sequence $start:$end: $e");
          // Continue with next batch instead of failing completely
          loaded += currentBatchSize;
          progressController.updateProgress(
            current: loaded,
            total: maxToLoad,
            progress: (loaded / maxToLoad).clamp(0.0, 1.0),
            subtitle: 'Recovering… $loaded / $maxToLoad',
          );
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
      
      // CRITICAL FIX: Trigger reactive updates for UI
      emails.refresh();
      update();
      
      // Eagerly prefetch full bodies and attachment metadata for visible window
      isPrefetching.value = true;
      progressController.updateStatus('Prefetching message bodies and attachments…');
      _updateReadyProgress(mailbox, maxToLoad);
      await _prefetchFullContentForWindow(mailbox, limit: maxToLoad);
      isPrefetching.value = false;
      
      logger.i("Finished loading ${emails[mailbox]!.length} emails for ${mailbox.name}");
      progressController.updateProgress(
        current: maxToLoad,
        total: maxToLoad,
        progress: 1.0,
        subtitle: 'Done',
      );
      // Hide progress UI now that prefetch is complete
      progressController.hide();
      
      // Start real-time updates via optimized IDLE (preferred)
      _initializeOptimizedIdleService();
      
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
    } finally {
      try { endTrace(); } catch (_) {}
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
  Future<void> loadMoreEmails(Mailbox mailbox, [int? pageNumber]) async {
    final endTrace = PerfTracer.begin('controller.loadMoreEmails', args: {
      'mailbox': mailbox.name,
      'page': pageNumber ?? 1,
    });
    try {
      // CRITICAL: Prevent infinite loading loops
      if (_isLoadingMore[mailbox] == true) {
        debugPrint('🔄 Already loading more emails for ${mailbox.name}');
        return;
      }
      
      if (isBoxBusy.value) return; // Prevent multiple simultaneous loads
      
      // Check if we have more messages to load
      final currentCount = emails[mailbox]?.length ?? 0;
      final totalMessages = mailbox.messagesExists;
      
      if (currentCount >= totalMessages) {
        logger.i("💡 All messages already loaded for ${mailbox.name} ($currentCount/$totalMessages)");
        return;
      }
      
      // Set loading state
      _isLoadingMore[mailbox] = true;
      
      logger.i("Loading more emails for ${mailbox.name} (current: $currentCount/$totalMessages)");
      
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
      await _loadAdditionalMessages(mailbox, pageNumber ?? 1);
      
    } catch (e) {
      logger.e("Error loading more emails: $e");
      // Don't show error for pagination failures to avoid disrupting UX
    } finally {
      // CRITICAL: Always reset loading state
      _isLoadingMore[mailbox] = false;
      try { endTrace(); } catch (_) {}
    }
  }

  // Load additional messages for pagination
  Future<void> _loadAdditionalMessages(Mailbox mailbox, int pageNumber) async {
    final endTrace = PerfTracer.begin('controller._loadAdditionalMessages', args: {
      'mailbox': mailbox.name,
      'page': pageNumber,
    });
    try {
      int max = mailbox.messagesExists;
      if (max == 0) return;

      int startIndex = pageNumber * pageSize;
      if (startIndex >= max) return; // No more messages

      int endIndex = startIndex + pageSize;
      if (endIndex > max) {
        endIndex = max;
      }

      // Create sequence for additional messages (fix sequence calculation)
      MessageSequence sequence;
      try {
        // IMAP messages are numbered 1 to max, we want older messages
        // For page 1: get messages (max-pageSize+1) to max
        // For page 2: get messages (max-2*pageSize+1) to (max-pageSize)
        int sequenceStart = max - endIndex + 1;
        int sequenceEnd = max - startIndex;
        
        // Ensure valid range
        if (sequenceStart < 1) sequenceStart = 1;
        if (sequenceEnd < sequenceStart) sequenceEnd = sequenceStart;
        
        sequence = MessageSequence.fromRange(sequenceStart, sequenceEnd);
logger.i("Loading messages $sequenceStart-$sequenceEnd for page $pageNumber");
      } catch (e) {
        logger.e("Error creating sequence for pagination: $e");
        return;
      }

      // Try to load next page from local storage first (by date)
      if (mailboxStorage[mailbox] != null) {
        final currentCount = emails[mailbox]?.length ?? 0;
        final pageFromDb = await mailboxStorage[mailbox]!
            .loadMessagePage(limit: pageSize, offset: currentCount)
            .timeout(const Duration(seconds: 8), onTimeout: () => <MimeMessage>[]);

        if (pageFromDb.isNotEmpty) {
          if (emails[mailbox] == null) {
            emails[mailbox] = <MimeMessage>[];
          }
          emails[mailbox]!.addAll(pageFromDb);
          // Launch preview backfill for DB page
          final storage = mailboxStorage[mailbox]!;
          previewService.queueBackfillForMessages(
            mailbox: mailbox,
            messages: pageFromDb,
            storage: storage,
            maxJobs: 20,
          );
          return;
        }
      }

      // If not available locally, fetch from server
      logger.i("Fetching ${sequence.length} messages from server for pagination");
      List<MimeMessage> newMessages = await mailService.client.fetchMessageSequence(
        sequence,
        fetchPreference: FetchPreference.envelope,
      ).timeout(
        const Duration(seconds: 30), // Increased timeout for better reliability
        onTimeout: () {
          logger.w("Timeout loading messages for pagination");
          return <MimeMessage>[];
        },
      );

      logger.i("Fetched ${newMessages.length} new messages from server");
      if (newMessages.isNotEmpty) {
        if (emails[mailbox] == null) {
          emails[mailbox] = <MimeMessage>[];
        }
        
        // Add new messages and remove duplicates
        final existingUids = emails[mailbox]!
            .map((m) => m.uid)
            .whereType<int>()
            .toSet();
        final existingSeqIds = emails[mailbox]!
            .map((m) => m.sequenceId)
            .whereType<int>()
            .toSet();
        final uniqueNewMessages = newMessages.where((m) {
          final uid = m.uid;
          final seq = m.sequenceId;
          final notByUid = uid == null || !existingUids.contains(uid);
          final notBySeq = seq == null || !existingSeqIds.contains(seq);
          return notByUid && notBySeq;
        }).toList();
        
        emails[mailbox]!.addAll(uniqueNewMessages);
        emails.refresh(); // CRITICAL FIX: Trigger reactive update for UI
        logger.i("Added ${uniqueNewMessages.length} unique messages to mailbox ${mailbox.name}");

        // Save to storage
        if (mailboxStorage[mailbox] != null && uniqueNewMessages.isNotEmpty) {
          try {
            await mailboxStorage[mailbox]!.saveMessageEnvelopes(uniqueNewMessages);
            logger.i("Saved ${uniqueNewMessages.length} messages to storage");
          } catch (e) {
            logger.e("Error saving messages to storage: $e");
          }
        }
        
        // Force UI update
        update();
      } else {
        logger.w("No new messages fetched for pagination");
      }
    } catch (e) {
      logger.e("Error in _loadAdditionalMessages: $e");
    } finally {
      try { endTrace(); } catch (_) {}
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


  Future<List<MimeMessage>> queue(MessageSequence sequence) async {
    try {
      // ENHANCED: Check cache first for performance optimization
      final List<MimeMessage> cachedMessages = [];
      final List<int> uncachedIds = [];
      
      // Check which messages are already cached
      for (final id in sequence.toList()) {
        final cached = _messageCache[id];
        if (cached != null) {
          cachedMessages.add(cached);
          if (kDebugMode) {
            print('📧 Cache HIT for message $id');
          }
        } else {
          uncachedIds.add(id);
        }
      }
      
      // Fetch only uncached messages from server
      List<MimeMessage> fetchedMessages = [];
      if (uncachedIds.isNotEmpty) {
        final uncachedSequence = MessageSequence.fromIds(uncachedIds);
        
        // CRITICAL FIX: Fetch envelope AND headers to get proper sender/subject information
        fetchedMessages = await mailService.client.fetchMessageSequence(
          uncachedSequence,
          fetchPreference: FetchPreference.fullWhenWithinSize, // Get full message data for better parsing
        );
        
        // ENHANCED: Cache fetched messages for future use
        for (final message in fetchedMessages) {
          if (message.sequenceId != null) {
            _messageCache[message.sequenceId!] = message;
            if (kDebugMode) {
              print('📧 Cached message ${message.sequenceId}');
            }
          }
        }
        
        if (kDebugMode) {
          print('📧 Cache MISS: Fetched ${fetchedMessages.length} messages from server');
          print('📧 Cache stats: ${_messageCache.getStats()}');
        }
      }
      
      // Combine cached and fetched messages
      final allMessages = [...cachedMessages, ...fetchedMessages];
      
      // ENHANCED FIX: Ensure messages have complete data for display
      for (final message in allMessages) {
        try {
          // Ensure envelope exists and is properly populated
          if (message.envelope == null) {
            // Force fetch envelope if missing - use fetchMessageSequence instead
            try {
              final singleSequence = MessageSequence.fromId(message.sequenceId!);
              final fullMessages = await mailService.client.fetchMessageSequence(
                singleSequence,
                fetchPreference: FetchPreference.envelope,
              );
              if (fullMessages.isNotEmpty) {
                message.envelope = fullMessages.first.envelope;
                // Skip header copying due to type mismatch - envelope data is sufficient
                // Headers will be available through message.getHeaderValue() method
              }
            } catch (e) {
              if (kDebugMode) {
                print('📧 Error fetching envelope for message ${message.sequenceId}: $e');
              }
            }
          }
          
          // Reconstruct envelope from headers if still missing
          if (message.envelope == null && message.headers != null) {
            try {
              final fromHeader = message.getHeaderValue('from');
              final toHeader = message.getHeaderValue('to');
              final subjectHeader = message.getHeaderValue('subject');
              final dateHeader = message.getHeaderValue('date');
              
              // Parse date properly
              DateTime? parsedDate;
              if (dateHeader != null) {
                try {
                  parsedDate = DateCodec.decodeDate(dateHeader);
                } catch (e) {
                  parsedDate = DateTime.tryParse(dateHeader);
                }
              }
              
              // Parse addresses properly
              List<MailAddress>? fromAddresses;
              if (fromHeader != null) {
                try {
                  // Use MailAddress.parse for single address
                  fromAddresses = [MailAddress.parse(fromHeader)];
                } catch (e) {
                  try {
                    // Fallback: create basic MailAddress
                    fromAddresses = [MailAddress('Unknown', fromHeader)];
                  } catch (e2) {
                fromAddresses = [const MailAddress('Unknown', 'unknown@unknown.com')];
                  }
                }
              }
              
              List<MailAddress>? toAddresses;
              if (toHeader != null) {
                try {
                  // Use MailAddress.parse for single address
                  toAddresses = [MailAddress.parse(toHeader)];
                } catch (e) {
                  try {
                    // Fallback: create basic MailAddress
                    toAddresses = [MailAddress('', toHeader)];
                  } catch (e2) {
                    toAddresses = [const MailAddress('', 'unknown@unknown.com')];
                  }
                }
              }
              
              // Create proper envelope
              message.envelope = Envelope(
                date: parsedDate ?? DateTime.now(),
                subject: subjectHeader ?? 'No Subject',
                from: fromAddresses ?? [const MailAddress('Unknown', 'unknown@unknown.com')],
                to: toAddresses,
                sender: fromAddresses?.first, // Use first address, not list
                replyTo: fromAddresses,
              );
              
              if (kDebugMode) {
                print('📧 ✅ Reconstructed envelope for message: ${message.envelope?.subject}');
              }
            } catch (e) {
              if (kDebugMode) {
                print('📧 ❌ Error reconstructing envelope: $e');
              }
              
              // Create minimal envelope as fallback
              message.envelope = Envelope(
                date: DateTime.now(),
                subject: 'No Subject',
                from: [const MailAddress('Unknown', 'unknown@unknown.com')],
              );
            }
          }
          
          // Ensure message has proper flags for UI display (skip if type mismatch)
          // message.flags initialization is handled by enough_mail internally
          
          // Ensure message has sequence ID for operations
          if (message.sequenceId == null && message.uid != null) {
            // Try to get sequence ID from UID if available
            message.sequenceId = message.uid;
          }
          
        } catch (e) {
          if (kDebugMode) {
            print('📧 ❌ Error processing message ${message.sequenceId}: $e');
          }
        }
      }

      return allMessages;
    } catch (e) {
      logger.e("Error in queue method: $e");
      return [];
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
    getSwapActionFromString(settingController.swipeGesturesLTR.value);
    _doSwapAction(
      action,
      message,
      mailbox,
    );
  }

  Future rtlTap(MimeMessage message, Mailbox mailbox) async {
    SwapAction action =
    getSwapActionFromString(settingController.swipeGesturesRTL.value);
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
    try {
      if (kDebugMode) {
        print("📧 Processing incoming mail: ${message.decodeSubject()}");
      }
      
      // Detect the mailbox from the message - default to INBOX if not found
      Mailbox? mailbox = mailboxes.firstWhereOrNull(
            (element) => element.flags.any((e) => message.hasFlag(e.name)),
      );
      
      // Default to INBOX if no specific mailbox found
      mailbox ??= mailboxes.firstWhereOrNull((element) => element.name == 'INBOX');
      
      if (mailbox != null && mailboxStorage[mailbox] != null) {
        final storage = mailboxStorage[mailbox]!;
        // Save to storage with error handling
        try {
          await storage.saveMessageEnvelopes([message]);
          
          if (kDebugMode) {
            print("📧 Message saved to storage successfully");
          }
        } catch (storageError) {
          if (kDebugMode) {
            print("📧 Storage error: $storageError");
          }
          // Continue processing even if storage fails
        }
        
        // Add to UI list if it's the current mailbox (with safety checks)
        try {
          if (emails[mailbox] != null) {
            // Check if message already exists to prevent duplicates
            final existingMessage = emails[mailbox]!.firstWhereOrNull(
              (msg) => msg.uid == message.uid || 
                      (msg.sequenceId == message.sequenceId && message.sequenceId != null)
            );
            
            if (existingMessage == null) {
              emails[mailbox]!.insert(0, message);
              emails.refresh();
              
              if (kDebugMode) {
                print("📧 Message added to UI list");
              }
            } else {
              if (kDebugMode) {
                print("📧 Message already exists in UI list, skipping");
              }
            }
          }
        } catch (uiError) {
          if (kDebugMode) {
            print("📧 UI update error: $uiError");
          }
          // Continue processing even if UI update fails
        }
        
        // Queue preview backfill for this message immediately (fast-path)
        try {
          previewService.queueBackfillForMessages(
            mailbox: mailbox,
            messages: [message],
            storage: storage,
            maxJobs: 1,
          );
        } catch (_) {}
        
        // Notify realtime service about new message (with error handling)
        try {
          final realtimeService = RealtimeUpdateService.instance;
          await realtimeService.notifyNewMessages([message]);
          
          if (kDebugMode) {
            print("📧 Realtime service notified successfully");
          }
        } catch (realtimeError) {
          if (kDebugMode) {
            print("📧 Realtime service error: $realtimeError");
          }
          // Continue processing even if realtime notification fails
        }
        
        if (kDebugMode) {
          print("📧 Successfully processed incoming mail");
        }
      } else {
        if (kDebugMode) {
          print("📧 No suitable mailbox found or storage not available for incoming message");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("📧 Critical error handling incoming mail: $e");
        print("📧 Stack trace: ${StackTrace.current}");
      }
      // Don't rethrow - just log the error to prevent GetX crashes
      // The error is already logged, and we don't want to break the event stream
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
      // CRITICAL FIX: Properly reset mailbox context and clear any stale state
      logger.i("Navigating to mailbox: ${mailbox.name}");
      
      // Capture previous mailbox and clear context
      final prev = currentMailbox;
      currentMailbox = null;
      
      // Force UI update to clear any cached state
      update();
      
      // Cancel any pending preview work for previous mailbox
      if (prev != null) {
        try {
          previewService.cancelForMailbox(prev);
        } catch (_) {}
      }

      // Navigate to the mailbox view
      Get.to(() => MailBoxView(mailbox: mailbox));
      
      // Load emails for the new mailbox with proper context setting
      await loadEmailsForBox(mailbox);
      
      // Ensure current mailbox is properly set after loading
      currentMailbox = mailbox;
      
      logger.i("Successfully navigated to mailbox: ${mailbox.name}");
    } catch (e) {
      logger.e("Error in navigatToMailBox: $e");
      // Reset loading state in case of error
      isBoxBusy(false);
      // Reset current mailbox on error
      currentMailbox = null;
    }
  }

  // CRITICAL FIX: Add method to validate message-mailbox consistency
  bool validateMessageMailboxConsistency(MimeMessage message, Mailbox mailbox) {
    try {
      // CRITICAL FIX: Check multiple possible mailbox sources to handle mismatch
      List<Mailbox> mailboxesToCheck = [
        mailbox, // The passed mailbox
        currentMailbox, // The current mailbox
        mailService.client.selectedMailbox, // The IMAP selected mailbox
      ].where((mb) => mb != null).cast<Mailbox>().toSet().toList(); // Remove nulls and duplicates
      
      // Check each possible mailbox source
      for (final checkMailbox in mailboxesToCheck) {
        final mailboxEmails = emails[checkMailbox];
        if (mailboxEmails == null) {
          logger.w("Mailbox ${checkMailbox.name} has no loaded emails");
          continue; // Try next mailbox
        }
        
        // Check if the message is in this mailbox's email list
        final messageExists = mailboxEmails.any((email) => 
          email.uid == message.uid || 
          email.sequenceId == message.sequenceId ||
          (email.decodeSubject() == message.decodeSubject() && 
           email.decodeDate()?.millisecondsSinceEpoch == message.decodeDate()?.millisecondsSinceEpoch)
        );
        
        if (messageExists) {
          logger.i("Message '${message.decodeSubject()}' found in mailbox ${checkMailbox.name}");
          return true; // Message found in at least one mailbox
        }
      }
      
      // CRITICAL FIX: If message not found in any mailbox, check if it's in the currently displayed messages
      final currentlyDisplayedMessages = boxMails;
      final messageInDisplayed = currentlyDisplayedMessages.any((email) => 
        email.uid == message.uid || 
        email.sequenceId == message.sequenceId ||
        (email.decodeSubject() == message.decodeSubject() && 
         email.decodeDate()?.millisecondsSinceEpoch == message.decodeDate()?.millisecondsSinceEpoch)
      );
      
      if (messageInDisplayed) {
        logger.i("Message '${message.decodeSubject()}' found in currently displayed messages");
        return true; // Message is in the displayed list, so it's valid
      }
      
      logger.w("Message '${message.decodeSubject()}' not found in any checked mailbox or displayed messages");
      logger.w("Checked mailboxes: ${mailboxesToCheck.map((mb) => mb.name).join(', ')}");
      logger.w("Currently displayed messages count: ${currentlyDisplayedMessages.length}");
      
      return false;
    } catch (e) {
      logger.e("Error validating message-mailbox consistency: $e");
      // CRITICAL FIX: On validation error, allow navigation to proceed (fail-safe approach)
      logger.w("Validation error occurred, allowing navigation to proceed as fail-safe");
      return true;
    }
  }

  // CRITICAL FIX: Add method to safely navigate to message view with validation
  Future<void> safeNavigateToMessage(MimeMessage message, Mailbox mailbox) async {
    try {
      logger.i("Safe navigation to message: ${message.decodeSubject()} in mailbox: ${mailbox.name}");
      
      // Validate message-mailbox consistency
      if (!validateMessageMailboxConsistency(message, mailbox)) {
        logger.e("Message-mailbox consistency check failed");
        Get.snackbar(
          'Error',
          'The selected email is not available in the current mailbox. Please refresh and try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }
      
      // Ensure current mailbox is set correctly
      currentMailbox = mailbox;
      
      // Navigate based on message type
      final isDraft = message.flags?.contains(MessageFlags.draft) ?? false;
      final isInDraftsMailbox = mailbox.isDrafts;
      final isDraftsMailboxByName = mailbox.name.toLowerCase().contains('draft');
      
      logger.i("Message navigation decision - isDraft: $isDraft, isInDraftsMailbox: $isInDraftsMailbox, isDraftsMailboxByName: $isDraftsMailboxByName");
      
      if (isDraft || isInDraftsMailbox || isDraftsMailboxByName) {
        logger.i("Navigating to compose screen for draft message");
        Get.to(() => const RedesignedComposeScreen(), arguments: {
          'type': 'draft',
          'message': message,
        });
      } else {
        logger.i("Navigating to paged show message screen for regular email");
        try {
          final listRef = emails[mailbox] ?? const <MimeMessage>[];
          int index = 0;
          if (listRef.isNotEmpty) {
            index = listRef.indexWhere((m) =>
                (message.uid != null && m.uid == message.uid) ||
                (message.sequenceId != null && m.sequenceId == message.sequenceId));
            if (index < 0) {
              // Fallback: try by subject+date
              index = listRef.indexWhere((m) =>
                  m.decodeSubject() == message.decodeSubject() &&
                  m.decodeDate()?.millisecondsSinceEpoch == message.decodeDate()?.millisecondsSinceEpoch);
            }
            if (index < 0) index = 0;
          }
          Get.to(() => ShowMessagePager(
                mailbox: mailbox,
                initialMessage: message,
              ));
        } catch (_) {
          // Fallback to single message view
          Get.to(() => ShowMessage(
                message: message,
                mailbox: mailbox,
              ));
        }
      }
    } catch (e) {
      logger.e("Error in safeNavigateToMessage: $e");
      Get.snackbar(
        'Navigation Error',
        'Failed to open the selected email. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
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
      Get.offAll(() => const LoginScreen());
    } catch (e) {
      logger.e(e);
    }
  }

  /// Remove message from UI after successful deletion
  void removeMessageFromUI(MimeMessage message, Mailbox mailbox) {
    try {
      final mailboxEmails = emails[mailbox];
      if (mailboxEmails != null) {
        mailboxEmails.removeWhere((m) => 
          (m.uid != null && m.uid == message.uid) ||
          (m.sequenceId != null && m.sequenceId == message.sequenceId)
        );
        
        // Trigger UI update
        emails.refresh();
        
        logger.i("Removed message from UI: ${message.decodeSubject()}");
      }
    } catch (e) {
      logger.e("Error removing message from UI: $e");
    }
  }

  /// Initialize optimized IDLE service for high-performance real-time updates
  void _initializeOptimizedIdleService() {
    try {
      if (_optimizedIdleStarted) return;
      // Start only if a mailbox is selected to avoid "no mailbox selected" errors
      if (mailService.client.selectedMailbox == null) {
        if (kDebugMode) {
          print('📧 ⏳ Delaying optimized IDLE start: no mailbox selected yet');
        }
        return;
      }

      if (kDebugMode) {
        print('📧 🚀 Starting optimized IDLE service (mailbox selected)');
      }
      
      // Get the optimized IDLE service instance
      final idleService = OptimizedIdleService.instance;
      
      // Start the optimized IDLE service for real-time email updates
      idleService.startOptimizedIdle().then((_) {
        if (kDebugMode) {
          print('📧 ✅ Optimized IDLE service started successfully');
        }
      }).catchError((error) {
        if (kDebugMode) {
          print('📧 ❌ Failed to start optimized IDLE service: $error');
        }
      });

      _optimizedIdleStarted = true;
      
      // Also initialize connection manager
      conn.ConnectionManager.instance;
      if (kDebugMode) {
        print('📧 🔌 Connection manager initialized');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('📧 ❌ Error initializing optimized IDLE service: $e');
      }
    }
  }

  Future<bool> _enterpriseSync(Mailbox mailbox, SQLiteMailboxMimeStorage storage, {required int maxToLoad}) async {
    try {
      // Persist server meta for reference
      await storage.updateMailboxMeta(uidNext: mailbox.uidNext, uidValidity: mailbox.uidValidity);

      // Detect UIDVALIDITY changes
      final state = await storage.getSyncState();
      if (mailbox.uidValidity != null && state.uidValidity != null && mailbox.uidValidity != state.uidValidity) {
        // Reset on UIDVALIDITY change
        try {
          await storage.deleteAllMessages();
          emails[mailbox]?.clear();
        } catch (_) {}
        await storage.resetSyncState(uidNext: mailbox.uidNext, uidValidity: mailbox.uidValidity);
      }

      // Working capacities
      int capacity = math.max(0, maxToLoad - (emails[mailbox]?.length ?? 0));
      if (capacity <= 0) return true;

      // 1) Ascending fetch for new mail beyond lastSyncedUidHigh
      final st1 = await storage.getSyncState();
      if (mailbox.uidNext != null && (st1.lastSyncedUidHigh ?? 0) < (mailbox.uidNext! - 1)) {
        final startUid = (st1.lastSyncedUidHigh ?? 0) + 1;
        final endUid = mailbox.uidNext! - 1;
        if (endUid >= startUid) {
          final take = math.min(capacity, endUid - startUid + 1);
          final fetchEnd = startUid + take - 1;
          progressController.updateStatus('Fetching new mail…');
          final seq = MessageSequence.fromRange(startUid, fetchEnd, isUidSequence: true);
          final fresh = await mailService.client.fetchMessageSequence(
            seq,
            fetchPreference: FetchPreference.envelope,
          ).timeout(const Duration(seconds: 25), onTimeout: () => <MimeMessage>[]);
          if (fresh.isNotEmpty) {
            final existingIds = emails[mailbox]!.map((m) => m.uid).toSet();
            final uniqueFresh = fresh.where((m) => !existingIds.contains(m.uid)).toList();
            if (uniqueFresh.isNotEmpty) {
              // Ensure newest-first when inserting at the top
              try {
                uniqueFresh.sort((a, b) => (b.uid ?? b.sequenceId ?? 0).compareTo(a.uid ?? a.sequenceId ?? 0));
              } catch (_) {}
              emails[mailbox]!.insertAll(0, uniqueFresh);
              previewService.queueBackfillForMessages(
                mailbox: mailbox,
                messages: uniqueFresh,
                storage: storage,
                maxJobs: 20,
              );
              await storage.saveMessageEnvelopes(uniqueFresh);
              await storage.updateSyncState(
                uidNext: mailbox.uidNext,
                uidValidity: mailbox.uidValidity,
                lastSyncedUidHigh: fetchEnd,
                lastSyncFinishedAt: DateTime.now().millisecondsSinceEpoch,
              );
              capacity = math.max(0, capacity - uniqueFresh.length);
              progressController.updateProgress(
                current: maxToLoad - capacity,
                total: maxToLoad,
                progress: maxToLoad > 0 ? ((maxToLoad - capacity) / maxToLoad).clamp(0.0, 1.0) : 1.0,
                subtitle: 'Fetched ${uniqueFresh.length} new emails',
              );
            }
          }
          if (capacity <= 0) return true;
        }
      }

      // 2) Descending fetch for initial-run older mail until window is filled
      final st2 = await storage.getSyncState();
      final initialDone = st2.initialSyncDone;
      if (!initialDone) {
        int? high = st2.lastSyncedUidLow != null
            ? (st2.lastSyncedUidLow! - 1)
            : (mailbox.uidNext != null ? mailbox.uidNext! - 1 : null);
        const int batch = 50;
        while (high != null && high >= 1 && capacity > 0) {
          final low = math.max(1, high - batch + 1);
          final take = math.min(capacity, high - low + 1);
          final adjLow = high - take + 1;
          progressController.updateStatus('Fetching older mail…');
          final seq = MessageSequence.fromRange(adjLow, high, isUidSequence: true);
          final older = await mailService.client.fetchMessageSequence(
            seq,
            fetchPreference: FetchPreference.envelope,
          ).timeout(const Duration(seconds: 30), onTimeout: () => <MimeMessage>[]);
          if (older.isEmpty) break;
          final existingIds = emails[mailbox]!.map((m) => m.uid).toSet();
          final uniqueOlder = older.where((m) => !existingIds.contains(m.uid)).toList();
          if (uniqueOlder.isNotEmpty) {
            emails[mailbox]!.addAll(uniqueOlder);
            previewService.queueBackfillForMessages(
              mailbox: mailbox,
              messages: uniqueOlder,
              storage: storage,
              maxJobs: 20,
            );
            await storage.saveMessageEnvelopes(uniqueOlder);
            // Initialize high watermark if not set
            final newHigh = st2.lastSyncedUidHigh ?? (mailbox.uidNext != null ? mailbox.uidNext! - 1 : high);
            await storage.updateSyncState(
              uidNext: mailbox.uidNext,
              uidValidity: mailbox.uidValidity,
              lastSyncedUidHigh: newHigh,
              lastSyncedUidLow: adjLow,
              lastSyncFinishedAt: DateTime.now().millisecondsSinceEpoch,
            );
            capacity -= uniqueOlder.length;
            progressController.updateProgress(
              current: maxToLoad - capacity,
              total: maxToLoad,
              progress: maxToLoad > 0 ? ((maxToLoad - capacity) / maxToLoad).clamp(0.0, 1.0) : 1.0,
              subtitle: 'Downloading emails… ${maxToLoad - capacity} / $maxToLoad',
            );
          }
          high = adjLow - 1;
        }
        // If we reached the bottom or filled the window, we may choose to mark initial sync as done later
        if (high != null && high < 1) {
          await storage.updateSyncState(initialSyncDone: true);
        }
      }

      return (emails[mailbox]?.length ?? 0) >= maxToLoad;
    } catch (e) {
      logger.w('Enterprise sync step error: $e');
      return false;
    }
  }

  /// Update bottom progress based on how many messages in the window are ready
  // Compute and stamp thread counts for current window (heuristic)
  void _computeAndStampThreadCounts(Mailbox mailbox) {
    try {
      final list = emails[mailbox];
      if (list == null || list.isEmpty) return;
      // Build keys by References/In-Reply-To root, fallback to normalized subject
      String _normalizeSubject(String? s) {
        if (s == null) return '';
        var t = s.trim();
        // Strip common reply/forward prefixes repeatedly
        final rx = RegExp(r'^(?:(re|fw|fwd|aw|wg)\s*:\s*)+', caseSensitive: false);
        t = t.replaceAll(rx, '').trim();
        return t.toLowerCase();
      }
      String _extractRootId(MimeMessage m) {
        String? refs = m.getHeaderValue('references');
        String? irt = m.getHeaderValue('in-reply-to');
        if (refs != null && refs.isNotEmpty) {
          final ids = RegExp(r'<[^>]+>').allMatches(refs).map((m) => m.group(0)!).toList();
          if (ids.isNotEmpty) return ids.first;
        }
        if (irt != null && irt.isNotEmpty) {
          final id = RegExp(r'<[^>]+>').firstMatch(irt)?.group(0);
          if (id != null) return id;
        }
        final subj = _normalizeSubject(m.decodeSubject() ?? m.envelope?.subject);
        return 'subj::$subj';
      }
      final counts = <String, int>{};
      for (final m in list) {
        final key = _extractRootId(m);
        counts[key] = (counts[key] ?? 0) + 1;
      }
      for (final m in list) {
        final key = _extractRootId(m);
        final c = counts[key] ?? 1;
        try { m.setHeader('x-thread-count', '$c'); } catch (_) {}
        try { bumpMessageMeta(mailbox, m); } catch (_) {}
      }
    } catch (_) {}
  }

  void _updateReadyProgress(Mailbox mailbox, int limit) {
    try {
      final list = emails[mailbox] ?? const <MimeMessage>[];
      int ready = 0;
      final take = list.length < limit ? list.length : limit;
      for (int i = 0; i < take; i++) {
        final m = list[i];
        if (m.getHeaderValue('x-ready') == '1') ready++;
      }
      if (limit > 0) {
        progressController.updateProgress(
          current: ready,
          total: limit,
          progress: (ready / limit).clamp(0.0, 1.0),
          subtitle: 'Preparing messages… $ready/$limit',
        );
      }
    } catch (_) {}
  }

  /// Eagerly fetch full content (body + attachment metadata) for the top [limit] messages
  Future<void> _prefetchFullContentForWindow(Mailbox mailbox, {required int limit, bool quiet = false}) async {
    try {
      final list = List<MimeMessage>.from((emails[mailbox] ?? const <MimeMessage>[])
          .take(limit));
      if (list.isEmpty) return;

      // Ensure IMAP has this mailbox selected (avoid selection thrash if already selected)
      try {
        if (mailService.client.selectedMailbox?.encodedPath != mailbox.encodedPath) {
          await mailService.client.selectMailbox(mailbox).timeout(const Duration(seconds: 8));
        }
      } catch (_) {}

      final storage = mailboxStorage[mailbox];
      const int concurrency = 4;
      int index = 0;
      int completed = 0;

      Future<void> worker() async {
        while (true) {
          MimeMessage? base;
          // Pull next message atomically
          if (index < list.length) {
            base = list[index++];
          } else {
            return;
          }
          try {
            // Skip if mailbox changed mid-run
            if (currentMailbox?.encodedPath != mailbox.encodedPath) return;

            // Skip already-ready messages to avoid redundant work
            if (base.getHeaderValue('x-ready') == '1') {
              continue;
            }

            // Fetch full content for this single message
            final seq = MessageSequence.fromMessage(base);
            final fetched = await mailService.client.fetchMessageSequence(
              seq,
              fetchPreference: FetchPreference.fullWhenWithinSize,
            ).timeout(const Duration(seconds: 25), onTimeout: () => <MimeMessage>[]);
            if (fetched.isEmpty) continue;
            final full = fetched.first;

            // Compute preview
            String preview = '';
            try {
              final plain = full.decodeTextPlainPart();
              if (plain != null && plain.isNotEmpty) {
                preview = plain.replaceAll(RegExp(r'\s+'), ' ').trim();
              } else {
                final html = full.decodeTextHtmlPart();
                if (html != null && html.isNotEmpty) {
                  final stripped = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
                  preview = stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
                }
              }
              if (preview.length > 140) preview = preview.substring(0, 140);
            } catch (_) {}

            bool hasAtt = false;
            try { hasAtt = full.hasAttachments(); } catch (_) {}

            // Persist preview/attachments to DB
            try {
              await storage?.updatePreviewAndAttachments(
                uid: full.uid,
                sequenceId: full.sequenceId,
                previewText: preview,
                hasAttachments: hasAtt,
              );
              // Also persist envelope + basic meta for accurate tiles
              await storage?.updateEnvelopeFromMessage(full);
            } catch (_) {}

            // Persist sanitized blocked HTML to offline store (no attachments here)
            try {
              final accountEmail = mailService.account.email;
              final mailboxPath = mailbox.encodedPath.isNotEmpty ? mailbox.encodedPath : (mailbox.path);
              final uidValidity = mailbox.uidValidity ?? 0;
              String? rawHtml = full.decodeTextHtmlPart();
              String? plain = full.decodeTextPlainPart();
              String? sanitizedHtml;
              if (rawHtml != null && rawHtml.trim().isNotEmpty) {
                // Pre-sanitize large HTML off main thread
                String preprocessed = rawHtml;
                if (rawHtml.length > 100 * 1024) {
                  try { preprocessed = await MessageContentStore.sanitizeHtmlInIsolate(rawHtml); } catch (_) {}
                }
                final enhanced = HtmlEnhancer.enhanceEmailHtml(
                  message: full,
                  rawHtml: preprocessed,
                  darkMode: false, // storage-time normalization only
                  blockRemoteImages: true,
                  deviceWidthPx: 1024.0,
                );
                sanitizedHtml = enhanced.html;
              }
              if ((sanitizedHtml != null && sanitizedHtml.isNotEmpty) || (plain != null && plain.isNotEmpty)) {
                await MessageContentStore.instance.upsertContent(
                  accountEmail: accountEmail,
                  mailboxPath: mailboxPath,
                  uidValidity: uidValidity,
                  uid: full.uid ?? -1,
                  plainText: plain,
                  htmlSanitizedBlocked: sanitizedHtml,
                  sanitizedVersion: 2,
                  forceMaterialize: FeatureFlags.instance.htmlMaterializeInitialWindow,
                );
              }
            } catch (_) {}

            // Replace in-memory message with full version
            try {
              final listRef = emails[mailbox];
              if (listRef != null) {
                final idx = listRef.indexWhere((m) =>
                  (full.uid != null && m.uid == full.uid) ||
                  (full.sequenceId != null && m.sequenceId == full.sequenceId));
                if (idx != -1) {
                  listRef[idx] = full;
                }
              }
            } catch (_) {}

            // Stamp headers for immediate UI benefit
            try {
              if (preview.isNotEmpty) full.setHeader('x-preview', preview);
              full.setHeader('x-has-attachments', hasAtt ? '1' : '0');
              // Stamp thread count for fast tile rendering (heuristic fallback if seq is null)
              try {
                int tc = 0;
                try {
                  final seq = full.threadSequence;
                  tc = seq == null ? 0 : seq.toList().length;
                } catch (_) {}
                if (tc <= 1) {
                  // Fallback based on subject/references within current list window
                  try {
                    final listRef = emails[mailbox] ?? const <MimeMessage>[];
                    String _norm(String? s) {
                      if (s == null) return '';
                      var t = s.trim();
                      final rx = RegExp(r'^(?:(re|fw|fwd|aw|wg)\s*:\s*)+', caseSensitive: false);
                      t = t.replaceAll(rx, '').trim();
                      return t.toLowerCase();
                    }
                    String key() {
                      final refs = full.getHeaderValue('references');
                      if (refs != null && refs.isNotEmpty) {
                        final ids = RegExp(r'<[^>]+>').allMatches(refs).map((m) => m.group(0)!).toList();
                        if (ids.isNotEmpty) return ids.first;
                      }
                      final irt = full.getHeaderValue('in-reply-to');
                      if (irt != null && irt.isNotEmpty) {
                        final id = RegExp(r'<[^>]+>').firstMatch(irt)?.group(0);
                        if (id != null) return id;
                      }
                      return 'subj::'+_norm(full.decodeSubject() ?? full.envelope?.subject);
                    }
                    final k = key();
                    tc = listRef.where((m) {
                      String kk;
                      final refs = m.getHeaderValue('references');
                      if (refs != null && refs.isNotEmpty) {
                        final ids = RegExp(r'<[^>]+>').allMatches(refs).map((mm) => mm.group(0)!).toList();
                        kk = ids.isNotEmpty ? ids.first : '';
                      } else {
                        final irt2 = m.getHeaderValue('in-reply-to');
                        if (irt2 != null && irt2.isNotEmpty) {
                          kk = RegExp(r'<[^>]+>').firstMatch(irt2)?.group(0) ?? '';
                        } else {
                          kk = 'subj::'+_norm(m.decodeSubject() ?? m.envelope?.subject);
                        }
                      }
                      return kk == k;
                    }).length;
                  } catch (_) {}
                }
                full.setHeader('x-thread-count', '${tc <= 0 ? 1 : tc}');
              } catch (_) {}
              full.setHeader('x-ready', '1');
              // Notify tile listeners
              try { bumpMessageMeta(mailbox, full); } catch (_) {}
            } catch (_) {}

            // Optional small attachment prefetch
            await _maybePrefetchSmallAttachments(mailbox, full);

          } catch (_) {
            // Ignore individual fetch errors
          } finally {
            completed++;
            // Update READY-based progress to align counter with tiles becoming visible
            if (!quiet) {
              _updateReadyProgress(mailbox, limit);
              // Throttled UI refresh to reflect new ready tiles in real time
              if (completed % 3 == 0) {
                try {
                  emails.refresh();
                  update();
                } catch (_) {}
              }
            }
          }
        }
      }

      // Launch workers
      final tasks = List.generate(concurrency, (_) => worker());
      await Future.wait(tasks);

      // Trigger UI update
      emails.refresh();
      update();
    } catch (_) {
      // Best-effort prefetch; ignore errors
    }
  }

  // Fast preview builder for handful of new messages to update tiles immediately
  Future<void> _fastPreviewForNewMessages(Mailbox mailbox, List<MimeMessage> messages) async {
    try {
      if (messages.isEmpty) return;

      // Ensure selection (best-effort, short timeout)
      try {
        if (mailService.client.selectedMailbox?.encodedPath != mailbox.encodedPath) {
          await mailService.client
              .selectMailbox(mailbox)
              .timeout(const Duration(seconds: 6));
        }
      } catch (_) {}

      final storage = mailboxStorage[mailbox];

      for (final base in messages) {
        try {
          // Fetch full content quick path
          final seq = MessageSequence.fromMessage(base);
          final fetched = await mailService.client
              .fetchMessageSequence(
                seq,
                fetchPreference: FetchPreference.fullWhenWithinSize,
              )
              .timeout(const Duration(seconds: 10), onTimeout: () => <MimeMessage>[]);
          if (fetched.isEmpty) continue;
          final full = fetched.first;

          // Compute preview
          String preview = '';
          try {
            final plain = full.decodeTextPlainPart();
            if (plain != null && plain.isNotEmpty) {
              preview = plain.replaceAll(RegExp(r'\s+'), ' ').trim();
            } else {
              final html = full.decodeTextHtmlPart();
              if (html != null && html.isNotEmpty) {
                final stripped = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
                preview = stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
              }
            }
            if (preview.length > 140) preview = preview.substring(0, 140);
          } catch (_) {}

          // Persist preview and stamp headers for tile
          try {
            if (preview.isNotEmpty) full.setHeader('x-preview', preview);
            full.setHeader('x-ready', '1');
          } catch (_) {}

          try {
            await storage?.updatePreviewAndAttachments(
              uid: full.uid,
              sequenceId: full.sequenceId,
              previewText: preview,
              hasAttachments: full.hasAttachments(),
            );
            // Persist envelope + basic meta so tiles can show sender/subject immediately
            await storage?.updateEnvelopeFromMessage(full);
          } catch (_) {}

          // Replace in-memory instance if present for immediate UI update
          try {
            final listRef = emails[mailbox];
            if (listRef != null) {
              final idx = listRef.indexWhere((m) =>
                  (full.uid != null && m.uid == full.uid) ||
                  (full.sequenceId != null && m.sequenceId == full.sequenceId));
              if (idx != -1) {
                listRef[idx] = full;
              }
            }
          } catch (_) {}

          // Notify tile meta changes and refresh UI
          try { bumpMessageMeta(mailbox, full); } catch (_) {}
          emails.refresh();
          update();
        } catch (_) {}
      }
    } catch (_) {}
  }

  // Ensure envelope JSON exists for new messages to avoid Unknown/No Subject tiles
  Future<void> _ensureEnvelopesForNewMessages(Mailbox mailbox, List<MimeMessage> messages) async {
    try {
      if (messages.isEmpty) return;
      final storage = mailboxStorage[mailbox];
      for (final base in messages) {
        // Skip if envelope already has from+subject
        final hasFrom = base.envelope?.from?.isNotEmpty == true || (base.from?.isNotEmpty == true);
        final hasSubj = (base.envelope?.subject?.isNotEmpty == true) || ((base.decodeSubject() ?? '').isNotEmpty);
        if (hasFrom && hasSubj) continue;
        try {
          final seq = MessageSequence.fromMessage(base);
          final fetched = await mailService.client
              .fetchMessageSequence(seq, fetchPreference: FetchPreference.envelope)
              .timeout(const Duration(seconds: 8), onTimeout: () => <MimeMessage>[]);
          if (fetched.isEmpty) continue;
          final envMsg = fetched.first;
          // Update in-memory instance if present
          try {
            final listRef = emails[mailbox];
            if (listRef != null) {
              final idx = listRef.indexWhere((m) =>
                  (envMsg.uid != null && m.uid == envMsg.uid) ||
                  (envMsg.sequenceId != null && m.sequenceId == envMsg.sequenceId));
              if (idx != -1) {
                // Merge envelope into existing message instance if full not available yet
                listRef[idx].envelope = envMsg.envelope;
                // Also hydrate top-level from if missing so details card shows proper sender
                try {
                  if ((listRef[idx].from == null || listRef[idx].from!.isEmpty) && (envMsg.envelope?.from?.isNotEmpty ?? false)) {
                    listRef[idx].from = envMsg.envelope!.from;
                  }
                } catch (_) {}
                bumpMessageMeta(mailbox, listRef[idx]);
              }
            }
          } catch (_) {}
          // Persist in DB for future loads
          try { await storage?.updateEnvelopeFromMessage(envMsg); } catch (_) {}
        } catch (_) {}
      }
      // Refresh UI after warming envelopes
      emails.refresh();
      update();
    } catch (_) {}
  }

  // Quiet foreground polling: start/stop and one-shot poll
  void _startForegroundPolling(Mailbox mailbox) {
    try {
      // If optimized IDLE is running, do not start foreground polling to avoid contention
      final idle = OptimizedIdleService.instance;
      if (idle.isRunning || idle.isIdleActive) {
        if (kDebugMode) {
          print('📧 ⏸️ Skipping foreground polling because optimized IDLE is active');
        }
        return;
      }

      _stopForegroundPolling();

      // Respect user settings
      final ff = FeatureFlags.instance;
      if (!ff.foregroundPollingEnabled) {
        if (kDebugMode) {
          print('📧 ⏸️ Foreground polling disabled by settings');
        }
        return;
      }
      final secs = ff.foregroundPollingIntervalSecs;
      final clamped = secs < 15 ? 15 : secs; // minimum safety interval
      pollingInterval = Duration(seconds: clamped);

      _pollingMailboxPath = mailbox.encodedPath;
      _pollTimer = Timer.periodic(pollingInterval, (t) async {
        if (_pollingMailboxPath != mailbox.encodedPath) return; // mailbox switched
        if (isLoadingEmails.value || isPrefetching.value) return; // avoid overlap
        // Also skip if optimized IDLE has become active since starting the timer
        if (idle.isRunning || idle.isIdleActive) return;
        try {
          await _pollOnce(mailbox);
        } catch (e) {
          logger.w('Polling error: $e');
        }
      });
      if (kDebugMode) {
        print('📧 🔄 Foreground polling started for ${mailbox.name} every ${pollingInterval.inSeconds}s');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 ⚠️ Failed to start polling: $e');
      }
    }
  }

  void _stopForegroundPolling() {
    try {
      _pollTimer?.cancel();
      _pollTimer = null;
      _pollingMailboxPath = null;
      if (kDebugMode) {
        print('📧 ⏹️ Foreground polling stopped');
      }
    } catch (_) {}
  }

  // Public method to apply updated polling settings immediately
  void restartForegroundPolling() {
    try {
      final m = currentMailbox;
      _stopForegroundPolling();
      if (m != null) {
        _startForegroundPolling(m);
      }
    } catch (_) {}
  }

  Future<void> _pollOnce(Mailbox mailbox, {bool force = false}) async {
    try {
      // Skip polling if optimized IDLE is active to avoid IDLE/DONE contention, unless forced
      final idle = OptimizedIdleService.instance;
      if (!force && (idle.isRunning || idle.isIdleActive)) return;

      final storage = mailboxStorage[mailbox];
      if (storage == null) return;

      // Ensure connection and selection
      if (!mailService.client.isConnected) {
        try { await mailService.connect().timeout(const Duration(seconds: 8)); } catch (_) { return; }
      }
      if (mailService.client.selectedMailbox?.encodedPath != mailbox.encodedPath) {
        try { await mailService.client.selectMailbox(mailbox).timeout(const Duration(seconds: 8)); } catch (_) { return; }
      }

      // Incremental sync: fetch only what capacity allows beyond current window
      final currentLen = emails[mailbox]?.length ?? 0;
      final target = math.min(mailbox.messagesExists, math.max(200, currentLen + 20));
      final satisfied = await _enterpriseSync(mailbox, storage, maxToLoad: target);
      if (!satisfied) return;

      // Quiet prefetch for a small number of top unready messages
      await _prefetchTopUnready(mailbox, limit: math.min(200, emails[mailbox]?.length ?? 0), maxToPrefetch: 12);

      // Trigger reactive update without UI progress noise
      emails.refresh();
      update();
    } catch (e) {
      logger.w('Polling step failed: $e');
    }
  }

  Future<void> _prefetchTopUnready(Mailbox mailbox, {required int limit, int maxToPrefetch = 10}) async {
    try {
      final list = List<MimeMessage>.from((emails[mailbox] ?? const <MimeMessage>[]).take(limit));
      if (list.isEmpty) return;
      final unready = <MimeMessage>[];
      for (final m in list) {
        if (m.getHeaderValue('x-ready') != '1') {
          unready.add(m);
          if (unready.length >= maxToPrefetch) break;
        }
      }
      if (unready.isEmpty) return;
      await _prefetchFullContentForMessages(mailbox, unready, quiet: true);
    } catch (_) {}
  }

  Future<void> _prefetchFullContentForMessages(Mailbox mailbox, List<MimeMessage> messages, {bool quiet = false}) async {
    try {
      if (messages.isEmpty) return;
      // Ensure selection
      try {
        if (mailService.client.selectedMailbox?.encodedPath != mailbox.encodedPath) {
          await mailService.client.selectMailbox(mailbox).timeout(const Duration(seconds: 8));
        }
      } catch (_) {}

      final storage = mailboxStorage[mailbox];
      const int concurrency = 2;
      int index = 0;

      Future<void> worker() async {
        while (true) {
          MimeMessage? base;
          if (index < messages.length) {
            base = messages[index++];
          } else {
            return;
          }
          try {
            if (currentMailbox?.encodedPath != mailbox.encodedPath) return;
            if (base.getHeaderValue('x-ready') == '1') continue;

            final seq = MessageSequence.fromMessage(base);
            final fetched = await mailService.client.fetchMessageSequence(
              seq,
              fetchPreference: FetchPreference.fullWhenWithinSize,
            ).timeout(const Duration(seconds: 20), onTimeout: () => <MimeMessage>[]);
            if (fetched.isEmpty) continue;
            final full = fetched.first;

            // Compute preview
            String preview = '';
            try {
              final plain = full.decodeTextPlainPart();
              if (plain != null && plain.isNotEmpty) {
                preview = plain.replaceAll(RegExp(r'\s+'), ' ').trim();
              } else {
                final html = full.decodeTextHtmlPart();
                if (html != null && html.isNotEmpty) {
                  final stripped = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
                  preview = stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
                }
              }
              if (preview.length > 140) preview = preview.substring(0, 140);
            } catch (_) {}

            bool hasAtt = false;
            try { hasAtt = full.hasAttachments(); } catch (_) {}

            // Persist preview/attachments to DB
            try {
              await storage?.updatePreviewAndAttachments(
                uid: full.uid,
                sequenceId: full.sequenceId,
                previewText: preview,
                hasAttachments: hasAtt,
              );
              // Also persist envelope + basic meta for accurate tiles
              await storage?.updateEnvelopeFromMessage(full);
            } catch (_) {}

            // Persist sanitized blocked HTML to offline store
            try {
              final accountEmail = mailService.account.email;
              final mailboxPath = mailbox.encodedPath.isNotEmpty ? mailbox.encodedPath : (mailbox.path);
              final uidValidity = mailbox.uidValidity ?? 0;
              String? rawHtml = full.decodeTextHtmlPart();
              String? plain = full.decodeTextPlainPart();
              String? sanitizedHtml;
              if (rawHtml != null && rawHtml.trim().isNotEmpty) {
                String preprocessed = rawHtml;
                if (rawHtml.length > 100 * 1024) {
                  try { preprocessed = await MessageContentStore.sanitizeHtmlInIsolate(rawHtml); } catch (_) {}
                }
                final enhanced = HtmlEnhancer.enhanceEmailHtml(
                  message: full,
                  rawHtml: preprocessed,
                  darkMode: false,
                  blockRemoteImages: true,
                  deviceWidthPx: 1024.0,
                );
                sanitizedHtml = enhanced.html;
              }
              if ((sanitizedHtml != null && sanitizedHtml.isNotEmpty) || (plain != null && plain.isNotEmpty)) {
                await MessageContentStore.instance.upsertContent(
                  accountEmail: accountEmail,
                  mailboxPath: mailboxPath,
                  uidValidity: uidValidity,
                  uid: full.uid ?? -1,
                  plainText: plain,
                  htmlSanitizedBlocked: sanitizedHtml,
                  sanitizedVersion: 2,
                  forceMaterialize: false,
                );
              }
            } catch (_) {}

            // Replace in-memory message with full version
            try {
              final listRef = emails[mailbox];
              if (listRef != null) {
                final idx = listRef.indexWhere((m) =>
                  (full.uid != null && m.uid == full.uid) ||
                  (full.sequenceId != null && m.sequenceId == full.sequenceId));
                if (idx != -1) {
                  listRef[idx] = full;
                }
              }
            } catch (_) {}

            // Stamp headers
            try {
              if (preview.isNotEmpty) full.setHeader('x-preview', preview);
              full.setHeader('x-has-attachments', hasAtt ? '1' : '0');
              // Stamp thread count for fast tile rendering (heuristic fallback)
              try {
                int tc = 0;
                try {
                  final seq = full.threadSequence;
                  tc = seq == null ? 0 : seq.toList().length;
                } catch (_) {}
                if (tc <= 1) {
                  try {
                    final listRef = emails[mailbox] ?? const <MimeMessage>[];
                    String _norm(String? s) {
                      if (s == null) return '';
                      var t = s.trim();
                      final rx = RegExp(r'^(?:(re|fw|fwd|aw|wg)\s*:\s*)+', caseSensitive: false);
                      t = t.replaceAll(rx, '').trim();
                      return t.toLowerCase();
                    }
                    String key() {
                      final refs = full.getHeaderValue('references');
                      if (refs != null && refs.isNotEmpty) {
                        final ids = RegExp(r'<[^>]+>').allMatches(refs).map((m) => m.group(0)!).toList();
                        if (ids.isNotEmpty) return ids.first;
                      }
                      final irt = full.getHeaderValue('in-reply-to');
                      if (irt != null && irt.isNotEmpty) {
                        final id = RegExp(r'<[^>]+>').firstMatch(irt)?.group(0);
                        if (id != null) return id;
                      }
                      return 'subj::'+_norm(full.decodeSubject() ?? full.envelope?.subject);
                    }
                    final k = key();
                    tc = listRef.where((m) {
                      String kk;
                      final refs = m.getHeaderValue('references');
                      if (refs != null && refs.isNotEmpty) {
                        final ids = RegExp(r'<[^>]+>').allMatches(refs).map((mm) => mm.group(0)!).toList();
                        kk = ids.isNotEmpty ? ids.first : '';
                      } else {
                        final irt2 = m.getHeaderValue('in-reply-to');
                        if (irt2 != null && irt2.isNotEmpty) {
                          kk = RegExp(r'<[^>]+>').firstMatch(irt2)?.group(0) ?? '';
                        } else {
                          kk = 'subj::'+_norm(m.decodeSubject() ?? m.envelope?.subject);
                        }
                      }
                      return kk == k;
                    }).length;
                  } catch (_) {}
                }
                full.setHeader('x-thread-count', '${tc <= 0 ? 1 : tc}');
              } catch (_) {}
              full.setHeader('x-ready', '1');
              try { bumpMessageMeta(mailbox, full); } catch (_) {}
            } catch (_) {}

            // Optional small attachment prefetch
            await _maybePrefetchSmallAttachments(mailbox, full);
          } catch (_) {
            // ignore per-message errors
          } finally {
            if (!quiet) {
              _updateReadyProgress(mailbox, math.min(200, emails[mailbox]?.length ?? 0));
            }
          }
        }
      }

      await Future.wait(List.generate(concurrency, (_) => worker()));
      // Trigger UI update quietly
      emails.refresh();
      update();
    } catch (_) {}
  }

  /// Public: Prefetch a single message's content quietly (body + attachments meta + offline HTML)
  Future<void> prefetchMessageContent(Mailbox mailbox, MimeMessage message, {bool quiet = true}) async {
    try {
      await _prefetchFullContentForMessages(mailbox, [message], quiet: quiet);
    } catch (_) {}
  }

  /// Prefetch small attachments for a message when enabled by feature flag.
  /// Limits: up to [maxAttachments] per message and [maxBytesPerAttachment] bytes each.
  Future<void> _maybePrefetchSmallAttachments(
    Mailbox mailbox,
    MimeMessage full, {
    int maxAttachments = 2,
    int maxBytesPerAttachment = 512 * 1024,
  }) async {
    try {
      if (!FeatureFlags.instance.attachmentPrefetchEnabled) return;

      // Ensure correct mailbox is selected
      try {
        if (mailService.client.selectedMailbox?.encodedPath != mailbox.encodedPath) {
          await mailService.client.selectMailbox(mailbox).timeout(const Duration(seconds: 8));
        }
      } catch (_) {}

      final infos = full.findContentInfo(disposition: ContentDisposition.attachment);
      if (infos.isEmpty) return;

      int prefetched = 0;
      for (final info in infos) {
        if (prefetched >= maxAttachments) break;
        final size = info.size ?? 0;
        if (size <= 0 || size > maxBytesPerAttachment) continue;
        try {
          final part = await mailService.client.fetchMessagePart(full, info.fetchId)
              .timeout(const Duration(seconds: 12));
          final encoding = part.getHeaderValue('content-transfer-encoding');
          final data = part.mimeData?.decodeBinary(encoding);
          if (data != null) {
            cacheManager.cacheAttachmentData(full, part, data);
            prefetched++;
          }
        } catch (_) {
          // Ignore individual attachment errors
        }
      }
    } catch (_) {}
  }

  /// Quick refresh of top-of-list messages without full reload. Useful for pull-to-refresh.
  Future<void> refreshTopNow() async {
    try {
      final m = currentMailbox ?? mailBoxInbox;
      if (m.name.isEmpty) return;

      // Force an incremental sync even if optimized IDLE is active, pausing IDLE briefly to avoid contention
      await _withIdlePause(() async {
        await _pollOnce(m, force: true);
      });

      // Ensure newest first and trigger UI
      try {
        final list = emails[m];
        if (list != null && list.isNotEmpty) {
          list.sort((a, b) {
            final da = a.decodeDate();
            final db = b.decodeDate();
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return db.compareTo(da);
          });
        }
      } catch (_) {}
      emails.refresh();
      update();
    } catch (_) {}
  }

  // Pause optimized IDLE around a critical foreground sync to avoid DONE contention
  Future<T> _withIdlePause<T>(Future<T> Function() action) async {
    final idle = OptimizedIdleService.instance;
    final wasRunning = idle.isRunning || idle.isIdleActive;
    if (wasRunning) {
      try { await idle.stopOptimizedIdle(); } catch (_) {}
    }
    try {
      return await action();
    } finally {
      if (wasRunning) {
        try { await idle.startOptimizedIdle(); } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    // Clean up stream subscriptions
    _messageUpdateSubscription?.cancel();
    _mailboxUpdateSubscription?.cancel();
    
    // Stop optimized IDLE service
    try {
      OptimizedIdleService.instance.stopOptimizedIdle();
      if (kDebugMode) {
        print('📧 🛑 Optimized IDLE service stopped');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 ⚠️ Error stopping optimized IDLE service: $e');
      }
    }
    
    MailService.instance.dispose();

    // Dispose meta notifiers
    for (final n in _messageMeta.values) {
      try { n.dispose(); } catch (_) {}
    }
    _messageMeta.clear();

    super.dispose();
  }
}
