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
import 'package:wahda_bank/services/internet_service.dart';
import 'package:flutter/foundation.dart';
import 'package:enough_mail/enough_mail.dart' show MailAccount;
import 'background_task_controller.dart';
import 'contact_controller.dart';
import 'email_storage_controller.dart';
import 'email_ui_state_controller.dart';

/// Model class for email updates to improve stream efficiency
class EmailUpdate {
  final Mailbox mailbox;
  final UpdateType type;
  final List<MimeMessage> messages;
  final List<int>? removedUids;

  EmailUpdate({
    required this.mailbox,
    required this.type,
    required this.messages,
    this.removedUids,
  });
}

/// Enum for update types to make UI updates more efficient
enum UpdateType {
  add,
  update,
  remove,
  replace,
}

/// Controller responsible for fetching emails from server and managing email data
class EmailFetchController extends GetxController {
  final Logger logger = Logger();
  final getStorage = GetStorage();

  // Loading states
  final RxBool isBusy = false.obs;
  final RxBool isBoxBusy = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isConnected = false.obs;

  // Email data - single source of truth
  final RxMap<Mailbox, List<MimeMessage>> emails = <Mailbox, List<MimeMessage>>{}.obs;

  // Enhanced stream controller for reactive updates with granular change notifications
  final _emailsSubject = BehaviorSubject<EmailUpdate>();
  Stream<EmailUpdate> get emailsStream => _emailsSubject.stream;

  // Compatibility stream for widgets expecting the old format
  // This converts EmailUpdate to Map<Mailbox, List<MimeMessage>> for backward compatibility
  Stream<Map<Mailbox, List<MimeMessage>>> get emailsMapStream =>
      _emailsSubject.stream.map((_) => emails);

  // Track last fetched UID for each mailbox
  final Map<Mailbox, int> _lastFetchedUids = {};

  // Track if initial load has been done for each mailbox
  final Map<String, bool> _initialLoadDone = {}; // Changed to use encodedPath as key for persistence

  // Track pagination for each mailbox
  final Map<Mailbox, int> _currentPage = {};
  final int pageSize = 100;

  // Debounce timer for UI updates
  Timer? _debounceTimer;

  // Connection management
  Timer? _connectionKeepAliveTimer;
  final Duration _keepAliveDuration = const Duration(minutes: 5);

  // Retry configuration
  final int _maxRetries = 3;
  final Duration _retryDelay = const Duration(seconds: 2);

  // Services and controllers
  late MailService mailService;
  late BackgroundTaskController _backgroundTaskController;
  late EmailStorageController _storageController;
  EmailUiStateController? _uiStateController;

  // Lock to prevent concurrent operations on the same mailbox
  final Map<String, Completer<void>> _mailboxLocks = {};

  @override
  void onInit() async {
    try {
      mailService = MailService.instance;

      // Get required controllers
      _backgroundTaskController = Get.find<BackgroundTaskController>();
      _storageController = Get.find<EmailStorageController>();

      // Try to find UI state controller, but don't fail if not available yet
      if (Get.isRegistered<EmailUiStateController>()) {
        _uiStateController = Get.find<EmailUiStateController>();
      }

      // Initialize the emails subject
      if (!_emailsSubject.hasValue) {
        _emailsSubject.add(EmailUpdate(
          mailbox: Mailbox(encodedName: '', encodedPath: '', flags: [], pathSeparator: ''),
          type: UpdateType.replace,
          messages: [],
        ));
      }

      // Load initial load state from storage
      _loadInitialLoadState();

      // Start connection keep-alive
      _startConnectionKeepAlive();

      // Initialize mailbox loading after a short delay to ensure all controllers are ready
      Future.delayed(const Duration(milliseconds: 500), () {
        _initializeMailboxes();
      });

      super.onInit();
    } catch (e) {
      logger.e("Error initializing EmailFetchController: $e");
    } finally {
      isBusy(false);
    }
  }

  // Initialize mailboxes and load initial data
  Future<void> _initializeMailboxes() async {
    try {
      // Ensure connection
      if (!await ensureConnection()) {
        logger.e("Failed to connect to mail server during initialization");
        return;
      }

      // Add a short delay to ensure server info is initialized
      await Future.delayed(Duration(milliseconds: 500));

      // Get mailboxes list with retry logic
      int attempts = 0;
      Mailbox? inboxMailbox;

      while (attempts < 5 && inboxMailbox == null) {
        try {
          // Get mailboxes list
          final mailboxes = await mailService.client.listMailboxes();

          // Find inbox mailbox
          inboxMailbox = mailboxes.firstWhereOrNull(
                (box) => box.isInbox,
          );

          if (inboxMailbox == null) {
            attempts++;
            logger.w("Inbox mailbox not found, retrying ($attempts/5)...");
            await Future.delayed(Duration(milliseconds: 500 * attempts));
          }
        } catch (e) {
          attempts++;
          logger.e("Error listing mailboxes (attempt $attempts): $e");
          await Future.delayed(Duration(milliseconds: 500 * attempts));
        }
      }

      if (inboxMailbox != null) {
        // Load inbox emails
        await loadEmailsForBox(inboxMailbox);
      } else {
        logger.e("Inbox mailbox not found after multiple attempts");
      }
    } catch (e) {
      logger.e("Error initializing mailboxes: $e");
    }
  }

