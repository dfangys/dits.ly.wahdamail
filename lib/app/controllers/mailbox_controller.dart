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
import 'package:wahda_bank/services/email_notification_service.dart';
import 'package:wahda_bank/services/outbox_service.dart';
import 'package:rxdart/rxdart.dart' hide Rx;
import 'package:wahda_bank/views/compose/redesigned_compose_screen.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';
import 'package:wahda_bank/views/view/showmessage/show_message_pager.dart';
import 'package:wahda_bank/views/box/mailbox_view.dart';
import 'package:wahda_bank/views/settings/data/swap_data.dart';
import 'package:workmanager/workmanager.dart';
import 'package:wahda_bank/widgets/progress_indicator_widget.dart';
import 'package:wahda_bank/app/constants/app_constants.dart';
import '../../views/authantication/screens/login/login.dart';
import 'package:wahda_bank/services/imap_command_queue.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';
import 'package:wahda_bank/shared/utils/hashing.dart';
import 'package:wahda_bank/shared/ddd_ui_wiring.dart';

class _LocalDbLoadResult {
  final int loaded;
  final int localCount;
  final bool loadedFromDb;
  const _LocalDbLoadResult({
    required this.loaded,
    required this.localCount,
    required this.loadedFromDb,
  });
}

class MailBoxController extends GetxController {
  // Retry guard for initial mailbox loading to handle transient connection limits on hot restart
  int _loadMailboxesRetries = 0;
  static const int _loadMailboxesMaxRetries = 4;
  Duration _loadMailboxesBackoff(int attempt) =>
      Duration(seconds: 2 * (attempt + 1));
  // ENHANCED: Add IndexedCache for high-performance message caching
  late final IndexedCache<MimeMessage> _messageCache;
  static const int _maxCacheSize = 200; // Optimized for mobile devices
  late MailService mailService;
  // Progress controller for download/loading feedback
  final EmailDownloadProgressController progressController =
      Get.find<EmailDownloadProgressController>();
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

  // Background monitor for special-use mailboxes (Drafts, Sent, Trash, Junk)
  Timer? _specialMonitorTimer;

  // Auto background refresh for current mailbox using IDLE meta snapshots
  Timer? _autoRefreshTimer;
  bool _autoSyncInFlight = false;
  DateTime _lastAutoSyncRun = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, int?> _mailboxUidNextSnapshot = {};
  final Map<String, int?> _mailboxExistsSnapshot = {};

  // Replace Hive storage with SQLite storage
  final RxMap<Mailbox, SQLiteMailboxMimeStorage> mailboxStorage =
      <Mailbox, SQLiteMailboxMimeStorage>{}.obs;
  final RxMap<Mailbox, List<MimeMessage>> emails =
      <Mailbox, List<MimeMessage>>{}.obs;