  // Load initial load state from storage
  void _loadInitialLoadState() {
    try {
      final initialLoadState = getStorage.read<Map<String, dynamic>>('initialLoadState');
      if (initialLoadState != null) {
        initialLoadState.forEach((key, value) {
          if (value is bool) {
            _initialLoadDone[key] = value;
          }
        });
      }
    } catch (e) {
      logger.e("Error loading initial load state: $e");
    }
  }

  // Save initial load state to storage
  void _saveInitialLoadState() {
    try {
      getStorage.write('initialLoadState', _initialLoadDone);
    } catch (e) {
      logger.e("Error saving initial load state: $e");
    }
  }

  /// Get emails for a specific mailbox
  List<MimeMessage> getEmailsForMailbox(Mailbox mailbox) {
    return emails[mailbox] ?? [];
  }

  /// Get emails for the currently selected mailbox
  List<MimeMessage> get boxMails {
    final selectedMailbox = mailService.client.selectedMailbox;
    if (selectedMailbox == null) {
      return [];
    }
    return emails[selectedMailbox] ?? [];
  }

  /// Get a filtered stream for a specific mailbox
  Stream<List<MimeMessage>> getMailboxStream(Mailbox mailbox) {
    return emailsStream
        .where((update) => update.mailbox == mailbox)
        .map((_) => emails[mailbox] ?? []);
  }

  /// Ensure connection to mail server with improved error handling and retry logic
  Future<bool> ensureConnection() async {
    // If already connected, verify the connection is still valid
    if (mailService.client.isConnected) {
      try {
        // Simple NOOP command to verify connection is still valid
        final imapClient = mailService.client.lowLevelIncomingMailClient as ImapClient;
        await imapClient.noop();
        isConnected(true);
        return true;
      } catch (e) {
        logger.w("Connection check failed, will attempt reconnect: $e");
        // Fall through to reconnection logic
      }
    }

    // Connection is not valid, attempt to reconnect with retries
    isConnected(false);

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        await mailService.connect();
        isConnected(true);
        logger.d("Successfully connected to mail server");
        return true;
      } catch (e) {
        final isLastAttempt = attempt == _maxRetries - 1;
        logger.e("Error connecting to mail server (attempt ${attempt + 1}/$_maxRetries): $e");

        if (!isLastAttempt) {
          // Wait before retry with exponential backoff
          final delay = _retryDelay * math.pow(2, attempt).toInt();
          logger.d("Retrying in ${delay.inSeconds} seconds...");
          await Future.delayed(delay);
        }
      }
    }

    // All retries failed
    isConnected(false);

    // Show error to user
    Get.showSnackbar(
      const GetSnackBar(
        message: 'Unable to connect to mail server. Please check your internet connection.',
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );

    return false;
  }

  /// Start connection keep-alive timer with improved reconnection logic
  void _startConnectionKeepAlive() {
    _connectionKeepAliveTimer?.cancel();
    _connectionKeepAliveTimer = Timer.periodic(_keepAliveDuration, (_) {
      if (isConnected.value) {
        _backgroundTaskController.queueOperation(() async {
          try {
            // Simple NOOP command to keep connection alive
            final imapClient = mailService.client.lowLevelIncomingMailClient as ImapClient;
            await imapClient.noop();
            logger.d("Keep-alive successful");
          } catch (e) {
            logger.e("Error in keep-alive: $e");
            // Try to reconnect with full retry logic
            await ensureConnection();
          }
        }, priority: Priority.high);
      } else {
        // If not connected, try to establish connection
        _backgroundTaskController.queueOperation(() async {
          await ensureConnection();
        }, priority: Priority.high);
      }
    });
  }

  /// Acquire a lock for a mailbox to prevent concurrent operations
  Future<void> _acquireMailboxLock(Mailbox mailbox) async {
    final lockKey = mailbox.encodedPath;
    if (_mailboxLocks.containsKey(lockKey)) {
      // Wait for existing operation to complete
      await _mailboxLocks[lockKey]!.future;
    }

    // Create a new lock
    final completer = Completer<void>();
    _mailboxLocks[lockKey] = completer;
  }

  /// Release a lock for a mailbox
  void _releaseMailboxLock(Mailbox mailbox) {
    final lockKey = mailbox.encodedPath;
    if (_mailboxLocks.containsKey(lockKey)) {
      _mailboxLocks[lockKey]!.complete();
      _mailboxLocks.remove(lockKey);
    }
  }

  /// Load emails for a specific mailbox with improved coordination between server and local storage
  Future<void> loadEmailsForBox(Mailbox mailbox) async {
    // Acquire lock to prevent concurrent operations on the same mailbox
    await _acquireMailboxLock(mailbox);

    try {
      if (!await ensureConnection()) {
        return;
      }

      isBoxBusy(true);

      // Update UI state if controller is available
      _uiStateController?.setMailboxLoading(mailbox, true);

      // Initialize storage for this mailbox
      await _storageController.initializeMailboxStorage(mailbox);

      // First, try to load from local storage to show something immediately
      final localMessages = await _storageController.loadMessagesFromStorage(mailbox);

      if (localMessages != null && localMessages.isNotEmpty) {
        // Update the emails map with local data first for immediate UI update
        emails[mailbox] = localMessages;
        notifyEmailsChanged(mailbox, UpdateType.replace, localMessages);
      }

      // Ensure the mailbox is selected before proceeding
      try {
        await mailService.client.selectMailbox(mailbox);
      } catch (e) {
        logger.e("Error selecting mailbox: $e");
        // Try to reconnect and select again
        if (await ensureConnection()) {
          await mailService.client.selectMailbox(mailbox);
        } else {
          throw Exception("Failed to select mailbox after reconnection attempt");
        }
      }

      // Check if this is the first load or a refresh
      final mailboxKey = mailbox.encodedPath;
      if (!(_initialLoadDone[mailboxKey] ?? false)) {
        await fetchMailbox(mailbox);
        _initialLoadDone[mailboxKey] = true;
        _saveInitialLoadState(); // Persist the state
      } else {
        // For subsequent loads, only fetch new emails
        await fetchNewEmails(mailbox);
      }
    } catch (e) {
      logger.e("Error loading emails for mailbox: $e");

      // Show error to user
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error loading mailbox: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      // Even if server fetch fails, try to show local data
      final localMessages = await _storageController.loadMessagesFromStorage(mailbox);
      if (localMessages != null && localMessages.isNotEmpty) {
        emails[mailbox] = localMessages;
        notifyEmailsChanged(mailbox, UpdateType.replace, localMessages);
      }
    } finally {
      isBoxBusy(false);

      // Update UI state if controller is available
      _uiStateController?.setMailboxLoading(mailbox, false);

      // Release the lock
      _releaseMailboxLock(mailbox);
    }
  }

  /// Load more emails when scrolling down (pagination) with improved error handling
  Future<void> loadMoreEmails(Mailbox mailbox) async {
    if (isLoadingMore.value || isBoxBusy.value) return;

    // Acquire lock to prevent concurrent operations on the same mailbox
    await _acquireMailboxLock(mailbox);

    isLoadingMore(true);

    // Update UI state if controller is available
    _uiStateController?.setLoadingMore(true);

    try {
      if (!await ensureConnection()) {
        isLoadingMore(false);
        _uiStateController?.setLoadingMore(false);
        return;
      }

      // Ensure the mailbox is selected before proceeding
      try {
        await mailService.client.selectMailbox(mailbox);
      } catch (e) {
        logger.e("Error selecting mailbox: $e");
        // Try to reconnect and select again
        if (await ensureConnection()) {
          await mailService.client.selectMailbox(mailbox);
        } else {
          throw Exception("Failed to select mailbox after reconnection attempt");
        }
      }

      final currentPage = _currentPage[mailbox] ?? 1;
      final nextPage = currentPage + 2;

      // Calculate start and end indices for this page
      final startIndex = (nextPage - 1) * pageSize + 2;
      final endIndex = startIndex + pageSize - 1;

      // Check if we've reached the end
      if (startIndex > mailbox.messagesExists) {
        isLoadingMore(false);
        _uiStateController?.setLoadingMore(false);
        return;
      }

      // Create sequence for this page - ensure valid range
      int start = mailbox.messagesExists - endIndex + 1;
      int end = mailbox.messagesExists - startIndex + 1;

      // Ensure valid range (both must be positive)
      if (start < 1) start = 1;
      if (end < 1) end = 1;

      // Ensure start <= end
      if (start > end) {
        int temp = start;
        start = end;
        end = temp;
      }

      // Validate sequence range before proceeding
      if (start <= 0 || end <= 0 || start > mailbox.messagesExists || end > mailbox.messagesExists) {
        logger.e("Invalid sequence range: $start-$end (mailbox size: ${mailbox.messagesExists})");
        isLoadingMore(false);
        _uiStateController?.setLoadingMore(false);
        return;
      }

      final sequence = MessageSequence.fromRange(start, end);

      // Fetch messages for this page with retry logic
      final messages = await fetchMessageBatch(sequence);

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

          // Save to local storage
          _storageController.saveMessagesInBackground(newMessages, mailbox);

          // Notify about changes
          notifyEmailsChanged(mailbox, UpdateType.add, newMessages);
        }

        // Update current page
        _currentPage[mailbox] = nextPage;
      }
    } catch (e) {
      logger.e("Error loading more emails: $e");

      // Show error to user
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error loading more emails: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      isLoadingMore(false);

      // Update UI state if controller is available
      _uiStateController?.setLoadingMore(false);

      // Release the lock
      _releaseMailboxLock(mailbox);
    }
  }

  /// Refresh emails for a mailbox with improved error handling
  Future<void> refreshEmails(Mailbox mailbox) async {
    if (isRefreshing.value || isBoxBusy.value) return;

    // Acquire lock to prevent concurrent operations on the same mailbox
    await _acquireMailboxLock(mailbox);

    isRefreshing(true);

    // Update UI state if controller is available
    _uiStateController?.setRefreshing(true);

    try {
      if (!await ensureConnection()) {
        isRefreshing(false);
        _uiStateController?.setRefreshing(false);
        return;
      }

      // Ensure the mailbox is selected before proceeding
      try {
        await mailService.client.selectMailbox(mailbox);
      } catch (e) {
        logger.e("Error selecting mailbox: $e");
        // Try to reconnect and select again
        if (await ensureConnection()) {
          await mailService.client.selectMailbox(mailbox);
        } else {
          throw Exception("Failed to select mailbox after reconnection attempt");
        }
      }

      // Fetch new emails
      await fetchNewEmails(mailbox);
    } catch (e) {
      logger.e("Error refreshing emails: $e");

      // Show error to user
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error refreshing emails: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      isRefreshing(false);

      // Update UI state if controller is available
      _uiStateController?.setRefreshing(false);

      // Release the lock
      _releaseMailboxLock(mailbox);
    }
  }


  /// Reload all mailboxes after reconnection
  Future<void> reloadAllMailboxes() async {
    logger.d("Reloading all mailboxes after reconnection");

    try {
      // Reset state
      _initialLoadDone.clear();
      _currentPage.clear();

      // Reload mailboxes
      final mailboxes = await mailService.client.listMailboxes();

      // Find inbox
      final inbox = mailboxes.firstWhereOrNull((box) => box.isInbox);

      if (inbox != null) {
        // Force reload emails for inbox
        await loadEmailsForBox(inbox);
      }
    } catch (e) {
      logger.e("Error reloading mailboxes: $e");
    }
  }



  /// Fetch new emails for a mailbox with improved error handling and retry logic
  Future<void> fetchNewEmails(Mailbox? mailbox) async {
    if (mailbox == null) {
      logger.e("No mailbox selected for fetchNewEmails");
      return;
    }

    // Acquire lock to prevent concurrent operations on the same mailbox
    await _acquireMailboxLock(mailbox);

    isBoxBusy(true);
    isRefreshing(true);

    // Update UI state if controller is available
    _uiStateController?.setMailboxLoading(mailbox, true);
    _uiStateController?.setRefreshing(true);

    try {
      if (!await ensureConnection()) {
        isBoxBusy(false);
        isRefreshing(false);
        _uiStateController?.setMailboxLoading(mailbox, false);
        _uiStateController?.setRefreshing(false);
        return;
      }

      // Ensure the mailbox is selected before proceeding
      try {
        await mailService.client.selectMailbox(mailbox);
      } catch (e) {
        logger.e("Error selecting mailbox: $e");
        // Try to reconnect and select again
        if (await ensureConnection()) {
          await mailService.client.selectMailbox(mailbox);
        } else {
          throw Exception("Failed to select mailbox after reconnection attempt");
        }
      }

      int lastUid = _lastFetchedUids[mailbox] ?? 0;

      if (mailbox.uidNext != null && mailbox.isInbox) {
        await getStorage.write(
          BackgroundService.keyInboxLastUid,
          mailbox.uidNext,
        );
      }

      if (lastUid == 0) {
        await fetchMailbox(mailbox);
        return;
      }

      logger.d('Fetching new emails since UID $lastUid for ${mailbox.name}');

      // Check if there are new messages to fetch
      if (mailbox.uidNext == null || mailbox.uidNext! <= lastUid + 1) {
        logger.d('No new messages to fetch (uidNext: ${mailbox.uidNext}, lastUid: $lastUid)');
        isBoxBusy(false);
        isRefreshing(false);
        _uiStateController?.setMailboxLoading(mailbox, false);
        _uiStateController?.setRefreshing(false);
        return;
      }

      // Calculate UID range to fetch
      final int startUid = lastUid + 1;
      final int endUid = mailbox.uidNext! - 1;

      // Don't fetch if there's no valid UID range
      if (startUid > endUid) {
        logger.d("No valid UID range to fetch (startUid: $startUid, endUid: $endUid)");
        isBoxBusy(false);
        isRefreshing(false);
        _uiStateController?.setMailboxLoading(mailbox, false);
        _uiStateController?.setRefreshing(false);
        return;
      }

      // Create optimized sequence with UID ranges instead of individual UIDs
      final sequence = MessageSequence();
      sequence.addRange(startUid, endUid);

      if (sequence.isEmpty) {
        logger.d("Empty sequence, nothing to fetch");
        isBoxBusy(false);
        isRefreshing(false);
        _uiStateController?.setMailboxLoading(mailbox, false);
        _uiStateController?.setRefreshing(false);
        return;
      }

      try {
        // Get the ImapClient directly to use UID-based fetch
        final imapClient = mailService.client.lowLevelIncomingMailClient as ImapClient;

        // Use uidFetchMessages which is the correct method for UID-based fetching
        final fetchResult = await imapClient.uidFetchMessages(sequence, 'ENVELOPE');
        final newServerMessages = fetchResult.messages;

        if (newServerMessages.isNotEmpty) {
          // Sort newest first
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

          // Save to local storage
          _storageController.saveMessagesInBackground(newServerMessages, mailbox);

          // Initialize email list if needed
          emails.putIfAbsent(mailbox, () => []);

          // Filter out duplicates
          final existingUids = emails[mailbox]!.map((m) => m.uid).toSet();
          final uniqueNewMessages = newServerMessages
              .where((m) => !existingUids.contains(m.uid))
              .toList();

          if (uniqueNewMessages.isNotEmpty) {
            // Insert at beginning (newest first)
            emails[mailbox]!.insertAll(0, uniqueNewMessages);

            // Re-sort all messages by date to ensure consistency
            emails[mailbox]!.sort((a, b) {
              final dateA = a.decodeDate() ?? DateTime.now();
              final dateB = b.decodeDate() ?? DateTime.now();
              return dateB.compareTo(dateA);
            });

            // Notify about changes
            notifyEmailsChanged(mailbox, UpdateType.add, uniqueNewMessages);

            // Show notification
            Get.showSnackbar(
              GetSnackBar(
                message: 'Received ${uniqueNewMessages.length} new email(s)',
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        logger.e("Error in primary fetch method: $e");

        // Fallback: Try fetching in smaller batches if batch fetch failed
        if (e.toString().contains("Invalid messageset") ||
            e.toString().contains("UID FETCH") ||
            e.toString().contains("connection")) {
          logger.d("Trying fallback fetch method with smaller batches");

          // Split into smaller batches of 10 UIDs
          const int batchSize = 10;
          List<MimeMessage> allMessages = [];
          final imapClient = mailService.client.lowLevelIncomingMailClient as ImapClient;

          // Process in batches
          for (int i = startUid; i <= endUid; i += batchSize) {
            try {
              final batchEndUid = math.min(i + batchSize - 1, endUid);
              final batchSequence = MessageSequence();
              batchSequence.addRange(i, batchEndUid);

              final fetchResult = await imapClient.uidFetchMessages(batchSequence, 'ENVELOPE');
              final messages = fetchResult.messages;

              if (messages.isNotEmpty) {
                allMessages.addAll(messages);

                // Update last fetched UID
                for (var msg in messages) {
                  if (msg.uid != null && msg.uid! > lastUid) {
                    lastUid = msg.uid!;
                  }
                }
              }
            } catch (batchError) {
              // Log and continue with next batch
              logger.d("Error fetching batch $i-${math.min(i + batchSize - 1, endUid)}: $batchError");

              // Try individual UIDs if batch fails
              for (int uid = i; uid <= math.min(i + batchSize - 1, endUid); uid++) {
                try {
                  final singleSequence = MessageSequence();
                  singleSequence.add(uid);

                  final fetchResult = await imapClient.uidFetchMessages(singleSequence, 'ENVELOPE');
                  final messages = fetchResult.messages;

                  if (messages.isNotEmpty) {
                    allMessages.addAll(messages);

                    // Update last fetched UID
                    for (var msg in messages) {
                      if (msg.uid != null && msg.uid! > lastUid) {
                        lastUid = msg.uid!;
                      }
                    }
                  }
                } catch (singleError) {
                  // Just log and continue
                  logger.d("Error fetching single UID $uid: $singleError");
                }
              }
            }

            // Small delay to avoid overwhelming the server
            await Future.delayed(const Duration(milliseconds: 100));
          }

          if (allMessages.isNotEmpty) {
            // Process the messages we were able to fetch
            _lastFetchedUids[mailbox] = lastUid;

            // Sort newest first
            allMessages.sort((a, b) {
              final dateA = a.decodeDate() ?? DateTime.now();
              final dateB = b.decodeDate() ?? DateTime.now();
              return dateB.compareTo(dateA);
            });

            // Save to local storage
            _storageController.saveMessagesInBackground(allMessages, mailbox);

            // Initialize email list if needed
            emails.putIfAbsent(mailbox, () => []);

            // Filter out duplicates
            final existingUids = emails[mailbox]!.map((m) => m.uid).toSet();
            final uniqueNewMessages = allMessages
                .where((m) => !existingUids.contains(m.uid))
                .toList();

            if (uniqueNewMessages.isNotEmpty) {
              // Insert at beginning (newest first)
              emails[mailbox]!.insertAll(0, uniqueNewMessages);

              // Re-sort all messages by date
              emails[mailbox]!.sort((a, b) {
                final dateA = a.decodeDate() ?? DateTime.now();
                final dateB = b.decodeDate() ?? DateTime.now();
                return dateB.compareTo(dateA);
              });

              // Notify about changes
              notifyEmailsChanged(mailbox, UpdateType.add, uniqueNewMessages);

              // Show notification
              Get.showSnackbar(
                GetSnackBar(
                  message: 'Received ${uniqueNewMessages.length} new email(s)',
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        } else {
          // Re-throw if it's not an invalid messageset error
          throw e;
        }
      }

      // Check for new mail in background for all folders, not just inbox
      _safeCheckForNewMail(false);

      updateMailboxUnreadCount(mailbox);

      if (Get.isRegistered<ContactController>()) {
        await Get.find<ContactController>().storeContactMails(emails[mailbox]!);
      }
    } catch (e) {
      logger.e("Error fetching new emails: $e");
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error refreshing emails: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      // Try to load from local storage as fallback
      final localMessages = await _storageController.loadMessagesFromStorage(mailbox);
      if (localMessages != null && localMessages.isNotEmpty && (emails[mailbox]?.isEmpty ?? true)) {
        emails[mailbox] = localMessages;
        notifyEmailsChanged(mailbox, UpdateType.replace, localMessages);
      }
    } finally {
      isBoxBusy(false);
      isRefreshing(false);

      // Update UI state if controller is available
      _uiStateController?.setMailboxLoading(mailbox, false);
      _uiStateController?.setRefreshing(false);

      // Release the lock
      _releaseMailboxLock(mailbox);
    }
  }

  /// Create an optimized message sequence with ranges instead of individual UIDs
  /// with improved validation and error handling
  MessageSequence createOptimizedSequence(int startUid, int endUid) {
    final sequence = MessageSequence();

    // Validate input
    if (startUid <= 0 || endUid <= 0 || startUid > endUid) {
      logger.e("Invalid UID range: $startUid-$endUid");
      return sequence; // Return empty sequence
    }

    // Add as a range instead of individual UIDs
    sequence.addRange(startUid, endUid);

    return sequence;
  }

  /// Fetch mailbox contents with optimized batching and improved error handling
  /// Modified to load all emails in batches instead of just the most recent ones
  Future<void> fetchMailbox(Mailbox mailbox) async {
    // Acquire lock to prevent concurrent operations on the same mailbox
    await _acquireMailboxLock(mailbox);

    isBoxBusy(true);
    isRefreshing(true);

    // Update UI state if controller is available
    _uiStateController?.setMailboxLoading(mailbox, true);
    _uiStateController?.setRefreshing(true);

    try {
      if (!await ensureConnection()) {
        isBoxBusy(false);
        isRefreshing(false);
        _uiStateController?.setMailboxLoading(mailbox, false);
        _uiStateController?.setRefreshing(false);
        return;
      }

      // Ensure the mailbox is selected before proceeding
      try {
        await mailService.client.selectMailbox(mailbox);
      } catch (e) {
        logger.e("Error selecting mailbox: $e");
        // Try to reconnect and select again
        if (await ensureConnection()) {
          await mailService.client.selectMailbox(mailbox);
        } else {
          throw Exception("Failed to select mailbox after reconnection attempt");
        }
      }

      int totalMessages = mailbox.messagesExists;
      if (mailbox.uidNext != null && mailbox.isInbox) {
        await getStorage.write(
          BackgroundService.keyInboxLastUid,
          mailbox.uidNext,
        );
      }

      if (totalMessages == 0) {
        isBoxBusy(false);
        isRefreshing(false);
        _uiStateController?.setMailboxLoading(mailbox, false);
        _uiStateController?.setRefreshing(false);
        return;
      }

      if (emails[mailbox] == null) {
        emails[mailbox] = <MimeMessage>[];
      }

      // Only clear emails on first load, not on refresh
      final mailboxKey = mailbox.encodedPath;
      if (!(_initialLoadDone[mailboxKey] ?? false)) {
        _currentPage[mailbox] = 1;
        emails[mailbox]!.clear();

        // Notify about changes
        notifyEmailsChanged(mailbox, UpdateType.replace, []);
      }

      // Initialize storage for this mailbox if needed
      await _storageController.initializeMailboxStorage(mailbox);

      // MODIFIED: Load all emails in batches instead of just the first page
      int batchSize = 50; // Larger batch size for efficiency
      List<MimeMessage> allMessages = [];

      // Show initial loading message
      Get.showSnackbar(
        GetSnackBar(
          message: 'Loading all emails from ${mailbox.name}...',
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );

      // Load emails in batches from newest to oldest
      for (int i = 0; i < totalMessages; i += batchSize) {
        // Update progress every few batches
        if (i > 0 && i % (batchSize * 3) == 0) {
          Get.showSnackbar(
            GetSnackBar(
              message: 'Loading emails: ${math.min(i + batchSize, totalMessages)}/$totalMessages',
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 1),
            ),
          );
        }

        int fetchCount = math.min(batchSize, totalMessages - i);
        int fetchStart = totalMessages - i - fetchCount + 1;
        int fetchEnd = totalMessages - i;

        // Ensure valid range
        if (fetchStart < 1) fetchStart = 1;
        if (fetchEnd < 1) fetchEnd = 1;
        if (fetchStart > fetchEnd) {
          int temp = fetchStart;
          fetchStart = fetchEnd;
          fetchEnd = temp;
        }

        logger.d("Fetching messages from $fetchStart to $fetchEnd (total: ${fetchEnd - fetchStart + 1})");

        final sequence = MessageSequence.fromRange(fetchStart, fetchEnd);
        final messages = await fetchMessageBatch(sequence);

        if (messages.isNotEmpty) {
          allMessages.addAll(messages);

          // Save to local storage in smaller batches to avoid overwhelming the database
          _storageController.saveMessagesInBackground(messages, mailbox);

          // Periodically update the UI to show progress
          if (i == 0 || allMessages.length >= 100 || i + batchSize >= totalMessages) {
            // Sort by date (newest first)
            allMessages.sort((a, b) {
              final dateA = a.decodeDate() ?? DateTime.now();
              final dateB = b.decodeDate() ?? DateTime.now();
              return dateB.compareTo(dateA);
            });

            // Update emails list with what we have so far
            emails[mailbox] = List.from(allMessages);

            // Notify about changes
            notifyEmailsChanged(mailbox, UpdateType.replace, allMessages);
          }
        }

        // Add a small delay to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Process all fetched messages
      if (allMessages.isNotEmpty) {
        // Final sort by date (newest first)
        allMessages.sort((a, b) {
          final dateA = a.decodeDate() ?? DateTime.now();
          final dateB = b.decodeDate() ?? DateTime.now();
          return dateB.compareTo(dateA);
        });

        // Update last fetched UID
        int lastUid = 0;
        for (var msg in allMessages) {
          if (msg.uid != null && msg.uid! > lastUid) {
            lastUid = msg.uid!;
          }
        }
        _lastFetchedUids[mailbox] = lastUid;

        // Final update to emails list
        emails[mailbox] = allMessages;

        // Final notification about changes
        notifyEmailsChanged(mailbox, UpdateType.replace, allMessages);

        // Show completion message
        Get.showSnackbar(
          GetSnackBar(
            message: 'Loaded ${allMessages.length} emails from ${mailbox.name}',
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Update unread count
      updateMailboxUnreadCount(mailbox);

      // Store contact emails
      if (Get.isRegistered<ContactController>()) {
        await Get.find<ContactController>().storeContactMails(emails[mailbox]!);
      }
    } catch (e) {
      logger.e("Error fetching mailbox: $e");

      // Show error to user
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error loading mailbox: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      // Try to load from local storage as fallback
      final localMessages = await _storageController.loadMessagesFromStorage(mailbox);
      if (localMessages != null && localMessages.isNotEmpty) {
        emails[mailbox] = localMessages;
        notifyEmailsChanged(mailbox, UpdateType.replace, localMessages);
      }
    } finally {
      isBoxBusy(false);
      isRefreshing(false);

      // Update UI state if controller is available
      _uiStateController?.setMailboxLoading(mailbox, false);
      _uiStateController?.setRefreshing(false);

      // Release the lock
      _releaseMailboxLock(mailbox);
    }
  }

  /// Fetch a batch of messages with retry logic
  Future<List<MimeMessage>> fetchMessageBatch(MessageSequence sequence) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final imapClient = mailService.client.lowLevelIncomingMailClient as ImapClient;

        // ENVELOPE fetches basic headers like subject, from, date, etc.
        final result = await imapClient.fetchMessages(sequence, 'ENVELOPE');
        return result.messages;
      } catch (e) {
        final isLastAttempt = attempt == _maxRetries - 1;
        logger.e("Error fetching message batch (attempt ${attempt + 1}/$_maxRetries): $e");

        if (isLastAttempt) {
          rethrow;
        } else {
          final delay = _retryDelay * math.pow(2, attempt).toInt();
          logger.d("Retrying in ${delay.inSeconds} seconds...");
          await Future.delayed(delay);
        }
      }
    }

    return [];
  }

  /// Update unread count for a mailbox
  Future<void> updateMailboxUnreadCount(Mailbox mailbox) async {
    try {
      if (Get.isRegistered<MailCountController>()) {
        final countController = Get.find<MailCountController>();
        await countController.updateUnreadCount(mailbox);
      }
    } catch (e) {
      logger.e("Error updating unread count: $e");
    }
  }

  /// Notify about changes to emails with debouncing to prevent UI flicker
  void notifyEmailsChanged(Mailbox mailbox, UpdateType type, List<MimeMessage> messages, {List<int>? removedUids}) {
    // Cancel any pending debounce timer
    _debounceTimer?.cancel();

    // Debounce UI updates to prevent flicker
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      // Add update to subject
      _emailsSubject.add(EmailUpdate(
        mailbox: mailbox,
        type: type,
        messages: messages,
        removedUids: removedUids,
      ));
    });
  }

  /// Handle incoming mail notification
  Future<void> handleIncomingMail(MimeMessage message) async {
    try {
      final mailbox = mailService.client.selectedMailbox;
      if (mailbox == null) {
        logger.e("No mailbox selected for handleIncomingMail");
        return;
      }

      // Initialize email list if needed
      emails.putIfAbsent(mailbox, () => []);

      // Check if message already exists
      final existingIndex = emails[mailbox]!.indexWhere((m) => m.uid == message.uid);

      if (existingIndex >= 0) {
        // Update existing message
        emails[mailbox]![existingIndex] = message;
        notifyEmailsChanged(mailbox, UpdateType.update, [message]);
      } else {
        // Add new message
        emails[mailbox]!.insert(0, message);

        // Re-sort all messages by date
        emails[mailbox]!.sort((a, b) {
          final dateA = a.decodeDate() ?? DateTime.now();
          final dateB = b.decodeDate() ?? DateTime.now();
          return dateB.compareTo(dateA);
        });

        notifyEmailsChanged(mailbox, UpdateType.add, [message]);
      }

      // Save to local storage
      _storageController.saveMessagesInBackground([message], mailbox);

      // Update unread count
      updateMailboxUnreadCount(mailbox);

      // Store contact emails
      if (Get.isRegistered<ContactController>()) {
        await Get.find<ContactController>().storeContactMails([message]);
      }
    } catch (e) {
      logger.e("Error handling incoming mail: $e");
    }
  }

  /// Remove messages from a mailbox
  Future<void> removeMessages(List<MimeMessage> messages, Mailbox mailbox) async {
    try {
      if (emails[mailbox] == null) {
        return;
      }

      // Get UIDs to remove
      final uidsToRemove = messages.map((m) => m.uid).whereType<int>().toList();

      // Remove from emails list
      emails[mailbox]!.removeWhere((m) => m.uid != null && uidsToRemove.contains(m.uid));

      // Notify about changes
      notifyEmailsChanged(mailbox, UpdateType.remove, messages, removedUids: uidsToRemove);

      // Remove from local storage
      _storageController.deleteMessagesFromStorage(messages, mailbox);

      // Update unread count
      updateMailboxUnreadCount(mailbox);
    } catch (e) {
      logger.e("Error removing messages: $e");
    }
  }

  /// Check for new emails in all mailboxes
  Future<void> checkForNewEmails({bool isBackground = false}) async {
    try {
      if (!await ensureConnection()) {
        return;
      }

      // Get all mailboxes
      final mailboxes = await mailService.client.listMailboxes();

      // Check each mailbox for new emails
      for (final mailbox in mailboxes) {
        // Skip special mailboxes in background mode to save resources
        if (isBackground && !mailbox.isInbox && !mailbox.hasFlag(MailboxFlag.sent)) {
          continue;
        }

        try {
          await mailService.client.selectMailbox(mailbox);
          await fetchNewEmails(mailbox);
        } catch (e) {
          logger.e("Error checking mailbox ${mailbox.name}: $e");
          // Continue with next mailbox
        }
      }
    } catch (e) {
      logger.e("Error checking for new emails: $e");
    }
  }

  /// Safely check for new mail with error handling
  Future<void> _safeCheckForNewMail(bool isBackground) async {
    try {
      await checkForNewEmails(isBackground: isBackground);
    } catch (e) {
      logger.e("Error in _safeCheckForNewMail: $e");
    }
  }

  @override
  void onClose() {
    _emailsSubject.close();
    _connectionKeepAliveTimer?.cancel();
    _debounceTimer?.cancel();
    super.onClose();
  }
}