  // Per-message meta notifiers (preview, flags, etc.) to enable fine-grained updates
  final Map<String, ValueNotifier<int>> _messageMeta =
      <String, ValueNotifier<int>>{};
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
      // Fallback by name
      try {
        return mailboxes.firstWhere(
          (m) => m.name.toLowerCase().contains('draft'),
        );
      } catch (_) {}
      logger.w("Drafts mailbox not found: $e");
      return null;
    }
  }

  // Getter for Sent mailbox using flags with name fallbacks
  Mailbox? get sentMailbox {
    try {
      return mailboxes.firstWhere((m) => m.isSent);
    } catch (_) {
      try {
        return mailboxes.firstWhere(
          (m) =>
              m.name.toLowerCase() == 'sent' ||
              m.name.toLowerCase().contains('sent'),
        );
      } catch (e) {
        logger.w("Sent mailbox not found: $e");
        return null;
      }
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
        logger.i(
          "Draft saved successfully with target sequence: ${result.targetSequence}",
        );

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
        BackgroundService.scheduleDerivedFieldsBackfill(
          perMailboxLimit: 5000,
          batchSize: 800,
        );
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
      _mailboxUpdateSubscription = realtimeService.mailboxUpdateStream.listen((
        update,
      ) {
        try {
          if (kDebugMode) {
            print('📧 Received mailbox update: ${update.type}');
          }

          if (update.type == MailboxUpdateType.messagesAdded &&
              update.messages != null) {
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
          final exists = inboxMessages.any(
            (m) =>
                m.uid == message.uid ||
                (m.sequenceId == message.sequenceId &&
                    message.sequenceId != null),
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
        final index = currentMessages.indexWhere(
          (m) =>
              m.uid == message.uid ||
              (m.sequenceId == message.sequenceId &&
                  message.sequenceId != null),
        );

        if (index != -1) {
          currentMessages[index] = message; // Update with new read status
          update(); // Trigger UI update

          if (kDebugMode) {
            print(
              '📧 Updated message read status: ${message.isSeen ? "read" : "unread"}',
            );
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
        final index = currentMessages.indexWhere(
          (m) =>
              m.uid == message.uid ||
              (m.sequenceId == message.sequenceId &&
                  message.sequenceId != null),
        );

        if (index != -1) {
          currentMessages[index] = message; // Update with new flag status
          update(); // Trigger UI update

          if (kDebugMode) {
            print(
              '📧 Updated message flag status: ${message.isFlagged ? "flagged" : "unflagged"}',
            );
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
        currentMessages.removeWhere(
          (m) =>
              m.uid == message.uid ||
              (m.sequenceId == message.sequenceId &&
                  message.sequenceId != null),
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
  Future<void> _handleNewMessagesInMailbox(
    Mailbox mailbox,
    List<MimeMessage> newMessages,
  ) async {
    try {
      // Robust mailbox matching: by encodedPath (preferred), name (case-insensitive), or inbox flag
      bool isSameMailbox = false;
      final current = currentMailbox;
      if (current != null) {
        if (current.encodedPath.isNotEmpty && mailbox.encodedPath.isNotEmpty) {
          isSameMailbox =
              current.encodedPath.toLowerCase() ==
              mailbox.encodedPath.toLowerCase();
        }
        if (!isSameMailbox) {
          isSameMailbox =
              current.name.toLowerCase() == mailbox.name.toLowerCase();
        }
        if (!isSameMailbox && current.isInbox && mailbox.isInbox) {
          isSameMailbox = true;
        }
      }

      // Only update if it's the current mailbox
      if (isSameMailbox) {
        final currentMessages = emails[current];
        if (currentMessages != null) {
          // Collect truly new messages to persist and for fast-path hydration
          final List<MimeMessage> persistBatch = [];
          for (final message in newMessages) {
            // Check if message already exists
            final exists = currentMessages.any(
              (m) =>
                  m.uid == message.uid ||
                  (m.sequenceId == message.sequenceId &&
                      message.sequenceId != null),
            );

            if (!exists) {
              currentMessages.insert(0, message); // Add to beginning
              persistBatch.add(message);
              try {
                if (current != null) bumpMessageMeta(current, message);
              } catch (_) {}
            }
          }
          // Trigger reactive updates
          emails.refresh();
          update();

          // Persist new envelopes immediately so storage-backed views update instantly
          final storage = mailboxStorage[current];
          if (storage != null && persistBatch.isNotEmpty) {
            try {
              await storage.saveMessageEnvelopes(persistBatch);
            } catch (_) {}
          }

          // Kick off a very fast preview/backfill for the top few new messages
          if (current != null)
            unawaited(
              _fastPreviewForNewMessages(current, newMessages.take(3).toList()),
            );
          // Warm up envelopes for all new messages so tiles don't show Unknown/No Subject
          if (current != null)
            unawaited(_ensureEnvelopesForNewMessages(current, newMessages));

          // Also queue background backfill for the whole batch
          if (storage != null && newMessages.isNotEmpty) {
            try {
              if (current != null) {
                previewService.queueBackfillForMessages(
                  mailbox: current,
                  messages: newMessages,
                  storage: storage,
                  maxJobs: 10,
                );
              }
            } catch (_) {}
          }

          if (kDebugMode) {
            print(
              '📧 Added ${newMessages.length} new messages to mailbox UI (${current?.name ?? 'unknown'})',
            );
          }
        }
      } else {
        if (kDebugMode) {
          print(
            "📧 Mailbox update ignored (current=${currentMailbox?.name}, update=${mailbox.name})",
          );
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
      final inbox =
          mailboxes.firstWhereOrNull((m) => m.isInbox) ??
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
      // Attempt to connect with a short timeout. On hot restart, servers may still count the previous session.
      try {
        await mailService.connect().timeout(const Duration(seconds: 12));
      } catch (connectErr) {
        final msg = connectErr.toString();
        // Handle transient IP/user connection limits or handshake/network issues silently with retry.
        final transient =
            msg.contains('Maximum number of connections') ||
            msg.contains('mail_max_userip_connections') ||
            msg.contains('HandshakeException') ||
            msg.contains('SocketException') ||
            msg.contains('Connection timed out') ||
            msg.contains('Failed host lookup') ||
            msg.contains('CERTIFICATE_VERIFY_FAILED');
        if (transient && _loadMailboxesRetries < _loadMailboxesMaxRetries) {
          final backoff = _loadMailboxesBackoff(_loadMailboxesRetries++);
          if (kDebugMode) {
            print(
              '📫 loadMailBoxes: transient connect error, retrying in ${backoff.inSeconds}s (attempt #$_loadMailboxesRetries) → $msg',
            );
          }
          // Keep the spinner visible; do not show snackbar. Retry shortly.
          Future.delayed(backoff, () async {
            try {
              await loadMailBoxes();
            } catch (_) {}
          });
          return; // Defer work to the retry
        } else if (transient) {
          if (kDebugMode) {
            print(
              '📫 loadMailBoxes: giving up retries after $_loadMailboxesRetries attempts',
            );
          }
          // Fall through to show a gentle error below.
        } else {
          // Non-transient: rethrow to outer catch
          rethrow;
        }
      }

      if (!mailService.client.isConnected) {
        // If still not connected (cooldown), schedule retry and keep spinner
        if (_loadMailboxesRetries < _loadMailboxesMaxRetries) {
          final backoff = _loadMailboxesBackoff(_loadMailboxesRetries++);
          if (kDebugMode) {
            print(
              '📫 loadMailBoxes: not connected yet, retrying in ${backoff.inSeconds}s (attempt #$_loadMailboxesRetries)',
            );
          }
          Future.delayed(backoff, () async {
            try {
              await loadMailBoxes();
            } catch (_) {}
          });
          return;
        }
      }

      // Always fetch a fresh mailbox list from the server to avoid stale flags/paths
      final listed = await mailService.client.listMailboxes();
      if (listed.isNotEmpty) {
        mailboxes(listed);
      }

      // Initialize per-mailbox storage if needed
      for (var m in mailboxes) {
        if (mailboxStorage[m] != null) continue;
        mailboxStorage[m] = SQLiteMailboxMimeStorage(
          mailAccount: mailService.account,
          mailbox: m,
        );
        emails[m] = <MimeMessage>[];
        await mailboxStorage[m]!.init();
      }
      await initInbox();
      isBusy(false);

      // Start background monitor for special-use mailboxes
      _startSpecialMailboxMonitor();

      // Reset retry counter after success
      _loadMailboxesRetries = 0;
    } catch (e) {
      logger.e("Error in loadMailBoxes: $e");
      // Keep spinner visible for a short time and retry once if possible on transient errors
      final msg = e.toString();
      final transient =
          msg.contains('Maximum number of connections') ||
          msg.contains('mail_max_userip_connections') ||
          msg.contains('HandshakeException') ||
          msg.contains('SocketException') ||
          msg.contains('Connection timed out') ||
          msg.contains('Failed host lookup') ||
          msg.contains('CERTIFICATE_VERIFY_FAILED');
      if (transient && _loadMailboxesRetries < _loadMailboxesMaxRetries) {
        final backoff = _loadMailboxesBackoff(_loadMailboxesRetries++);
        if (kDebugMode) {
          print(
            '📫 loadMailBoxes: transient failure in outer catch, retrying in ${backoff.inSeconds}s (attempt #$_loadMailboxesRetries) → $msg',
          );
        }
        Future.delayed(backoff, () async {
          try {
            await loadMailBoxes();
          } catch (_) {}
        });
        return;
      }

      // Show gentle error once and drop spinner so user can pull-to-refresh
      isBusy(false);
      if (!Get.isSnackbarOpen) {
        Get.snackbar(
          'Connection issue',
          'Failed to load mailboxes. Retrying may help.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> loadEmailsForBox(Mailbox mailbox) async {
    // Check if we have cached emails first (moved outside try block for scope)
    final hasExistingEmails =
        emails[mailbox] != null && emails[mailbox]!.isNotEmpty;

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
      logger.i(
        "Loading emails for mailbox: ${mailbox.name} (path: ${mailbox.path})",
      );
      logger.i("Has existing emails: $hasExistingEmails");
      logger.i("Previous current mailbox: ${currentMailbox?.name}");

      // Only show progress indicator if this is the first time loading (no cached emails)
      // Removed progressController to avoid duplicate loading indicators

      isBoxBusy(true);

      // Stop any previous polling when switching mailboxes
      _stopForegroundPolling();
      _stopAutoBackgroundRefresh();

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
        if (mailService.client.selectedMailbox?.encodedPath !=
            mailbox.encodedPath) {
          await mailService.client
              .selectMailbox(mailbox)
              .timeout(const Duration(seconds: 8));
        }
        // NOTE: Defer starting optimized IDLE until after initial load/prefetch completes
      } catch (_) {}

      // PERFORMANCE FIX: If emails already exist, just return them (use cache)
      // IMPORTANT: Never short-circuit for Drafts – always reconcile against server for exact match
      if (hasExistingEmails && !mailbox.isDrafts) {
        logger.i(
          "Using cached emails for ${mailbox.name} (${emails[mailbox]!.length} messages)",
        );
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
        _startAutoBackgroundRefresh();
        return;
      }

      // For Drafts, force an exact reconciliation even if cache exists
      if (mailbox.isDrafts) {
        await _reconcileDraftsExact(mailbox, maxUidFetch: 2000);
        isLoadingEmails.value = false;
        _initializeOptimizedIdleService();
        _startAutoBackgroundRefresh();
        return;
      }

      // Check connection with shorter timeout
      if (!mailService.client.isConnected) {
        progressController.updateStatus('Connecting…');
        await mailService.connect().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException(
              "Connection timeout",
              const Duration(seconds: 10),
            );
          },
        );
      }

      // Select mailbox with timeout
      progressController.updateStatus('Selecting mailbox…');
      await mailService.client
          .selectMailbox(mailbox)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                "Mailbox selection timeout",
                const Duration(seconds: 10),
              );
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
          throw TimeoutException(
            "Loading emails timed out",
            Duration(seconds: outerTimeoutSeconds),
          );
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
              throw TimeoutException(
                "Reconnection timeout",
                const Duration(seconds: 8),
              );
            },
          );

          await mailService.client
              .selectMailbox(mailbox)
              .timeout(
                const Duration(seconds: 8),
                onTimeout: () {
                  throw TimeoutException(
                    "Mailbox selection timeout on retry",
                    const Duration(seconds: 8),
                  );
                },
              );

          // PERFORMANCE FIX: Use forceRefresh on retry to ensure fresh data
          await fetchMailbox(mailbox, forceRefresh: true).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              logger.e(
                "Timeout while fetching mailbox on retry: ${mailbox.name}",
              );
              throw TimeoutException(
                "Loading emails timed out on retry",
                const Duration(seconds: 30),
              );
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
          logger.w(
            'Timeout occurred but emails are partially loaded; continuing without error.',
          );
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
      progressController.show(
        title: 'Downloading all emails',
        subtitle: 'Preparing…',
        indeterminate: true,
      );
      // Sync envelopes for the entire mailbox
      await _enterpriseSync(
        mailbox,
        storage,
        maxToLoad: mailbox.messagesExists,
      );
      // Switch to READY-based progress and prefetch full content for all loaded emails
      _updateReadyProgress(mailbox, emails[mailbox]?.length ?? 0);
      progressController.updateStatus(
        'Prefetching message bodies and attachments…',
      );
      await _prefetchFullContentForWindow(
        mailbox,
        limit: emails[mailbox]?.length ?? 0,
      );
      _updateReadyProgress(mailbox, emails[mailbox]?.length ?? 0);
      progressController.updateProgress(
        current: emails[mailbox]?.length ?? 0,
        total: emails[mailbox]?.length ?? 0,
        progress: 1.0,
        subtitle: 'Done',
      );
    } catch (e) {
      logger.e('Download all failed: $e');
      Get.snackbar(
        'Error',
        'Failed to download all emails. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isPrefetching.value = false;
      progressController.hide();
    }
  }

  // Pagination for emails
  int page = 1;
  int pageSize =
      AppConstants
          .PAGE_SIZE; // Increased from 10 to 50 for better email loading performance

  // Helper: initialize storage with timeout and proper mailbox binding
  Future<void> _initializeMailboxStorageSafe(Mailbox mailbox) async {
    if (mailboxStorage[mailbox] != null) return;
    mailboxStorage[mailbox] = SQLiteMailboxMimeStorage(
      mailAccount: mailService.account,
      mailbox: mailbox,
    );
    await mailboxStorage[mailbox]!.init().timeout(
      Duration(seconds: AppConstants.DB_INIT_TIMEOUT_SECONDS),
      onTimeout: () {
        throw TimeoutException(
          "Database initialization timeout",
          Duration(seconds: AppConstants.DB_INIT_TIMEOUT_SECONDS),
        );
      },
    );
  }

  // Helper: load first page from local DB (skipped on forceRefresh)
  Future<_LocalDbLoadResult> _fmLoadFromLocalDb(
    Mailbox mailbox,
    int maxToLoad, {
    required bool forceRefresh,
  }) async {
    final storage = mailboxStorage[mailbox]!;
    int localCount = 0;
    int loaded = 0;
    bool loadedFromDb = false;
    if (!forceRefresh) {
      localCount = await storage.countMessages();
      final fromDb = await storage
          .loadMessagePage(limit: maxToLoad, offset: 0)
          .timeout(
            Duration(seconds: AppConstants.CONNECTION_TIMEOUT_SECONDS),
            onTimeout: () => <MimeMessage>[],
          );
      if (fromDb.isNotEmpty) {
        emails[mailbox]!.addAll(fromDb);
        _computeAndStampThreadCounts(mailbox);
        previewService.queueBackfillForMessages(
          mailbox: mailbox,
          messages: fromDb,
          storage: storage,
          maxJobs: AppConstants.PREVIEW_BACKFILL_MAX_JOBS_PAGINATION,
        );
        loaded = fromDb.length;
        loadedFromDb = true;
        logger.i(
          "Loaded ${fromDb.length} messages from local DB for ${mailbox.name}",
        );
      }
    }
    return _LocalDbLoadResult(
      loaded: loaded,
      localCount: localCount,
      loadedFromDb: loadedFromDb,
    );
  }

  // Helper: enterprise sync followed by optional prefetch; returns true if satisfied window
  Future<bool> _fmEnterpriseSyncAndMaybePrefetch(
    Mailbox mailbox,
    SQLiteMailboxMimeStorage storage,
    int maxToLoad, {
    required bool loadedFromDb,
  }) async {
    final satisfied = await _enterpriseSync(
      mailbox,
      storage,
      maxToLoad: maxToLoad,
    );
    if (!satisfied) return false;

    // Sort newest first
    _fmSortByDate(mailbox);
    emails.refresh();
    update();

    // Prefetch window
    final bool quietPrefetch = loadedFromDb;
    if (!quietPrefetch) {
      isPrefetching.value = true;
      progressController.updateStatus(
        'Prefetching message bodies and attachments…',
      );
      _updateReadyProgress(mailbox, maxToLoad);
    }
    await _prefetchFullContentForWindow(
      mailbox,
      limit: maxToLoad,
      quiet: quietPrefetch,
    );
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

    // Start IDLE and auto background refresh after initial load
    _initializeOptimizedIdleService();
    _startAutoBackgroundRefresh();
    logger.i(
      "Enterprise sync satisfied initial window for ${mailbox.name} (${emails[mailbox]!.length})",
    );
    return true;
  }

  // Helper: fetch the remaining envelopes from server in descending sequence order
  Future<void> _fmFetchRemainingFromServer(
    Mailbox mailbox,
    SQLiteMailboxMimeStorage storage,
    int max,
    int loaded,
    int maxToLoad,
  ) async {
    int batchSize = AppConstants.MAILBOX_FETCH_BATCH_SIZE;
    while (loaded < maxToLoad) {
      int currentBatchSize = batchSize;
      if (loaded + currentBatchSize > maxToLoad) {
        currentBatchSize = maxToLoad - loaded;
      }

      // Descending from newest
      int start = max - loaded - currentBatchSize + 1;
      int end = max - loaded;

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
        final messages = await mailService.client
            .fetchMessageSequence(
              sequence,
              fetchPreference: FetchPreference.envelope,
            )
            .timeout(
              Duration(seconds: AppConstants.FETCH_NETWORK_TIMEOUT_SECONDS),
              onTimeout:
                  () =>
                      throw TimeoutException(
                        "Network fetch timeout",
                        Duration(
                          seconds: AppConstants.FETCH_NETWORK_TIMEOUT_SECONDS,
                        ),
                      ),
            );

        if (messages.isEmpty) break;

        // De-duplicate by UID and sequenceId
        final existingUids =
            emails[mailbox]!.map((m) => m.uid).whereType<int>().toSet();
        final existingSeqIds =
            emails[mailbox]!.map((m) => m.sequenceId).whereType<int>().toSet();
        final unique =
            messages.where((m) {
              final uid = m.uid;
              final seq = m.sequenceId;
              final notByUid = uid == null || !existingUids.contains(uid);
              final notBySeq = seq == null || !existingSeqIds.contains(seq);
              return notByUid && notBySeq;
            }).toList();

        if (unique.isEmpty) break;
        emails[mailbox]!.addAll(unique);
        _computeAndStampThreadCounts(mailbox);
        previewService.queueBackfillForMessages(
          mailbox: mailbox,
          messages: unique,
          storage: storage,
          maxJobs: AppConstants.PREVIEW_BACKFILL_MAX_JOBS_PAGINATION,
        );

        // Persist (best-effort)
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
        logger.i(
          "Loaded network batch: ${unique.length} messages (total: ${emails[mailbox]!.length})",
        );
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
  }

  // Helper: sort current mailbox newest-first
  void _fmSortByDate(Mailbox mailbox) {
    if (emails[mailbox]!.isEmpty) return;
    emails[mailbox]!.sort((a, b) {
      final dateA = a.decodeDate();
      final dateB = b.decodeDate();
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });
  }

  Future<void> fetchMailbox(
    Mailbox mailbox, {
    bool forceRefresh = false,
  }) async {
    final endTrace = PerfTracer.begin(
      'controller.fetchMailbox',
      args: {'mailbox': mailbox.name, 'forceRefresh': forceRefresh},
    );
    // P12: UI wiring behind flags — optionally prime DDD store (no UI change)
    try {
      await DddUiWiring.maybeFetchInbox(folderId: mailbox.encodedPath.isNotEmpty ? mailbox.encodedPath : mailbox.name);
    } catch (_) {}
    // Telemetry: time inbox open end-to-end
    final _tSw = Stopwatch()..start();
    final _req = DddUiWiring.newRequestId();
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

      // Ensure fresh server metadata is used for counts/UIDNEXT
      await _ensureConnectedAndSelectedMailbox(mailbox);
      final selected = mailService.client.selectedMailbox ?? mailbox;

      int max = selected.messagesExists;
      if (selected.uidNext != null && mailbox.isInbox) {
        await GetStorage().write(
          BackgroundService.keyInboxLastUid,
          selected.uidNext,
        );
      }

      // Handle empty mailbox
      if (max == 0) {
        emails[mailbox] ??= <MimeMessage>[];
        if (mailboxStorage[mailbox] != null) {
          await mailboxStorage[mailbox]!.saveMessageEnvelopes([]);
        }
        emails.refresh();
        update();
        return;
      }

      // Initialize emails list if not exists
      emails[mailbox] ??= <MimeMessage>[];

      // Use cached emails when allowed
      if (!forceRefresh && emails[mailbox]!.isNotEmpty) {
        logger.i(
          "Using cached emails for ${mailbox.name} (${emails[mailbox]!.length} messages)",
        );
        return;
      }

      // Clear only when actually refreshing
      if (forceRefresh) {
        emails[mailbox]!.clear();
        logger.i("Force refresh: cleared cached emails for ${mailbox.name}");
      }

      // Ensure storage is initialized
      await _initializeMailboxStorageSafe(mailbox);
      final storage = mailboxStorage[mailbox]!;

      // Compute initial window
      final int maxToLoad = math.min(
        max,
        AppConstants.INITIAL_MAILBOX_LOAD_LIMIT,
      );
      if (maxToLoad > 0) {
        progressController.updateProgress(
          current: 0,
          total: maxToLoad,
          progress: 0.0,
          subtitle: 'Preparing to load $maxToLoad emails…',
        );
      }

      // Local DB warm page
      final db = await _fmLoadFromLocalDb(
        mailbox,
        maxToLoad,
        forceRefresh: forceRefresh,
      );

      // Enterprise sync + prefetch path
      final satisfied = await _fmEnterpriseSyncAndMaybePrefetch(
        mailbox,
        storage,
        maxToLoad,
        loadedFromDb: db.loadedFromDb,
      );
      if (satisfied) return;

      // If already have enough locally, prefer quiet finish
      if (!forceRefresh && db.localCount >= maxToLoad) {
        _fmSortByDate(mailbox);
        emails.refresh();
        update();
        await _prefetchFullContentForWindow(
          mailbox,
          limit: maxToLoad,
          quiet: true,
        );
        _initializeOptimizedIdleService();
        logger.i(
          "Finished loading from local DB for ${mailbox.name} (${emails[mailbox]!.length} messages)",
        );
        return;
      }

      // Fetch remaining from server
      await _fmFetchRemainingFromServer(
        mailbox,
        storage,
        max,
        db.loaded,
        maxToLoad,
      );

      _fmSortByDate(mailbox);
      emails.refresh();
      update();

      // Prefetch visible window
      isPrefetching.value = true;
      progressController.updateStatus(
        'Prefetching message bodies and attachments…',
      );
      _updateReadyProgress(mailbox, maxToLoad);
      await _prefetchFullContentForWindow(mailbox, limit: maxToLoad);
      isPrefetching.value = false;

      logger.i(
        "Finished loading ${emails[mailbox]!.length} emails for ${mailbox.name}",
      );
      progressController.updateProgress(
        current: maxToLoad,
        total: maxToLoad,
        progress: 1.0,
        subtitle: 'Done',
      );
      progressController.hide();

      _initializeOptimizedIdleService();
      _startAutoBackgroundRefresh();

      if (mailbox.isInbox) {
        try {
          BackgroundService.checkForNewMail(false);
        } catch (e) {
          logger.w("Background service error: $e");
        }
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
    } finally {
      try {
        endTrace();
      } catch (_) {}
      try {
        _tSw.stop();
        Telemetry.event(
          'inbox_open_ms',
          props: {
            'request_id': _req,
            'op': 'inbox_open',
            'folder_id': mailbox.encodedPath.isNotEmpty ? mailbox.encodedPath : mailbox.name,
            'lat_ms': _tSw.elapsedMilliseconds,
            'mailbox_hash': Hashing.djb2(mailbox.encodedPath).toString(),
          },
        );
      } catch (_) {}
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
    final endTrace = PerfTracer.begin(
      'controller.loadMoreEmails',
      args: {'mailbox': mailbox.name, 'page': pageNumber ?? 1},
    );
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
        logger.i(
          "💡 All messages already loaded for ${mailbox.name} ($currentCount/$totalMessages)",
        );
        return;
      }

      // Set loading state
      _isLoadingMore[mailbox] = true;

      logger.i(
        "Loading more emails for ${mailbox.name} (current: $currentCount/$totalMessages)",
      );

      // Set current mailbox
      currentMailbox = mailbox;

      // Check connection
      if (!mailService.client.isConnected) {
        await mailService.connect().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException(
              "Connection timeout",
              const Duration(seconds: 10),
            );
          },
        );
      }

      // Select mailbox
      await mailService.client
          .selectMailbox(mailbox)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                "Mailbox selection timeout",
                const Duration(seconds: 10),
              );
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
      try {
        endTrace();
      } catch (_) {}
    }
  }

  // Load additional messages for pagination
  Future<void> _loadAdditionalMessages(Mailbox mailbox, int pageNumber) async {
    final endTrace = PerfTracer.begin(
      'controller._loadAdditionalMessages',
      args: {'mailbox': mailbox.name, 'page': pageNumber},
    );
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
        logger.i(
          "Loading messages $sequenceStart-$sequenceEnd for page $pageNumber",
        );
      } catch (e) {
        logger.e("Error creating sequence for pagination: $e");
        return;
      }

      // Try to load next page from local storage first (by date)
      if (mailboxStorage[mailbox] != null) {
        final currentCount = emails[mailbox]?.length ?? 0;
        final pageFromDb = await mailboxStorage[mailbox]!
            .loadMessagePage(limit: pageSize, offset: currentCount)
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => <MimeMessage>[],
            );

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
      logger.i(
        "Fetching ${sequence.length} messages from server for pagination",
      );
      List<MimeMessage> newMessages = await mailService.client
          .fetchMessageSequence(
            sequence,
            fetchPreference: FetchPreference.envelope,
          )
          .timeout(
            const Duration(
              seconds: 30,
            ), // Increased timeout for better reliability
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
        final existingUids =
            emails[mailbox]!.map((m) => m.uid).whereType<int>().toSet();
        final existingSeqIds =
            emails[mailbox]!.map((m) => m.sequenceId).whereType<int>().toSet();
        final uniqueNewMessages =
            newMessages.where((m) {
              final uid = m.uid;
              final seq = m.sequenceId;
              final notByUid = uid == null || !existingUids.contains(uid);
              final notBySeq = seq == null || !existingSeqIds.contains(seq);
              return notByUid && notBySeq;
            }).toList();

        emails[mailbox]!.addAll(uniqueNewMessages);
        emails.refresh(); // CRITICAL FIX: Trigger reactive update for UI
        logger.i(
          "Added ${uniqueNewMessages.length} unique messages to mailbox ${mailbox.name}",
        );

        // Save to storage
        if (mailboxStorage[mailbox] != null && uniqueNewMessages.isNotEmpty) {
          try {
            await mailboxStorage[mailbox]!.saveMessageEnvelopes(
              uniqueNewMessages,
            );
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
      try {
        endTrace();
      } catch (_) {}
    }
  }

  Future<void> _loadDraftsFromServer(Mailbox mailbox) async {
    // Delegate to exact reconciliation to ensure server-authoritative state
    await _reconcileDraftsExact(mailbox, maxUidFetch: 2000);
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
          fetchPreference:
              FetchPreference
                  .fullWhenWithinSize, // Get full message data for better parsing
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
          print(
            '📧 Cache MISS: Fetched ${fetchedMessages.length} messages from server',
          );
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
              final singleSequence = MessageSequence.fromId(
                message.sequenceId!,
              );
              final fullMessages = await mailService.client
                  .fetchMessageSequence(
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
                print(
                  '📧 Error fetching envelope for message ${message.sequenceId}: $e',
                );
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
                    fromAddresses = [
                      const MailAddress('Unknown', 'unknown@unknown.com'),
                    ];
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
                    toAddresses = [
                      const MailAddress('', 'unknown@unknown.com'),
                    ];
                  }
                }
              }

              // Create proper envelope
              message.envelope = Envelope(
                date: parsedDate ?? DateTime.now(),
                subject: subjectHeader ?? 'No Subject',
                from:
                    fromAddresses ??
                    [const MailAddress('Unknown', 'unknown@unknown.com')],
                to: toAddresses,
                sender: fromAddresses?.first, // Use first address, not list
                replyTo: fromAddresses,
              );

              if (kDebugMode) {
                print(
                  '📧 ✅ Reconstructed envelope for message: ${message.envelope?.subject}',
                );
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

  Future<void> _ensureConnectedAndSelectedMailbox(Mailbox mailbox) async {
    if (!mailService.client.isConnected) {
      await mailService.connect().timeout(
        Duration(seconds: AppConstants.CONNECTION_TIMEOUT_SECONDS),
        onTimeout: () {
          throw TimeoutException(
            "Connection timeout",
            Duration(seconds: AppConstants.CONNECTION_TIMEOUT_SECONDS),
          );
        },
      );
    }
    if (mailService.client.selectedMailbox?.encodedPath !=
        mailbox.encodedPath) {
      await mailService.client
          .selectMailbox(mailbox)
          .timeout(
            Duration(seconds: AppConstants.MAILBOX_SELECTION_TIMEOUT_SECONDS),
            onTimeout: () {
              throw TimeoutException(
                "Mailbox selection timeout",
                Duration(
                  seconds: AppConstants.MAILBOX_SELECTION_TIMEOUT_SECONDS,
                ),
              );
            },
          );
    }
  }

  // Operations on emails
  Future markAsReadUnread(
    List<MimeMessage> messages,
    Mailbox box, [
    bool isSeen = true,
  ]) async {
    // Optimistic local update
    for (var message in messages) {
      message.isSeen = isSeen;
      try {
        await mailboxStorage[box]?.saveMessageEnvelopes([message]);
      } catch (_) {}
    }
    // Trigger UI refresh immediately
    try {
      emails.refresh();
      update();
    } catch (_) {}

    // Serialize and send to server with proper mailbox selection
    await ImapCommandQueue.instance.run('markAsReadUnread', () async {
      await _ensureConnectedAndSelectedMailbox(box);
      for (var message in messages) {
        try {
          await mailService.client.flagMessage(message, isSeen: isSeen);
        } catch (e) {
          logger.w(
            'Failed to set seen=$isSeen for message ${message.uid ?? message.sequenceId}: $e',
          );
        }
      }
    });
  }

  // Pending server delete state and expunge scheduling
  DeleteResult? deleteResult;
  Map<Mailbox, List<MimeMessage>> deletedMessages = {};
  Timer? _pendingExpungeTimer;
  Mailbox? _pendingExpungeMailbox;

  Future deleteMails(List<MimeMessage> messages, Mailbox mailbox) async {
    // Optimistic local UI removal and storage delete
    try {
      for (final message in messages) {
        removeMessageFromUI(message, mailbox);
        try {
          await mailboxStorage[mailbox]?.deleteMessage(message);
        } catch (_) {}
      }
      emails.refresh();
      update();
    } catch (_) {}

    deletedMessages[mailbox] = messages;

    await ImapCommandQueue.instance.run('deleteMails', () async {
      try {
        await _ensureConnectedAndSelectedMailbox(mailbox);
        deleteResult = await mailService.client.deleteMessages(
          MessageSequence.fromMessages(messages),
          messages: messages,
          expunge: false,
        );
      } catch (e) {
        logger.w('Server delete failed: $e');
      }
    });

    if (deleteResult != null && deleteResult!.canUndo) {
      // Schedule expunge if not undone within snackbar duration
      const snackDuration = Duration(seconds: 5);
      _pendingExpungeTimer?.cancel();
      _pendingExpungeMailbox = mailbox;
      _pendingExpungeTimer = Timer(
        snackDuration + const Duration(seconds: 1),
        () async {
          if (deleteResult != null && _pendingExpungeMailbox != null) {
            await ImapCommandQueue.instance.run('expungeAfterDelete', () async {
              try {
                final mailbox = _pendingExpungeMailbox!;
                await _ensureConnectedAndSelectedMailbox(mailbox);
                // Reissue delete with expunge=true to purge flagged messages
                final msgs = deletedMessages[mailbox] ?? const <MimeMessage>[];
                if (msgs.isNotEmpty) {
                  await mailService.client.deleteMessages(
                    MessageSequence.fromMessages(msgs),
                    messages: msgs,
                    expunge: true,
                  );
                }
              } catch (e) {
                logger.w('Expunge after delete failed: $e');
              } finally {
                deleteResult = null;
                _pendingExpungeMailbox = null;
              }
            });
          }
        },
      );

      Get.showSnackbar(
        GetSnackBar(
          message: 'messages_deleted'.tr,
          backgroundColor: Colors.redAccent,
          duration: snackDuration,
          mainButton: TextButton(
            onPressed: () async {
              await undoDelete();
            },
            child: Text('undo'.tr),
          ),
        ),
      );
    }

    // Light reconcile to ensure local view matches server state for recent window
    try {
      await reconcileRecentWithServer(mailbox, window: 100);
    } catch (_) {}
  }

  Future undoDelete() async {
    // Cancel any pending expunge
    _pendingExpungeTimer?.cancel();
    _pendingExpungeTimer = null;
    _pendingExpungeMailbox = null;

    if (deleteResult != null) {
      try {
        await mailService.client.undoDeleteMessages(deleteResult!);
      } catch (e) {
        logger.w('Undo delete failed: $e');
      }
      deleteResult = null;
      // Restore to storage and UI
      for (var mailbox in deletedMessages.keys) {
        final restored = deletedMessages[mailbox] ?? const <MimeMessage>[];
        try {
          await mailboxStorage[mailbox]?.saveMessageEnvelopes(restored);
        } catch (_) {}
        try {
          emails[mailbox] ??= <MimeMessage>[];
          // Reinsert at top if not already present
          for (final m in restored) {
            final exists = emails[mailbox]!.any(
              (e) =>
                  (m.uid != null && e.uid == m.uid) ||
                  (m.sequenceId != null && e.sequenceId == m.sequenceId),
            );
            if (!exists) {
              emails[mailbox]!.insert(0, m);
            }
          }
        } catch (_) {}
      }
      deletedMessages.clear();
      try {
        emails.refresh();
        update();
      } catch (_) {}
    }
  }

  Future moveMails(List<MimeMessage> messages, Mailbox from, Mailbox to) async {
    // Optimistic UI + storage updates
    for (var message in messages) {
      try {
        // Remove from source UI
        final src = emails[from];
        src?.removeWhere(
          (m) =>
              (message.uid != null && m.uid == message.uid) ||
              (message.sequenceId != null &&
                  m.sequenceId == message.sequenceId),
        );
        // Add to destination UI
        emails[to] ??= <MimeMessage>[];
        final exists = emails[to]!.any(
          (m) =>
              (message.uid != null && m.uid == message.uid) ||
              (message.sequenceId != null &&
                  m.sequenceId == message.sequenceId),
        );
        if (!exists) emails[to]!.insert(0, message);
        // Persist
        try {
          await mailboxStorage[from]?.deleteMessage(message);
        } catch (_) {}
        try {
          await mailboxStorage[to]?.saveMessageEnvelopes([message]);
        } catch (_) {}
      } catch (_) {}
    }
    try {
      emails.refresh();
      update();
    } catch (_) {}

    // Server move (serialized and mailbox-aware)
    await ImapCommandQueue.instance.run('moveMails', () async {
      try {
        await _ensureConnectedAndSelectedMailbox(from);
        for (var message in messages) {
          try {
            await mailService.client.moveMessage(message, to);
          } catch (e) {
            logger.w('Move single failed: $e');
          }
        }
      } catch (e) {
        logger.w('Move failed: $e');
      }
    });

    // Reconcile both mailboxes lightly
    try {
      await reconcileRecentWithServer(from, window: 100);
    } catch (_) {}
    try {
      await reconcileRecentWithServer(to, window: 100);
    } catch (_) {}
  }

  /// High-level Archive using enough_mail helpers with optimistic UI
  Future<bool> archiveMessages(
    List<MimeMessage> messages,
    Mailbox from, {
    bool optimistic = true,
  }) async {
    try {
      // Optimistic: drop from current mailbox UI and local storage
      if (optimistic) {
        for (final m in messages) {
          removeMessageFromUI(m, from);
          try {
            await mailboxStorage[from]?.deleteMessage(m);
          } catch (_) {}
        }
      }

      bool movedAny = false;
      // Build sequence from UIDs where possible
      final ids = messages.map((m) => m.uid).whereType<int>().toList();
      if (ids.isNotEmpty) {
        try {
          await mailService.client.moveMessagesToFlag(
            MessageSequence.fromIds(ids),
            MailboxFlag.archive,
          );
          movedAny = true;
        } catch (e) {
          logger.w('Archive (bulk) failed, falling back to single moves: $e');
          for (final m in messages) {
            try {
              await mailService.client.moveMessageToFlag(
                m,
                MailboxFlag.archive,
              );
              movedAny = true;
            } catch (_) {}
          }
        }
      } else {
        // Fallback: move individually (for messages missing UID)
        for (final m in messages) {
          try {
            await mailService.client.moveMessageToFlag(m, MailboxFlag.archive);
            movedAny = true;
          } catch (_) {}
        }
      }

      // Fallback when server lacks special-use Archive support: move to a best-guess Archive mailbox by name/flag
      if (!movedAny) {
        final toArchive =
            mailboxes.firstWhereOrNull((m) => m.isArchive) ??
            mailboxes.firstWhereOrNull(
              (m) => m.name.toLowerCase().contains('archive'),
            ) ??
            mailboxes.firstWhereOrNull(
              (m) => m.name.toLowerCase().contains('all mail'),
            );
        if (toArchive != null) {
          for (final m in messages) {
            try {
              await mailService.client.moveMessage(m, toArchive);
              movedAny = true;
            } catch (_) {}
          }
        }
      }

      // Best-effort: persist to Archive storage
      try {
        final archive =
            mailboxes.firstWhereOrNull((m) => m.isArchive) ??
            mailboxes.firstWhereOrNull(
              (m) => m.name.toLowerCase().contains('archive'),
            ) ??
            mailboxes.firstWhereOrNull(
              (m) => m.name.toLowerCase().contains('all mail'),
            );
        if (archive != null) {
          await mailboxStorage[archive]?.saveMessageEnvelopes(messages);
        }
      } catch (_) {}

      // Kick a quick reconcile to remove any local ghosts
      try {
        await reconcileRecentWithServer(from, window: 300);
      } catch (_) {}
      return movedAny || optimistic; // optimistic UI already applied
    } catch (e) {
      logger.w('archiveMessages error: $e');
      return false;
    }
  }

  /// High-level Junk (Spam) using enough_mail helpers with optimistic UI
  Future<bool> junkMessages(
    List<MimeMessage> messages,
    Mailbox from, {
    bool optimistic = true,
  }) async {
    try {
      if (optimistic) {
        for (final m in messages) {
          removeMessageFromUI(m, from);
          try {
            await mailboxStorage[from]?.deleteMessage(m);
          } catch (_) {}
        }
      }

      bool movedAny = false;
      final ids = messages.map((m) => m.uid).whereType<int>().toList();
      if (ids.isNotEmpty) {
        try {
          await mailService.client.junkMessages(MessageSequence.fromIds(ids));
          movedAny = true;
        } catch (e) {
          logger.w('Junk (bulk) failed, falling back to single moves: $e');
          for (final m in messages) {
            try {
              await mailService.client.junkMessage(m);
              movedAny = true;
            } catch (_) {}
          }
        }
      } else {
        for (final m in messages) {
          try {
            await mailService.client.junkMessage(m);
            movedAny = true;
          } catch (_) {}
        }
      }

      // Fallback when server lacks special-use Junk support: move to a best-guess Junk/Spam mailbox by flag/name
      if (!movedAny) {
        final toJunk =
            mailboxes.firstWhereOrNull((m) => m.isJunk) ??
            mailboxes.firstWhereOrNull(
              (m) => m.name.toLowerCase().contains('junk'),
            ) ??
            mailboxes.firstWhereOrNull(
              (m) => m.name.toLowerCase().contains('spam'),
            );
        if (toJunk != null) {
          for (final m in messages) {
            try {
              await mailService.client.moveMessage(m, toJunk);
              movedAny = true;
            } catch (_) {}
          }
        }
      }

      // Best-effort: persist to Junk storage
      try {
        final junk =
            mailboxes.firstWhereOrNull((m) => m.isJunk) ??
            mailboxes.firstWhereOrNull(
              (m) => m.name.toLowerCase().contains('junk'),
            ) ??
            mailboxes.firstWhereOrNull(
              (m) => m.name.toLowerCase().contains('spam'),
            );
        if (junk != null) {
          await mailboxStorage[junk]?.saveMessageEnvelopes(messages);
        }
      } catch (_) {}

      try {
        await reconcileRecentWithServer(from, window: 300);
      } catch (_) {}
      return movedAny || optimistic;
    } catch (e) {
      logger.w('junkMessages error: $e');
      return false;
    }
  }

  // update flag on messages on server (toggle)
  Future updateFlag(List<MimeMessage> messages, Mailbox mailbox) async {
    // Optimistic local toggle
    for (var message in messages) {
      try {
        message.isFlagged = !message.isFlagged;
        await mailboxStorage[mailbox]?.saveMessageEnvelopes([message]);
      } catch (_) {}
    }
    try {
      emails.refresh();
      update();
    } catch (_) {}

    await ImapCommandQueue.instance.run('updateFlag', () async {
      await _ensureConnectedAndSelectedMailbox(mailbox);
      for (var message in messages) {
        try {
          await mailService.client.flagMessage(
            message,
            isFlagged: message.isFlagged,
          );
        } catch (e) {
          logger.w(
            'Flag toggle failed for ${message.uid ?? message.sequenceId}: $e',
          );
        }
      }
    });
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
    SwapAction action = getSwapActionFromString(
      settingController.swipeGesturesLTR.value,
    );
    _doSwapAction(action, message, mailbox);
  }

  Future rtlTap(MimeMessage message, Mailbox mailbox) async {
    SwapAction action = getSwapActionFromString(
      settingController.swipeGesturesRTL.value,
    );
    _doSwapAction(action, message, mailbox);
  }

  Future _doSwapAction(
    SwapAction action,
    MimeMessage message,
    Mailbox box,
  ) async {
    if (action == SwapAction.readUnread) {
      await markAsReadUnread([message], box, !message.isSeen);
    } else if (action == SwapAction.delete) {
      await deleteMails([message], box);
    } else if (action == SwapAction.archive) {
      await archiveMessages([message], box, optimistic: true);
    } else if (action == SwapAction.toggleFlag) {
      await updateFlag([message], box);
    } else if (action == SwapAction.markAsJunk) {
      await junkMessages([message], box, optimistic: true);
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
      mailbox ??= mailboxes.firstWhereOrNull(
        (element) => element.name == 'INBOX',
      );

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
              (msg) =>
                  msg.uid == message.uid ||
                  (msg.sequenceId == message.sequenceId &&
                      message.sequenceId != null),
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
          print(
            "📧 No suitable mailbox found or storage not available for incoming message",
          );
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
      List<Mailbox> mailboxesToCheck =
          [
                mailbox, // The passed mailbox
                currentMailbox, // The current mailbox
                mailService.client.selectedMailbox, // The IMAP selected mailbox
              ]
              .where((mb) => mb != null)
              .cast<Mailbox>()
              .toSet()
              .toList(); // Remove nulls and duplicates

      // Check each possible mailbox source
      for (final checkMailbox in mailboxesToCheck) {
        final mailboxEmails = emails[checkMailbox];
        if (mailboxEmails == null) {
          logger.w("Mailbox ${checkMailbox.name} has no loaded emails");
          continue; // Try next mailbox
        }

        // Check if the message is in this mailbox's email list
        final messageExists = mailboxEmails.any(
          (email) =>
              email.uid == message.uid ||
              email.sequenceId == message.sequenceId ||
              (email.decodeSubject() == message.decodeSubject() &&
                  email.decodeDate()?.millisecondsSinceEpoch ==
                      message.decodeDate()?.millisecondsSinceEpoch),
        );

        if (messageExists) {
          logger.i(
            "Message '${message.decodeSubject()}' found in mailbox ${checkMailbox.name}",
          );
          return true; // Message found in at least one mailbox
        }
      }

      // CRITICAL FIX: If message not found in any mailbox, check if it's in the currently displayed messages
      final currentlyDisplayedMessages = boxMails;
      final messageInDisplayed = currentlyDisplayedMessages.any(
        (email) =>
            email.uid == message.uid ||
            email.sequenceId == message.sequenceId ||
            (email.decodeSubject() == message.decodeSubject() &&
                email.decodeDate()?.millisecondsSinceEpoch ==
                    message.decodeDate()?.millisecondsSinceEpoch),
      );

      if (messageInDisplayed) {
        logger.i(
          "Message '${message.decodeSubject()}' found in currently displayed messages",
        );
        return true; // Message is in the displayed list, so it's valid
      }

      logger.w(
        "Message '${message.decodeSubject()}' not found in any checked mailbox or displayed messages",
      );
      logger.w(
        "Checked mailboxes: ${mailboxesToCheck.map((mb) => mb.name).join(', ')}",
      );
      logger.w(
        "Currently displayed messages count: ${currentlyDisplayedMessages.length}",
      );

      return false;
    } catch (e) {
      logger.e("Error validating message-mailbox consistency: $e");
      // CRITICAL FIX: On validation error, allow navigation to proceed (fail-safe approach)
      logger.w(
        "Validation error occurred, allowing navigation to proceed as fail-safe",
      );
      return true;
    }
  }

  // CRITICAL FIX: Add method to safely navigate to message view with validation
  Future<void> safeNavigateToMessage(
    MimeMessage message,
    Mailbox mailbox,
  ) async {
    try {
      final subject = message.decodeSubject() ?? '(no subject)';
      logger.i(
        "Safe navigation to message: $subject in mailbox: ${mailbox.name}",
      );

      // Determine draft-like status early and short-circuit validation for drafts
      final isDraft = message.flags?.contains(MessageFlags.draft) ?? false;
      final isInDraftsMailbox = mailbox.isDrafts;
      final isDraftsMailboxByName = mailbox.name.toLowerCase().contains(
        'draft',
      );

      if (isDraft || isInDraftsMailbox || isDraftsMailboxByName) {
        logger.i(
          "Draft-like message detected; skipping consistency validation and opening composer",
        );
        // Ensure current mailbox context
        currentMailbox = mailbox;
        Get.to(
          () => const RedesignedComposeScreen(),
          arguments: {'type': 'draft', 'message': message, 'mailbox': mailbox},
        );
        return;
      }

      // Validate message-mailbox consistency for non-drafts
      if (!validateMessageMailboxConsistency(message, mailbox)) {
        logger.w(
          "Message-mailbox consistency check failed; attempting fallback navigation to message view",
        );
        // Try best-effort navigation rather than blocking the user
        try {
          currentMailbox = mailbox;
          Get.to(
            () => ShowMessagePager(mailbox: mailbox, initialMessage: message),
          );
        } catch (_) {
          Get.to(() => ShowMessage(message: message, mailbox: mailbox));
        }
        return;
      }

      // Ensure current mailbox is set correctly
      currentMailbox = mailbox;

      // Navigate to paged show message screen for regular email
      logger.i("Navigating to paged show message screen for regular email");
      try {
        final listRef = emails[mailbox] ?? const <MimeMessage>[];
        int index = 0;
        if (listRef.isNotEmpty) {
          index = listRef.indexWhere(
            (m) =>
                (message.uid != null && m.uid == message.uid) ||
                (message.sequenceId != null &&
                    m.sequenceId == message.sequenceId),
          );
          if (index < 0) {
            // Fallback: try by subject+date
            index = listRef.indexWhere(
              (m) =>
                  m.decodeSubject() == message.decodeSubject() &&
                  m.decodeDate()?.millisecondsSinceEpoch ==
                      message.decodeDate()?.millisecondsSinceEpoch,
            );
          }
          if (index < 0) index = 0;
        }
        Get.to(
          () => ShowMessagePager(mailbox: mailbox, initialMessage: message),
        );
      } catch (_) {
        // Fallback to single message view
        Get.to(() => ShowMessage(message: message, mailbox: mailbox));
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

  /// Enterprise-grade send flow with optimistic UI and best-effort append to Sent.
  /// Returns true if SMTP send succeeded and message was appended/moved to Sent or will be shortly.
  Future<bool> sendMailOptimistic({
    required MimeMessage message,
    MimeMessage? draftMessage,
    Mailbox? draftMailbox,
  }) async {
    Mailbox? sent = sentMailbox;
    if (sent == null) {
      logger.e('Cannot send optimistically: Sent mailbox not found');
      // Fallback: try to select inbox to avoid selection issues, but proceed with SMTP only
      try {
        await mailService.connect();
      } catch (_) {}
    }

    // Optimistic UI insertion to Sent
    String optimisticId = DateTime.now().microsecondsSinceEpoch.toString();
    try {
      if (sent != null) {
        // Mark as optimistic and insert into UI
        try {
          message.isSeen = true;
        } catch (_) {}
        emails[sent] ??= <MimeMessage>[];
        emails[sent]!.insert(0, message);
        // Persist envelope for fast subsequent loads
        final storage = mailboxStorage[sent];
        if (storage != null) {
          try {
            await storage.saveMessageEnvelopes([message]);
          } catch (_) {}
        }
        // Track in outbox for restart resilience
        try {
          await OutboxService.instance.init();
          final key = '${sent.encodedPath}:$optimisticId';
          OutboxService.instance.add(key, {
            'mailboxPath': sent.encodedPath,
            'subject': message.decodeSubject() ?? '',
            'date':
                (message.decodeDate() ?? DateTime.now()).millisecondsSinceEpoch,
          });
        } catch (_) {}
        emails.refresh();
        update();
      }

      // Remove draft from UI immediately
      if (draftMailbox != null && draftMessage != null) {
        try {
          final list = emails[draftMailbox];
          list?.removeWhere(
            (m) =>
                (draftMessage.uid != null && m.uid == draftMessage.uid) ||
                (draftMessage.sequenceId != null &&
                    m.sequenceId == draftMessage.sequenceId),
          );
          emails.refresh();
          update();
        } catch (_) {}
      }
    } catch (e) {
      logger.w('Optimistic UI setup failed: $e');
    }

    // Perform SMTP send
    try {
      // Safety: ensure multipart containers are not base64-encoded at top-level
      try {
        final ct =
            (message.getHeaderValue('Content-Type') ??
                    message.getHeaderValue('content-type') ??
                    '')
                .toLowerCase();
        if (ct.contains('multipart/')) {
          message.setHeader('Content-Transfer-Encoding', '7bit');
        }
      } catch (_) {}
      await mailService.client.sendMessage(message);
    } catch (e) {
      logger.e('SMTP send failed: $e');
      // Rollback optimistic UI
      if (sent != null) {
        try {
          final list = emails[sent];
          list?.removeWhere(
            (m) =>
                (message.uid != null && m.uid == message.uid) ||
                (message.sequenceId != null &&
                    m.sequenceId == message.sequenceId) ||
                (m.decodeSubject() == message.decodeSubject() &&
                    m.decodeDate()?.millisecondsSinceEpoch ==
                        message.decodeDate()?.millisecondsSinceEpoch),
          );
          emails.refresh();
          update();
        } catch (_) {}
      }
      // Reinsert draft back into Drafts UI
      if (draftMailbox != null && draftMessage != null) {
        try {
          emails[draftMailbox] ??= <MimeMessage>[];
          emails[draftMailbox]!.insert(0, draftMessage);
          emails.refresh();
          update();
        } catch (_) {}
      }
      return false;
    }

    // Confirm append: check if server already appended to Sent (to avoid duplicates); append if missing
    bool appended = false;
    final needAppend = (draftMailbox != null && draftMessage != null);
    if (sent != null) {
      try {
        // Ensure Sent is selected
        logger.i(
          'SendFlow: verifying message in Sent by Message-Id; mailbox=${sent.encodedPath}',
        );
        if (!mailService.client.isConnected) {
          try {
            await mailService.connect();
          } catch (_) {}
        }
        try {
          await mailService.client.selectMailbox(sent);
        } catch (_) {}
        // Fetch recent messages and look for matching Message-Id
        final msgId =
            (message.getHeaderValue('message-id') ??
                    message.getHeaderValue('Message-Id'))
                ?.trim();
        logger.i(
          'SendFlow: Message-Id used for Sent detection: ${msgId ?? '(none)'}',
        );
        int max = sent.messagesExists;
        if (max > 0) {
          final start = math.max(1, max - 20 + 1);
          final end = max;
          final seq = MessageSequence.fromRange(start, end);
          final recents = await mailService.client
              .fetchMessageSequence(
                seq,
                fetchPreference: FetchPreference.fullWhenWithinSize,
              )
              .timeout(
                const Duration(seconds: 20),
                onTimeout: () => <MimeMessage>[],
              );
          if (msgId != null) {
            logger.i(
              'SendFlow: fetched recent ${recents.length} items in Sent; scanning for Message-Id match',
            );
            appended = recents.any((m) {
              final mid =
                  (m.getHeaderValue('message-id') ??
                          m.getHeaderValue('Message-Id'))
                      ?.trim();
              return mid != null && mid == msgId;
            });
          }
        }
        if (!appended) {
          try {
            logger.i('SendFlow: APPEND to Sent required; attempting append');
            await mailService.client.appendMessage(message, sent);
            appended = true;
            logger.i('SendFlow: APPEND to Sent succeeded');
          } catch (e) {
            logger.w('APPEND to Sent failed: $e');
          }
        }
      } catch (e) {
        logger.w('Sent confirmation step failed: $e');
      }

      if (!appended && needAppend) {
        // Fallback: if editing a draft, move it to Sent as a server-side record
        try {
          logger.w(
            'SendFlow: APPEND not confirmed; moving draft to Sent as fallback',
          );
          await moveMails([draftMessage], draftMailbox, sent);
          appended = true;
        } catch (err) {
          logger.w('Move draft to Sent failed as fallback: $err');
        }
      }
    } else {
      // No Sent mailbox available; accept SMTP-only success
      appended =
          !needAppend; // true if not a draft send; false if draft (we want append confirmation)
    }

    // If append failed for edited drafts, rollback optimistic UI and restore draft
    if (needAppend && !appended) {
      if (sent != null) {
        try {
          final list = emails[sent];
          list?.removeWhere((m) => identical(m, message));
          emails.refresh();
          update();
        } catch (_) {}
      }
      // Restore draft back into Drafts UI
      try {
        emails[draftMailbox] ??= <MimeMessage>[];
        emails[draftMailbox]!.insert(0, draftMessage);
        emails.refresh();
        update();
      } catch (_) {}
      // Remove from outbox
      try {
        if (sent != null) {
          final key = '${sent.encodedPath}:$optimisticId';
          OutboxService.instance.remove(key);
        }
      } catch (_) {}
      return false;
    }

    // Mark optimistic message as delivered and clear outbox tracking
    try {
      if (sent != null) {
        final list = emails[sent] ?? const <MimeMessage>[];
        final idx = list.indexWhere((m) => identical(m, message));
        if (idx >= 0) {
          try {
            final key = '${sent.encodedPath}:$optimisticId';
            OutboxService.instance.remove(key);
          } catch (_) {}
          emails.refresh();
          update();
        }
      }
    } catch (_) {}

    // If we sent from a draft, delete the original draft on the server and in local storage
    if (needAppend) {
      try {
        logger.i(
          'SendFlow: deleting original draft after send; mailbox=${draftMailbox.encodedPath}, uid=${draftMessage.uid ?? -1}, seq=${draftMessage.sequenceId ?? -1}',
        );
        // Select the original Drafts mailbox
        if (!mailService.client.isConnected) {
          try {
            await mailService.connect();
          } catch (_) {}
        }
        try {
          await mailService.client.selectMailbox(draftMailbox);
        } catch (_) {}
        // Prefer UID-based deletion
        MessageSequence seq;
        if (draftMessage.uid != null) {
          seq = MessageSequence.fromRange(
            draftMessage.uid!,
            draftMessage.uid!,
            isUidSequence: true,
          );
        } else {
          seq = MessageSequence.fromMessage(draftMessage);
        }
        await mailService.client.deleteMessages(seq, expunge: true);
        logger.i(
          'SendFlow: server delete (expunge) request issued for original draft',
        );
      } catch (e) {
        logger.w('Failed to delete draft after send: $e');
      }
      // Purge from local storage and UI definitively
      try {
        await mailboxStorage[draftMailbox]?.deleteMessage(draftMessage);
        logger.i('SendFlow: local DB purge of original draft completed');
      } catch (e) {
        logger.w('SendFlow: local DB purge failed: $e');
      }
      try {
        final list = emails[draftMailbox];
        final before = list?.length ?? 0;
        list?.removeWhere(
          (m) =>
              (draftMessage.uid != null && m.uid == draftMessage.uid) ||
              (draftMessage.sequenceId != null &&
                  m.sequenceId == draftMessage.sequenceId),
        );
        final after = list?.length ?? 0;
        logger.i(
          'SendFlow: in-memory Drafts list removed ${(before - after).clamp(0, before)} item(s)',
        );
        emails.refresh();
        update();
      } catch (_) {}
    }

    // Light reconcile of Sent to ensure exact server state (captures provider auto-sent copies)
    try {
      if (sent != null) {
        await reconcileRecentWithServer(sent, window: 300);
      }
    } catch (_) {}

    // Only report success when append/move succeeded for drafts; for new messages SMTP success is enough
    return needAppend ? appended : true;
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
        mailboxEmails.removeWhere(
          (m) =>
              (m.uid != null && m.uid == message.uid) ||
              (m.sequenceId != null && m.sequenceId == message.sequenceId),
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

      // Ensure the notification listener is active (it only subscribes; it does NOT start IDLE)
      try {
        EmailNotificationService.instance.startListening();
      } catch (_) {}

      // Get the optimized IDLE service instance
      final idleService = OptimizedIdleService.instance;

      // Start the optimized IDLE service for real-time email updates
      idleService
          .startOptimizedIdle()
          .then((_) {
            // Only mark as started if the service actually entered running state
            if (idleService.isRunning) {
              _optimizedIdleStarted = true;
              if (kDebugMode) {
                print('📧 ✅ Optimized IDLE service started successfully');
              }
            } else {
              // Retry once after a short delay (e.g., when the queue had IDLE paused)
              Future.delayed(const Duration(seconds: 1), () async {
                try {
                  await idleService.startOptimizedIdle();
                  if (idleService.isRunning) {
                    _optimizedIdleStarted = true;
                    if (kDebugMode)
                      print('📧 ✅ Optimized IDLE service started on retry');
                  }
                } catch (_) {}
              });
            }
          })
          .catchError((error) {
            if (kDebugMode) {
              print('📧 ❌ Failed to start optimized IDLE service: $error');
            }
          });

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

  Future<bool> _enterpriseSync(
    Mailbox mailbox,
    SQLiteMailboxMimeStorage storage, {
    required int maxToLoad,
    bool quiet = false,
  }) async {
    try {
      // Use the currently selected mailbox for fresh server metadata
      final selected = mailService.client.selectedMailbox ?? mailbox;

      // Persist server meta for reference
      await storage.updateMailboxMeta(
        uidNext: selected.uidNext,
        uidValidity: selected.uidValidity,
      );

      // Detect UIDVALIDITY changes
      final state = await storage.getSyncState();
      if (selected.uidValidity != null &&
          state.uidValidity != null &&
          selected.uidValidity != state.uidValidity) {
        // Reset on UIDVALIDITY change
        try {
          await storage.deleteAllMessages();
          emails[mailbox]?.clear();
        } catch (_) {}
        await storage.resetSyncState(
          uidNext: mailbox.uidNext,
          uidValidity: mailbox.uidValidity,
        );
      }

      // Working capacities
      int capacity = math.max(0, maxToLoad - (emails[mailbox]?.length ?? 0));
      if (capacity <= 0) return true;

      // 1) Ascending fetch for new mail beyond lastSyncedUidHigh
      final st1 = await storage.getSyncState();
      if (selected.uidNext != null &&
          (st1.lastSyncedUidHigh ?? 0) < (selected.uidNext! - 1)) {
        final startUid = (st1.lastSyncedUidHigh ?? 0) + 1;
        final endUid = selected.uidNext! - 1;
        if (endUid >= startUid) {
          final take = math.min(capacity, endUid - startUid + 1);
          final fetchEnd = startUid + take - 1;
          if (!quiet) {
            progressController.updateStatus('Fetching new mail…');
          }
          final seq = MessageSequence.fromRange(
            startUid,
            fetchEnd,
            isUidSequence: true,
          );
          final fresh = await mailService.client
              .fetchMessageSequence(
                seq,
                fetchPreference: FetchPreference.envelope,
              )
              .timeout(
                const Duration(seconds: 25),
                onTimeout: () => <MimeMessage>[],
              );
          if (fresh.isNotEmpty) {
            final existingIds = emails[mailbox]!.map((m) => m.uid).toSet();
            final uniqueFresh =
                fresh.where((m) => !existingIds.contains(m.uid)).toList();
            if (uniqueFresh.isNotEmpty) {
              // Ensure newest-first when inserting at the top
              try {
                uniqueFresh.sort(
                  (a, b) => (b.uid ?? b.sequenceId ?? 0).compareTo(
                    a.uid ?? a.sequenceId ?? 0,
                  ),
                );
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
                uidNext: selected.uidNext,
                uidValidity: selected.uidValidity,
                lastSyncedUidHigh: fetchEnd,
                lastSyncFinishedAt: DateTime.now().millisecondsSinceEpoch,
              );
              capacity = math.max(0, capacity - uniqueFresh.length);
              if (!quiet) {
                progressController.updateProgress(
                  current: maxToLoad - capacity,
                  total: maxToLoad,
                  progress:
                      maxToLoad > 0
                          ? ((maxToLoad - capacity) / maxToLoad).clamp(0.0, 1.0)
                          : 1.0,
                  subtitle: 'Fetched ${uniqueFresh.length} new emails',
                );
              }
            }
          }
          if (capacity <= 0) return true;
        }
      }

      // 2) Descending fetch for initial-run older mail until window is filled
      final st2 = await storage.getSyncState();
      final initialDone = st2.initialSyncDone;
      if (!initialDone) {
        int? high =
            st2.lastSyncedUidLow != null
                ? (st2.lastSyncedUidLow! - 1)
                : (selected.uidNext != null ? selected.uidNext! - 1 : null);
        const int batch = 50;
        while (high != null && high >= 1 && capacity > 0) {
          final low = math.max(1, high - batch + 1);
          final take = math.min(capacity, high - low + 1);
          final adjLow = high - take + 1;
          if (!quiet) {
            progressController.updateStatus('Fetching older mail…');
          }
          final seq = MessageSequence.fromRange(
            adjLow,
            high,
            isUidSequence: true,
          );
          final older = await mailService.client
              .fetchMessageSequence(
                seq,
                fetchPreference: FetchPreference.envelope,
              )
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () => <MimeMessage>[],
              );
          if (older.isEmpty) break;
          final existingIds = emails[mailbox]!.map((m) => m.uid).toSet();
          final uniqueOlder =
              older.where((m) => !existingIds.contains(m.uid)).toList();
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
            final newHigh =
                st2.lastSyncedUidHigh ??
                (mailbox.uidNext != null ? mailbox.uidNext! - 1 : high);
            await storage.updateSyncState(
              uidNext: selected.uidNext,
              uidValidity: selected.uidValidity,
              lastSyncedUidHigh: newHigh,
              lastSyncedUidLow: adjLow,
              lastSyncFinishedAt: DateTime.now().millisecondsSinceEpoch,
            );
            capacity -= uniqueOlder.length;
            if (!quiet) {
              progressController.updateProgress(
                current: maxToLoad - capacity,
                total: maxToLoad,
                progress:
                    maxToLoad > 0
                        ? ((maxToLoad - capacity) / maxToLoad).clamp(0.0, 1.0)
                        : 1.0,
                subtitle:
                    'Downloading emails… ${maxToLoad - capacity} / $maxToLoad',
              );
            }
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
      String normalizeSubject(String? s) {
        if (s == null) return '';
        var t = s.trim();
        // Strip common reply/forward prefixes repeatedly
        final rx = RegExp(
          r'^(?:(re|fw|fwd|aw|wg)\s*:\s*)+',
          caseSensitive: false,
        );
        t = t.replaceAll(rx, '').trim();
        return t.toLowerCase();
      }

      String extractRootId(MimeMessage m) {
        String? refs = m.getHeaderValue('references');
        String? irt = m.getHeaderValue('in-reply-to');
        if (refs != null && refs.isNotEmpty) {
          final ids =
              RegExp(
                r'<[^>]+>',
              ).allMatches(refs).map((m) => m.group(0)!).toList();
          if (ids.isNotEmpty) return ids.first;
        }
        if (irt != null && irt.isNotEmpty) {
          final id = RegExp(r'<[^>]+>').firstMatch(irt)?.group(0);
          if (id != null) return id;
        }
        final subj = normalizeSubject(m.decodeSubject() ?? m.envelope?.subject);
        return 'subj::$subj';
      }

      final counts = <String, int>{};
      for (final m in list) {
        final key = extractRootId(m);
        counts[key] = (counts[key] ?? 0) + 1;
      }
      for (final m in list) {
        final key = extractRootId(m);
        final c = counts[key] ?? 1;
        try {
          m.setHeader('x-thread-count', '$c');
        } catch (_) {}
        try {
          bumpMessageMeta(mailbox, m);
        } catch (_) {}
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
  Future<void> _prefetchFullContentForWindow(
    Mailbox mailbox, {
    required int limit,
    bool quiet = false,
  }) async {
    try {
      final list = List<MimeMessage>.from(
        (emails[mailbox] ?? const <MimeMessage>[]).take(limit),
      );
      if (list.isEmpty) return;

      // Ensure IMAP has this mailbox selected (avoid selection thrash if already selected)
      try {
        if (mailService.client.selectedMailbox?.encodedPath !=
            mailbox.encodedPath) {
          await mailService.client
              .selectMailbox(mailbox)
              .timeout(const Duration(seconds: 8));
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
            final fetched = await mailService.client
                .fetchMessageSequence(
                  seq,
                  fetchPreference: FetchPreference.fullWhenWithinSize,
                )
                .timeout(
                  const Duration(seconds: 25),
                  onTimeout: () => <MimeMessage>[],
                );
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
            try {
              hasAtt = full.hasAttachments();
            } catch (_) {}

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
              final mailboxPath =
                  mailbox.encodedPath.isNotEmpty
                      ? mailbox.encodedPath
                      : (mailbox.path);
              final uidValidity = mailbox.uidValidity ?? 0;
              String? rawHtml = full.decodeTextHtmlPart();
              String? plain = full.decodeTextPlainPart();
              String? sanitizedHtml;
              if (rawHtml != null && rawHtml.trim().isNotEmpty) {
                // Pre-sanitize large HTML off main thread
                String preprocessed = rawHtml;
                if (rawHtml.length > 100 * 1024) {
                  try {
                    preprocessed =
                        await MessageContentStore.sanitizeHtmlInIsolate(
                          rawHtml,
                        );
                  } catch (_) {}
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
              if ((sanitizedHtml != null && sanitizedHtml.isNotEmpty) ||
                  (plain != null && plain.isNotEmpty)) {
                await MessageContentStore.instance.upsertContent(
                  accountEmail: accountEmail,
                  mailboxPath: mailboxPath,
                  uidValidity: uidValidity,
                  uid: full.uid ?? -1,
                  plainText: plain,
                  htmlSanitizedBlocked: sanitizedHtml,
                  sanitizedVersion: 2,
                  forceMaterialize:
                      FeatureFlags.instance.htmlMaterializeInitialWindow,
                );
              }
            } catch (_) {}

            // Replace in-memory message with full version
            try {
              final listRef = emails[mailbox];
              if (listRef != null) {
                final idx = listRef.indexWhere(
                  (m) =>
                      (full.uid != null && m.uid == full.uid) ||
                      (full.sequenceId != null &&
                          m.sequenceId == full.sequenceId),
                );
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
                    String norm(String? s) {
                      if (s == null) return '';
                      var t = s.trim();
                      final rx = RegExp(
                        r'^(?:(re|fw|fwd|aw|wg)\s*:\s*)+',
                        caseSensitive: false,
                      );
                      t = t.replaceAll(rx, '').trim();
                      return t.toLowerCase();
                    }

                    String key() {
                      final refs = full.getHeaderValue('references');
                      if (refs != null && refs.isNotEmpty) {
                        final ids =
                            RegExp(
                              r'<[^>]+>',
                            ).allMatches(refs).map((m) => m.group(0)!).toList();
                        if (ids.isNotEmpty) return ids.first;
                      }
                      final irt = full.getHeaderValue('in-reply-to');
                      if (irt != null && irt.isNotEmpty) {
                        final id = RegExp(r'<[^>]+>').firstMatch(irt)?.group(0);
                        if (id != null) return id;
                      }
                      return 'subj::${norm(full.decodeSubject() ?? full.envelope?.subject)}';
                    }

                    final k = key();
                    tc =
                        listRef.where((m) {
                          String kk;
                          final refs = m.getHeaderValue('references');
                          if (refs != null && refs.isNotEmpty) {
                            final ids =
                                RegExp(r'<[^>]+>')
                                    .allMatches(refs)
                                    .map((mm) => mm.group(0)!)
                                    .toList();
                            kk = ids.isNotEmpty ? ids.first : '';
                          } else {
                            final irt2 = m.getHeaderValue('in-reply-to');
                            if (irt2 != null && irt2.isNotEmpty) {
                              kk =
                                  RegExp(
                                    r'<[^>]+>',
                                  ).firstMatch(irt2)?.group(0) ??
                                  '';
                            } else {
                              kk =
                                  'subj::${norm(m.decodeSubject() ?? m.envelope?.subject)}';
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
              try {
                bumpMessageMeta(mailbox, full);
              } catch (_) {}
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
  Future<void> _fastPreviewForNewMessages(
    Mailbox mailbox,
    List<MimeMessage> messages,
  ) async {
    try {
      if (messages.isEmpty) return;

      // Ensure selection (best-effort, short timeout)
      try {
        if (mailService.client.selectedMailbox?.encodedPath !=
            mailbox.encodedPath) {
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
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => <MimeMessage>[],
              );
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
              final idx = listRef.indexWhere(
                (m) =>
                    (full.uid != null && m.uid == full.uid) ||
                    (full.sequenceId != null &&
                        m.sequenceId == full.sequenceId),
              );
              if (idx != -1) {
                listRef[idx] = full;
              }
            }
          } catch (_) {}

          // Notify tile meta changes and refresh UI
          try {
            bumpMessageMeta(mailbox, full);
          } catch (_) {}
          emails.refresh();
          update();
        } catch (_) {}
      }
    } catch (_) {}
  }

  // Ensure envelope JSON exists for new messages to avoid Unknown/No Subject tiles
  Future<void> _ensureEnvelopesForNewMessages(
    Mailbox mailbox,
    List<MimeMessage> messages,
  ) async {
    try {
      if (messages.isEmpty) return;
      final storage = mailboxStorage[mailbox];
      for (final base in messages) {
        // Skip if envelope already has from+subject
        final hasFrom =
            base.envelope?.from?.isNotEmpty == true ||
            (base.from?.isNotEmpty == true);
        final hasSubj =
            (base.envelope?.subject?.isNotEmpty == true) ||
            ((base.decodeSubject() ?? '').isNotEmpty);
        if (hasFrom && hasSubj) continue;
        try {
          final seq = MessageSequence.fromMessage(base);
          final fetched = await mailService.client
              .fetchMessageSequence(
                seq,
                fetchPreference: FetchPreference.envelope,
              )
              .timeout(
                const Duration(seconds: 8),
                onTimeout: () => <MimeMessage>[],
              );
          if (fetched.isEmpty) continue;
          final envMsg = fetched.first;
          // Update in-memory instance if present
          try {
            final listRef = emails[mailbox];
            if (listRef != null) {
              final idx = listRef.indexWhere(
                (m) =>
                    (envMsg.uid != null && m.uid == envMsg.uid) ||
                    (envMsg.sequenceId != null &&
                        m.sequenceId == envMsg.sequenceId),
              );
              if (idx != -1) {
                // Merge envelope into existing message instance if full not available yet
                listRef[idx].envelope = envMsg.envelope;
                // Also hydrate top-level from if missing so details card shows proper sender
                try {
                  if ((listRef[idx].from == null ||
                          listRef[idx].from!.isEmpty) &&
                      (envMsg.envelope?.from?.isNotEmpty ?? false)) {
                    listRef[idx].from = envMsg.envelope!.from;
                  }
                } catch (_) {}
                bumpMessageMeta(mailbox, listRef[idx]);
              }
            }
          } catch (_) {}
          // Persist in DB for future loads
          try {
            await storage?.updateEnvelopeFromMessage(envMsg);
          } catch (_) {}
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
          print(
            '📧 ⏸️ Skipping foreground polling because optimized IDLE is active',
          );
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
      final clamped =
          secs < AppConstants.FOREGROUND_POLL_MIN_INTERVAL_SECONDS
              ? AppConstants.FOREGROUND_POLL_MIN_INTERVAL_SECONDS
              : secs; // minimum safety interval
      pollingInterval = Duration(seconds: clamped);

      _pollingMailboxPath = mailbox.encodedPath;
      _pollTimer = Timer.periodic(pollingInterval, (t) async {
        if (_pollingMailboxPath != mailbox.encodedPath)
          return; // mailbox switched
        if (isLoadingEmails.value || isPrefetching.value)
          return; // avoid overlap
        // Also skip if optimized IDLE has become active since starting the timer
        if (idle.isRunning || idle.isIdleActive) return;
        try {
          await _pollOnce(mailbox);
        } catch (e) {
          logger.w('Polling error: $e');
        }
      });
      if (kDebugMode) {
        print(
          '📧 🔄 Foreground polling started for ${mailbox.name} every ${pollingInterval.inSeconds}s',
        );
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

  // Auto background refresh (quiet, delta-driven) for the selected mailbox
  void _startAutoBackgroundRefresh({
    Duration period = const Duration(
      seconds: AppConstants.AUTO_REFRESH_PERIOD_SECONDS,
    ),
  }) {
    try {
      _stopAutoBackgroundRefresh();
      _autoRefreshTimer = Timer.periodic(period, (t) async {
        if (_autoSyncInFlight) return;
        // Respect in-flight loads/prefetches
        if (isLoadingEmails.value || isPrefetching.value) return;
        // Require an actively selected mailbox
        final selected = mailService.client.selectedMailbox;
        final m = currentMailbox ?? selected;
        if (selected == null || m == null) return;

        final key =
            selected.encodedPath.isNotEmpty
                ? selected.encodedPath
                : selected.name;
        final uidNext = selected.uidNext;
        final exists = selected.messagesExists;
        final prevUid = _mailboxUidNextSnapshot[key];
        final prevEx = _mailboxExistsSnapshot[key];

        final hasChange =
            (uidNext != null && uidNext != prevUid) ||
            (prevEx == null || exists != prevEx);
        // Snapshot current server meta
        _mailboxUidNextSnapshot[key] = uidNext;
        _mailboxExistsSnapshot[key] = exists;

        if (!hasChange) return; // No delta → no work
        final now = DateTime.now();
        if (now.difference(_lastAutoSyncRun).inSeconds < 5) return; // throttle

        _autoSyncInFlight = true;
        _lastAutoSyncRun = now;
        try {
          await _withIdlePause(() async {
            // Quiet incremental sync and quick reconciliations for near-real-time accuracy
            await _pollOnce(m, force: false);
            await _reconcileFlagsForRecent(m, window: 150);
            await reconcileRecentWithServer(m, window: 150);
          });
        } catch (_) {
          // Ignore background sync errors
        } finally {
          _autoSyncInFlight = false;
        }
      });
      if (kDebugMode) {
        print('📧 🤫 Auto background refresh started');
      }
    } catch (_) {}
  }

  void _stopAutoBackgroundRefresh() {
    try {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
      if (kDebugMode) {
        print('📧 📴 Auto background refresh stopped');
      }
    } catch (_) {}
  }

  // Monitor special-use mailboxes (Drafts, Sent, Trash, Junk) with low-impact periodic reconciliation
  void _startSpecialMailboxMonitor() {
    try {
      _specialMonitorTimer?.cancel();
      // 45s cadence strikes balance between freshness and battery usage
      _specialMonitorTimer = Timer.periodic(
        Duration(seconds: AppConstants.SPECIAL_MONITOR_PERIOD_SECONDS),
        (t) async {
          try {
            final specials = mailboxes
                .where((m) => m.isDrafts || m.isSent || m.isTrash || m.isJunk)
                .toList(growable: false);
            if (specials.isEmpty) return;
            // We reconcile even if IDLE is active, but keep it lightweight for large boxes
            for (final m in specials) {
              try {
                if (m.isDrafts) {
                  // Drafts are typically small; do exact reconciliation
                  await _reconcileDraftsExact(m, maxUidFetch: 2000);
                } else {
                  // For Sent/Trash/Junk, reconcile recent window
                  await reconcileRecentWithServer(m, window: 300);
                }
              } catch (_) {}
            }
          } catch (e) {
            if (kDebugMode) {
              print('📧 Special mailbox monitor tick failed: $e');
            }
          }
        },
      );
      if (kDebugMode) {
        print('📧 🔭 Special mailbox monitor started (Drafts/Sent/Trash/Junk)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 ⚠️ Failed to start special mailbox monitor: $e');
      }
    }
  }

  void _stopSpecialMailboxMonitor() {
    try {
      _specialMonitorTimer?.cancel();
      _specialMonitorTimer = null;
      if (kDebugMode) {
        print('📧 📴 Special mailbox monitor stopped');
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
        try {
          await mailService.connect().timeout(const Duration(seconds: 8));
        } catch (_) {
          return;
        }
      }
      if (mailService.client.selectedMailbox?.encodedPath !=
          mailbox.encodedPath) {
        try {
          await mailService.client
              .selectMailbox(mailbox)
              .timeout(const Duration(seconds: 8));
        } catch (_) {
          return;
        }
      }

      // Incremental sync: fetch only what capacity allows beyond current window
      final currentLen = emails[mailbox]?.length ?? 0;
      final target = math.min(
        mailbox.messagesExists,
        math.max(200, currentLen + 20),
      );
      final satisfied = await _enterpriseSync(
        mailbox,
        storage,
        maxToLoad: target,
        quiet: true,
      );
      if (!satisfied) return;

      // Quiet prefetch for a small number of top unready messages
      await _prefetchTopUnready(
        mailbox,
        limit: math.min(200, emails[mailbox]?.length ?? 0),
        maxToPrefetch: 12,
      );

      // Trigger reactive update without UI progress noise
      emails.refresh();
      update();
    } catch (e) {
      logger.w('Polling step failed: $e');
    }
  }

  Future<void> _prefetchTopUnready(
    Mailbox mailbox, {
    required int limit,
    int maxToPrefetch = 10,
  }) async {
    try {
      final list = List<MimeMessage>.from(
        (emails[mailbox] ?? const <MimeMessage>[]).take(limit),
      );
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

  // Reconcile server flags/read status for recent window by fetching messages and applying flag changes
  Future<void> _reconcileFlagsForRecent(
    Mailbox mailbox, {
    int window = 300,
  }) async {
    await ImapCommandQueue.instance.run('reconcileFlagsForRecent', () async {
      try {
        // Ensure connection and selection
        await _ensureConnectedAndSelectedMailbox(mailbox);
        final selected = mailService.client.selectedMailbox ?? mailbox;
        final exists = selected.messagesExists;
        if (exists <= 0) return;
        final take = window.clamp(1, 2000);
        int start = exists - take + 1;
        if (start < 1) start = 1;
        final seq = MessageSequence.fromRange(start, exists);

        // Fetch full or envelope with flags for that range
        // Using fullWhenWithinSize to ensure flags are populated consistently
        final fetched = await mailService.client
            .fetchMessageSequence(
              seq,
              fetchPreference: FetchPreference.fullWhenWithinSize,
            )
            .timeout(
              const Duration(seconds: 25),
              onTimeout: () => <MimeMessage>[],
            );
        if (fetched.isEmpty) return;

        // Build map by UID for quick lookup
        final byUid = <int, MimeMessage>{};
        for (final m in fetched) {
          if (m.uid != null) byUid[m.uid!] = m;
        }

        final listRef = emails[mailbox];
        if (listRef == null || listRef.isEmpty) return;

        bool changed = false;
        for (int i = 0; i < listRef.length; i++) {
          final local = listRef[i];
          final uid = local.uid;
          if (uid == null) continue;
          final server = byUid[uid];
          if (server == null) continue;
          bool any = false;
          // Compare and update seen flag
          if (local.isSeen != server.isSeen) {
            local.isSeen = server.isSeen;
            any = true;
          }
          // Compare and update flagged flag
          if (local.isFlagged != server.isFlagged) {
            local.isFlagged = server.isFlagged;
            any = true;
          }
          if (any) {
            changed = true;
            try {
              await mailboxStorage[mailbox]?.saveMessageEnvelopes([local]);
            } catch (_) {}
          }
        }

        if (changed) {
          emails.refresh();
          update();
        }
      } catch (e) {
        logger.w('reconcileFlagsForRecent failed: $e');
      }
    });
  }

  Future<void> _prefetchFullContentForMessages(
    Mailbox mailbox,
    List<MimeMessage> messages, {
    bool quiet = false,
  }) async {
    try {
      if (messages.isEmpty) return;
      // Ensure selection
      try {
        if (mailService.client.selectedMailbox?.encodedPath !=
            mailbox.encodedPath) {
          await mailService.client
              .selectMailbox(mailbox)
              .timeout(const Duration(seconds: 8));
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
            final fetched = await mailService.client
                .fetchMessageSequence(
                  seq,
                  fetchPreference: FetchPreference.fullWhenWithinSize,
                )
                .timeout(
                  const Duration(seconds: 20),
                  onTimeout: () => <MimeMessage>[],
                );
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
            try {
              hasAtt = full.hasAttachments();
            } catch (_) {}

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
              final mailboxPath =
                  mailbox.encodedPath.isNotEmpty
                      ? mailbox.encodedPath
                      : (mailbox.path);
              final uidValidity = mailbox.uidValidity ?? 0;
              String? rawHtml = full.decodeTextHtmlPart();
              String? plain = full.decodeTextPlainPart();
              String? sanitizedHtml;
              if (rawHtml != null && rawHtml.trim().isNotEmpty) {
                String preprocessed = rawHtml;
                if (rawHtml.length > 100 * 1024) {
                  try {
                    preprocessed =
                        await MessageContentStore.sanitizeHtmlInIsolate(
                          rawHtml,
                        );
                  } catch (_) {}
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
              if ((sanitizedHtml != null && sanitizedHtml.isNotEmpty) ||
                  (plain != null && plain.isNotEmpty)) {
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
                final idx = listRef.indexWhere(
                  (m) =>
                      (full.uid != null && m.uid == full.uid) ||
                      (full.sequenceId != null &&
                          m.sequenceId == full.sequenceId),
                );
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
                    String norm(String? s) {
                      if (s == null) return '';
                      var t = s.trim();
                      final rx = RegExp(
                        r'^(?:(re|fw|fwd|aw|wg)\s*:\s*)+',
                        caseSensitive: false,
                      );
                      t = t.replaceAll(rx, '').trim();
                      return t.toLowerCase();
                    }

                    String key() {
                      final refs = full.getHeaderValue('references');
                      if (refs != null && refs.isNotEmpty) {
                        final ids =
                            RegExp(
                              r'<[^>]+>',
                            ).allMatches(refs).map((m) => m.group(0)!).toList();
                        if (ids.isNotEmpty) return ids.first;
                      }
                      final irt = full.getHeaderValue('in-reply-to');
                      if (irt != null && irt.isNotEmpty) {
                        final id = RegExp(r'<[^>]+>').firstMatch(irt)?.group(0);
                        if (id != null) return id;
                      }
                      return 'subj::${norm(full.decodeSubject() ?? full.envelope?.subject)}';
                    }

                    final k = key();
                    tc =
                        listRef.where((m) {
                          String kk;
                          final refs = m.getHeaderValue('references');
                          if (refs != null && refs.isNotEmpty) {
                            final ids =
                                RegExp(r'<[^>]+>')
                                    .allMatches(refs)
                                    .map((mm) => mm.group(0)!)
                                    .toList();
                            kk = ids.isNotEmpty ? ids.first : '';
                          } else {
                            final irt2 = m.getHeaderValue('in-reply-to');
                            if (irt2 != null && irt2.isNotEmpty) {
                              kk =
                                  RegExp(
                                    r'<[^>]+>',
                                  ).firstMatch(irt2)?.group(0) ??
                                  '';
                            } else {
                              kk =
                                  'subj::${norm(m.decodeSubject() ?? m.envelope?.subject)}';
                            }
                          }
                          return kk == k;
                        }).length;
                  } catch (_) {}
                }
                full.setHeader('x-thread-count', '${tc <= 0 ? 1 : tc}');
              } catch (_) {}
              full.setHeader('x-ready', '1');
              try {
                bumpMessageMeta(mailbox, full);
              } catch (_) {}
            } catch (_) {}

            // Optional small attachment prefetch
            await _maybePrefetchSmallAttachments(mailbox, full);
          } catch (_) {
            // ignore per-message errors
          } finally {
            if (!quiet) {
              _updateReadyProgress(
                mailbox,
                math.min(200, emails[mailbox]?.length ?? 0),
              );
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
  Future<void> prefetchMessageContent(
    Mailbox mailbox,
    MimeMessage message, {
    bool quiet = true,
  }) async {
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
        if (mailService.client.selectedMailbox?.encodedPath !=
            mailbox.encodedPath) {
          await mailService.client
              .selectMailbox(mailbox)
              .timeout(const Duration(seconds: 8));
        }
      } catch (_) {}

      final infos = full.findContentInfo(
        disposition: ContentDisposition.attachment,
      );
      if (infos.isEmpty) return;

      int prefetched = 0;
      for (final info in infos) {
        if (prefetched >= maxAttachments) break;
        final size = info.size ?? 0;
        if (size <= 0 || size > maxBytesPerAttachment) continue;
        try {
          final part = await mailService.client
              .fetchMessagePart(full, info.fetchId)
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
        if (m.isDrafts) {
          // Exact, server-authoritative reconciliation for Drafts
          await _reconcileDraftsExact(m, maxUidFetch: 2000);
        } else {
          await _pollOnce(m, force: true);
          // After polling, reconcile against server for recent window to capture deletions
          await reconcileRecentWithServer(m, window: 300);
          // Also reconcile flags/read status for recent window so server changes appear without restart
          await _reconcileFlagsForRecent(m, window: 300);
        }
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

  /// Reconcile the top [window] messages in the mailbox against the server to remove locally deleted items.
  /// This is crucial when messages are deleted server-side (e.g., via webmail) so the app reflects the change.
  Future<void> reconcileRecentWithServer(
    Mailbox mailbox, {
    int window = 300,
  }) async {
    await ImapCommandQueue.instance.run('reconcileRecentWithServer', () async {
      try {
        final listRef = emails[mailbox] ?? <MimeMessage>[];
        if (listRef.isEmpty) return;

        // Ensure connection and selection
        try {
          if (!mailService.client.isConnected) {
            await mailService.connect().timeout(const Duration(seconds: 8));
          }
          if (mailService.client.selectedMailbox?.encodedPath !=
              mailbox.encodedPath) {
            await mailService.client
                .selectMailbox(mailbox)
                .timeout(const Duration(seconds: 8));
          }
        } catch (_) {}

        final selected = mailService.client.selectedMailbox ?? mailbox;
        final exists = selected.messagesExists;
        if (exists <= 0) {
          // Mailbox empty on server -> clear local list and storage
          try {
            emails[mailbox]?.clear();
          } catch (_) {}
          try {
            await mailboxStorage[mailbox]?.deleteAllMessages();
          } catch (_) {}
          emails.refresh();
          update();
          return;
        }

        // Compute recent window by sequence range
        final take = window.clamp(1, 2000); // hard cap
        int start = exists - take + 1;
        if (start < 1) start = 1;
        final seq = MessageSequence.fromRange(start, exists);

        // Fetch envelope-only for speed; we only need UIDs
        final recent = await mailService.client
            .fetchMessageSequence(
              seq,
              fetchPreference: FetchPreference.envelope,
            )
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () => <MimeMessage>[],
            );

        if (recent.isEmpty) return;
        final serverUids = recent.map((m) => m.uid).whereType<int>().toSet();

        // Determine local candidates within top window
        final localTop = List<MimeMessage>.from(listRef.take(take));
        final toRemove = <int>{};
        for (final m in localTop) {
          final uid = m.uid;
          if (uid != null && !serverUids.contains(uid)) {
            toRemove.add(uid);
          }
        }
        if (toRemove.isEmpty) return;

        // Remove from UI list
        listRef.removeWhere((m) => m.uid != null && toRemove.contains(m.uid));
        emails[mailbox] = listRef;
        emails.refresh();
        update();

        // Remove from local storage (best-effort)
        final st = mailboxStorage[mailbox];
        if (st != null) {
          for (final uid in toRemove) {
            try {
              await st.deleteMessageEnvelopes(
                MessageSequence.fromRange(uid, uid, isUidSequence: true),
              );
            } catch (_) {}
          }
        }
      } catch (_) {}
    });
  }

  // Exact reconciliation for Drafts: replace local state with authoritative server state using UID-based fetch
  Future<void> _reconcileDraftsExact(
    Mailbox mailbox, {
    int maxUidFetch = 2000,
  }) async {
    await ImapCommandQueue.instance.run('reconcileDraftsExact', () async {
      try {
        // Initialize storage if needed
        mailboxStorage[mailbox] ??= SQLiteMailboxMimeStorage(
          mailAccount: mailService.account,
          mailbox: mailbox,
        );
        await mailboxStorage[mailbox]!.init();
        emails[mailbox] ??= <MimeMessage>[];

        // Ensure connection and selection
        if (!mailService.client.isConnected) {
          await mailService.connect().timeout(const Duration(seconds: 10));
        }
        if (mailService.client.selectedMailbox?.encodedPath !=
            mailbox.encodedPath) {
          await mailService.client
              .selectMailbox(mailbox)
              .timeout(const Duration(seconds: 10));
        }

        // Use the freshly selected mailbox status for authoritative counts/UIDs
        final selected = mailService.client.selectedMailbox ?? mailbox;
        final exists = selected.messagesExists;
        if (exists <= 0) {
          // Empty on server: clear local completely
          emails[mailbox]!.clear();
          await mailboxStorage[mailbox]!.deleteAllMessages();
          emails.refresh();
          update();
          return;
        }

        // Determine UID range to fetch using fresh UIDNEXT
        final uidNext = selected.uidNext;
        int fromUid = 1;
        int toUid;
        if (uidNext != null) {
          toUid = uidNext - 1;
          // Limit to maxUidFetch to avoid large scans; Drafts are usually small
          if ((toUid - fromUid + 1) > maxUidFetch) {
            fromUid = toUid - maxUidFetch + 1;
          }
        } else {
          // Fallback to sequence numbers if UIDNEXT is not available
          final startSeq = math.max(1, exists - maxUidFetch + 1);
          final endSeq = exists;
          final seq = MessageSequence.fromRange(startSeq, endSeq);
          final fetched = await mailService.client
              .fetchMessageSequence(
                seq,
                fetchPreference: FetchPreference.envelope,
              )
              .timeout(
                const Duration(seconds: 25),
                onTimeout: () => <MimeMessage>[],
              );
          await _replaceLocalWithFetchedDrafts(mailbox, fetched);
          return;
        }

        // Fetch by UID in chunks to build the authoritative set
        final List<MimeMessage> fetched = [];
        const int chunk = 200;
        int cur = fromUid;
        while (cur <= toUid) {
          final end = math.min(toUid, cur + chunk - 1);
          final uidSeq = MessageSequence.fromRange(
            cur,
            end,
            isUidSequence: true,
          );
          final part = await mailService.client
              .fetchMessageSequence(
                uidSeq,
                fetchPreference: FetchPreference.envelope,
              )
              .timeout(
                const Duration(seconds: 25),
                onTimeout: () => <MimeMessage>[],
              );
          if (part.isNotEmpty) fetched.addAll(part);
          cur = end + 1;
        }

        await _replaceLocalWithFetchedDrafts(mailbox, fetched);
      } catch (e) {
        logger.w('Drafts exact reconciliation failed: $e');
      }
    });
  }

  Future<void> _replaceLocalWithFetchedDrafts(
    Mailbox mailbox,
    List<MimeMessage> fetched,
  ) async {
    try {
      // Normalize by unique UID and sort newest first
      final Map<int, MimeMessage> byUid = {};
      for (final m in fetched) {
        if (m.uid != null) byUid[m.uid!] = m;
      }
      final list = byUid.values.toList();
      list.sort((a, b) {
        final da = a.decodeDate();
        final db = b.decodeDate();
        if (da == null && db == null) return (b.uid ?? 0).compareTo(a.uid ?? 0);
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

      // Replace in-memory and storage to match server exactly
      emails[mailbox]!.clear();
      emails[mailbox]!.addAll(list);
      emails.refresh();
      update();

      final storage = mailboxStorage[mailbox]!;
      await storage.deleteAllMessages();
      if (list.isNotEmpty) {
        await storage.saveMessageEnvelopes(list);
      }

      // Update counts
      if (Get.isRegistered<MailCountController>()) {
        final countController = Get.find<MailCountController>();
        String key = "${mailbox.name.toLowerCase()}_count";
        countController.counts[key] = list.length;
      }
    } catch (e) {
      logger.w('Replacing local drafts with fetched set failed: $e');
    }
  }

  // Pause optimized IDLE around a critical foreground sync to avoid DONE contention
  Future<T> _withIdlePause<T>(Future<T> Function() action) async {
    final idle = OptimizedIdleService.instance;
    final wasRunning = idle.isRunning || idle.isIdleActive;
    if (wasRunning) {
      try {
        await idle.stopOptimizedIdle();
      } catch (_) {}
    }
    try {
      return await action();
    } finally {
      if (wasRunning) {
        try {
          await idle.startOptimizedIdle();
        } catch (_) {}
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

    // Stop special mailbox monitor
    _stopSpecialMailboxMonitor();

    // Stop auto background refresh
    _stopAutoBackgroundRefresh();

    // Dispose meta notifiers
    for (final n in _messageMeta.values) {
      try {
        n.dispose();
      } catch (_) {}
    }
    _messageMeta.clear();

    super.dispose();
  }
}
