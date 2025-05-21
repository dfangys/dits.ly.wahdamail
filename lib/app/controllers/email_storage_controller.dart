import 'dart:async';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:wahda_bank/models/sqlite_mailbox_storage.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'background_task_controller.dart';

/// Controller responsible for email storage operations
class EmailStorageController extends GetxController {
  final Logger logger = Logger();

  // Map of mailbox to storage instance
  final Map<Mailbox, SqliteMailboxStorage> mailboxStorage = {};

  // Central storage instance
  final SqliteMimeStorage _mimeStorage = SqliteMimeStorage.instance;

  // Background task controller for async operations
  late BackgroundTaskController _backgroundTaskController;

  // Mail service for account information
  late MailService _mailService;

  // Operation queue to prevent concurrent operations on the same mailbox
  final Map<String, Completer<void>> _operationQueue = {};

  // Cache invalidation tracking
  final Map<String, DateTime> _cacheLastInvalidated = {};

  // Maximum retry attempts for storage operations
  final int _maxRetries = 3;

  @override
  void onInit() {
    super.onInit();
    _backgroundTaskController = Get.find<BackgroundTaskController>();
    _mailService = MailService.instance;

    // Initialize the central storage
    _initializeCentralStorage();
  }

  /// Initialize the central storage with proper transaction handling
  Future<void> _initializeCentralStorage() async {
    try {
      await _mimeStorage.init();
      logger.d("Initialized central storage");
    } catch (e) {
      logger.e("Error initializing central storage: $e");
    }
  }

  /// Initialize storage for a specific mailbox
  Future<void> initializeMailboxStorage(Mailbox mailbox) async {
    if (mailboxStorage[mailbox] != null) {
      return; // Already initialized
    }

    try {
      final account = _mailService.client.account;
      if (account == null) {
        logger.e("Cannot initialize storage: No account available");
        return;
      }

      final storage = SqliteMailboxStorage(
        mailAccount: account,
        mailbox: mailbox,
      );

      await storage.init();
      mailboxStorage[mailbox] = storage;

      // Set initial cache invalidation timestamp
      _cacheLastInvalidated["${account.email}_${mailbox.encodedPath}"] = DateTime.now();

      logger.d("Initialized storage for mailbox: ${mailbox.name}");
    } catch (e) {
      logger.e("Error initializing mailbox storage: $e");
      // Show error to user
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error initializing storage: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Save messages to storage in background with improved error handling and retry
  Future<void> saveMessagesInBackground(List<MimeMessage> messages, Mailbox mailbox) async {
    if (messages.isEmpty) return;

    final account = _mailService.client.account;
    if (account == null) {
      logger.e("Cannot save messages: No account available");
      return;
    }

    // Create a unique key for this operation
    final operationKey = "${account.email}_${mailbox.encodedPath}_save";

    // Check if an operation is already in progress for this mailbox
    if (_operationQueue.containsKey(operationKey)) {
      // Wait for the current operation to complete
      await _operationQueue[operationKey]!.future;
    }

    // Create a new completer for this operation
    final completer = Completer<void>();
    _operationQueue[operationKey] = completer;

    try {
      // Queue the operation to the background task controller
      _backgroundTaskController.queueOperation(() async {
        try {
          // Initialize storage if needed
          if (mailboxStorage[mailbox] == null) {
            await initializeMailboxStorage(mailbox);
          }

          // Save messages with retry logic
          for (int attempt = 0; attempt < _maxRetries; attempt++) {
            try {
              await mailboxStorage[mailbox]?.saveMessageEnvelopes(messages);

              // Invalidate cache after saving
              _invalidateCache(account.email, mailbox.encodedPath);

              logger.d("Saved ${messages.length} messages to storage for ${mailbox.name}");
              break; // Success, exit retry loop
            } catch (e) {
              final isLastAttempt = attempt == _maxRetries - 1;
              logger.e("Error saving messages (attempt ${attempt + 1}/$_maxRetries): $e");

              if (isLastAttempt) {
                // Last attempt failed, throw the error
                throw e;
              } else {
                // Wait before retry
                await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
              }
            }
          }
        } catch (e) {
          logger.e("Failed to save messages after $_maxRetries attempts: $e");
          // Don't show error to user for background operations
        }
      });
    } catch (e) {
      logger.e("Error queuing save operation: $e");
    } finally {
      // Complete the operation
      completer.complete();
      _operationQueue.remove(operationKey);
    }
  }

  /// Save message envelopes directly to storage
  /// This method is used by email_operation_controller.dart
  Future<void> saveMessageEnvelopes(List<MimeMessage> messages, Mailbox mailbox) async {
    if (messages.isEmpty) return;

    try {
      final account = _mailService.client.account;
      if (account == null) {
        logger.e("Cannot save message envelopes: No account available");
        return;
      }

      // Initialize storage if needed
      if (mailboxStorage[mailbox] == null) {
        await initializeMailboxStorage(mailbox);
      }

      // Save messages with retry logic
      for (int attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          await mailboxStorage[mailbox]?.saveMessageEnvelopes(messages);

          // Invalidate cache after saving
          _invalidateCache(account.email, mailbox.encodedPath);

          logger.d("Saved ${messages.length} message envelopes to storage for ${mailbox.name}");
          break; // Success, exit retry loop
        } catch (e) {
          final isLastAttempt = attempt == _maxRetries - 1;
          logger.e("Error saving message envelopes (attempt ${attempt + 1}/$_maxRetries): $e");

          if (isLastAttempt) {
            // Last attempt failed, throw the error
            throw e;
          } else {
            // Wait before retry
            await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          }
        }
      }
    } catch (e) {
      logger.e("Failed to save message envelopes: $e");
      throw e; // Rethrow for caller to handle
    }
  }

  /// Load message envelopes from storage with improved error handling
  Future<List<MimeMessage>?> loadMessageEnvelopes(
      Mailbox mailbox,
      MessageSequence sequence,
      ) async {
    try {
      final account = _mailService.client.account;
      if (account == null) {
        logger.e("Cannot load message envelopes: No account available");
        return null;
      }

      // Initialize storage if needed
      if (mailboxStorage[mailbox] == null) {
        await initializeMailboxStorage(mailbox);
      }

      // Check if cache is valid
      final cacheKey = "${account.email}_${mailbox.encodedPath}";
      final lastInvalidated = _cacheLastInvalidated[cacheKey] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final storage = mailboxStorage[mailbox];

      if (storage != null) {
        // If cache was invalidated after storage's last refresh, force refresh
        if (lastInvalidated.isAfter(storage.lastRefreshed)) {
          await storage.refreshCache();
        }
      }

      // Load messages with retry logic
      for (int attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          final messages = await mailboxStorage[mailbox]?.loadMessageEnvelopes(sequence);
          logger.d("Loaded ${messages?.length ?? 0} messages from storage for ${mailbox.name}");
          return messages;
        } catch (e) {
          final isLastAttempt = attempt == _maxRetries - 1;
          logger.e("Error loading messages (attempt ${attempt + 1}/$_maxRetries): $e");

          if (isLastAttempt) {
            // Last attempt failed, throw the error
            throw e;
          } else {
            // Wait before retry
            await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          }
        }
      }
    } catch (e) {
      logger.e("Failed to load messages after $_maxRetries attempts: $e");
      // Show error to user
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error loading messages: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    return null;
  }

  /// Load all messages from storage for a mailbox with improved error handling
  Future<List<MimeMessage>?> loadMessagesFromStorage(Mailbox mailbox) async {
    try {
      final account = _mailService.client.account;
      if (account == null) {
        logger.e("Cannot load messages: No account available");
        return null;
      }

      // Initialize storage if needed
      if (mailboxStorage[mailbox] == null) {
        await initializeMailboxStorage(mailbox);
      }

      // Check if cache is valid
      final cacheKey = "${account.email}_${mailbox.encodedPath}";
      final lastInvalidated = _cacheLastInvalidated[cacheKey] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final storage = mailboxStorage[mailbox];

      if (storage != null) {
        // If cache was invalidated after storage's last refresh, force refresh
        if (lastInvalidated.isAfter(storage.lastRefreshed)) {
          await storage.refreshCache();
        }
      }

      // Create a sequence for all messages
      final sequence = MessageSequence();
      if (mailbox.messagesExists > 0) {
        sequence.addRange(1, mailbox.messagesExists);
      } else {
        // If we don't know how many messages exist, try to load all available
        // Fix: Don't use addAll with List.generate
        for (int i = 1; i <= 1000; i++) {
          sequence.add(i);
        }
      }

      return await loadMessageEnvelopes(mailbox, sequence);
    } catch (e) {
      logger.e("Error loading messages from storage: $e");
      return null;
    }
  }

  /// Fetch message contents with improved error handling and fallback
  Future<MimeMessage?> fetchMessageContents(
      MimeMessage message,
      Mailbox mailbox, {
        bool markAsSeen = false,
      }) async {
    try {
      final account = _mailService.client.account;
      if (account == null) {
        logger.e("Cannot fetch message contents: No account available");
        return null;
      }

      // Initialize storage if needed
      if (mailboxStorage[mailbox] == null) {
        await initializeMailboxStorage(mailbox);
      }

      // Try to load from storage first
      MimeMessage? fullMessage;
      try {
        fullMessage = await mailboxStorage[mailbox]?.fetchMessageContents(
          message,
          markAsSeen: markAsSeen,
        );

        // If we got a valid message with content, return it
        if (fullMessage != null && fullMessage.mimeData != null) {
          logger.d("Loaded message content from storage: UID ${message.uid}");
          return fullMessage;
        }
      } catch (e) {
        logger.w("Error loading message content from storage: $e");
        // Continue to try server fetch
      }

      // If storage fetch failed or returned incomplete message, try server
      logger.d("Trying to fetch message content from server: UID ${message.uid}");

      // Ensure we have a valid connection
      if (!_mailService.client.isConnected) {
        await _mailService.connect();
      }

      // Select the mailbox
      await _mailService.client.selectMailbox(mailbox);

      // Fetch the message with retry logic
      for (int attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          // Try to fetch by UID first if available
          if (message.uid != null) {
            final imapClient = _mailService.client.lowLevelIncomingMailClient as ImapClient;
            final sequence = MessageSequence();
            sequence.add(message.uid!);

            final fetchResult = await imapClient.uidFetchMessages(
              sequence,
              '(BODY.PEEK[])',
            );

            if (fetchResult.messages.isNotEmpty) {
              fullMessage = fetchResult.messages.first;

              // Mark as seen if requested
              if (markAsSeen && !fullMessage.isSeen) {
                fullMessage.isSeen = true;
                await mailboxStorage[mailbox]?.updateMessageFlags(fullMessage);

                // Invalidate cache after updating flags
                _invalidateCache(account.email, mailbox.encodedPath);
              }

              // Save to storage for future use
              await mailboxStorage[mailbox]?.saveMessageContents(fullMessage);

              logger.d("Successfully fetched message by UID: ${message.uid}");
              return fullMessage;
            }
          }

          // If UID fetch failed or UID is null, try by sequence ID
          if (message.sequenceId != null) {
            fullMessage = await _mailService.client.fetchMessageContents(message);

            // Mark as seen if requested
            if (markAsSeen && !fullMessage.isSeen) {
              fullMessage.isSeen = true;
              await mailboxStorage[mailbox]?.updateMessageFlags(fullMessage);

              // Invalidate cache after updating flags
              _invalidateCache(account.email, mailbox.encodedPath);
            }

            // Save to storage for future use
            await mailboxStorage[mailbox]?.saveMessageContents(fullMessage);

            logger.d("Successfully fetched message by sequence ID: ${message.sequenceId}");
            return fullMessage;
          }

          // If we got here, both methods failed
          // Fix: Use correct MailException constructor for enough_mail 2.1.6
          final mailClient = _mailService.client.lowLevelIncomingMailClient;
          throw MailException(mailClient as MailClient, "Unable to fetch message: no valid UID or sequence ID");
        } catch (e) {
          final isLastAttempt = attempt == _maxRetries - 1;
          logger.e("Error fetching message (attempt ${attempt + 1}/$_maxRetries): $e");

          if (isLastAttempt) {
            // Last attempt failed, throw the error
            // Fix: Use correct MailException constructor for enough_mail 2.1.6
            final mailClient = _mailService.client.lowLevelIncomingMailClient;
            throw MailException(
                mailClient as MailClient,
                "Unable to download message with UID ${message.uid} / sequence ID ${message.sequenceId}: ${e.toString()}"
            );
          } else {
            // Wait before retry
            await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          }
        }
      }
    } catch (e) {
      logger.e("Failed to fetch message contents: $e");

      // Show a more user-friendly error message
      final errorMessage = e.toString().contains("MailException")
          ? "Unable to load message. Please try again later."
          : "Error loading message: ${e.toString()}";

      Get.showSnackbar(
        GetSnackBar(
          message: errorMessage,
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    return null;
  }

  /// Update message flags with improved error handling
  Future<void> updateMessageFlags(MimeMessage message, Mailbox mailbox) async {
    try {
      final account = _mailService.client.account;
      if (account == null) {
        logger.e("Cannot update message flags: No account available");
        return;
      }

      // Initialize storage if needed
      if (mailboxStorage[mailbox] == null) {
        await initializeMailboxStorage(mailbox);
      }

      // Update flags in storage
      await mailboxStorage[mailbox]?.updateMessageFlags(message);

      // Invalidate cache after updating flags
      _invalidateCache(account.email, mailbox.encodedPath);

      logger.d("Updated message flags in storage: UID ${message.uid}");
    } catch (e) {
      logger.e("Error updating message flags: $e");
    }
  }

  /// Update message flags in batch with improved error handling
  Future<void> updateMessageFlagsBatch(List<MimeMessage> messages, Mailbox mailbox) async {
    if (messages.isEmpty) return;

    try {
      final account = _mailService.client.account;
      if (account == null) {
        logger.e("Cannot update message flags batch: No account available");
        return;
      }

      // Initialize storage if needed
      if (mailboxStorage[mailbox] == null) {
        await initializeMailboxStorage(mailbox);
      }

      // Update flags in storage one by one
      for (var message in messages) {
        await mailboxStorage[mailbox]?.updateMessageFlags(message);
      }

      // Invalidate cache after updating flags
      _invalidateCache(account.email, mailbox.encodedPath);

      // Update flags on server in batch
      _backgroundTaskController.queueOperation(() async {
        try {
          // Ensure we have a valid connection
          if (!_mailService.client.isConnected) {
            await _mailService.connect();
          }

          // Select the mailbox
          await _mailService.client.selectMailbox(mailbox);

          // For enough_mail 2.1.6, we need to use the correct method signature
          final imapClient = _mailService.client.lowLevelIncomingMailClient as ImapClient;

          // Create a sequence with all UIDs
          final sequence = MessageSequence();
          for (var message in messages) {
            if (message.uid != null) {
              sequence.add(message.uid!);
            }
          }

          if (!sequence.isEmpty) {
            // Determine flags to set
            List<String> flags = [];
            if (messages.first.isSeen) flags.add(r'\Seen');
            if (messages.first.isFlagged) flags.add(r'\Flagged');
            if (messages.first.isAnswered) flags.add(r'\Answered');
            // if (messages.first.isDraft) flags.add(r'\Draft');
            if (messages.first.flags?.contains(r'\Draft') ?? false) {
              flags.add(r'\Draft');
            }

            // Store flags
            await imapClient.uidStore(sequence, flags);

            logger.d("Updated flags for ${messages.length} messages on server");
          }
        } catch (e) {
          logger.e("Error updating message flags batch on server: $e");
          // Don't show error to user for background operations
        }
      });
    } catch (e) {
      logger.e("Error updating message flags batch: $e");
    }
  }

  /// Delete a message with improved error handling
  Future<void> deleteMessage(MimeMessage message, Mailbox mailbox) async {
    try {
      final account = _mailService.client.account;
      if (account == null) {
        logger.e("Cannot delete message: No account available");
        return;
      }

      // Initialize storage if needed
      if (mailboxStorage[mailbox] == null) {
        await initializeMailboxStorage(mailbox);
      }

      // Delete from storage
      await mailboxStorage[mailbox]?.deleteMessage(message);

      // Invalidate cache after deleting
      _invalidateCache(account.email, mailbox.encodedPath);

      logger.d("Deleted message from storage: UID ${message.uid}");
    } catch (e) {
      logger.e("Error deleting message: $e");
    }
  }

  /// Delete messages in batch with improved error handling
  Future<void> deleteMessagesBatch(List<MimeMessage> messages, Mailbox mailbox) async {
    if (messages.isEmpty) return;

    try {
      final account = _mailService.client.account;
      if (account == null) {
        logger.e("Cannot delete messages batch: No account available");
        return;
      }

      // Initialize storage if needed
      if (mailboxStorage[mailbox] == null) {
        await initializeMailboxStorage(mailbox);
      }

      // Delete from storage one by one
      for (var message in messages) {
        await mailboxStorage[mailbox]?.deleteMessage(message);
      }

      // Invalidate cache after deleting
      _invalidateCache(account.email, mailbox.encodedPath);

      logger.d("Deleted ${messages.length} messages from storage");
    } catch (e) {
      logger.e("Error deleting messages batch: $e");
    }
  }

  /// Clear all messages for a mailbox with improved error handling
  Future<void> clearMailbox(Mailbox mailbox) async {
    try {
      final account = _mailService.client.account;
      if (account == null) {
        logger.e("Cannot clear mailbox: No account available");
        return;
      }

      // Clear from storage
      await _mimeStorage.clearMailbox(
        account.email,
        mailbox.encodedPath,
      );

      // Invalidate cache after clearing
      _invalidateCache(account.email, mailbox.encodedPath);

      // Reinitialize storage
      mailboxStorage.remove(mailbox);
      await initializeMailboxStorage(mailbox);

      logger.d("Cleared mailbox: ${mailbox.name}");
    } catch (e) {
      logger.e("Error clearing mailbox: $e");

      // Show error to user
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error clearing mailbox: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Invalidate cache for a specific mailbox
  void _invalidateCache(String email, String mailboxPath) {
    final cacheKey = "${email}_${mailboxPath}";
    _cacheLastInvalidated[cacheKey] = DateTime.now();
    logger.d("Invalidated cache for mailbox: $mailboxPath");
  }

  /// Get mailbox storage instance for a specific mailbox
  SqliteMailboxStorage? getMailboxStorage(Mailbox mailbox) {
    return mailboxStorage[mailbox];
  }

  /// Force refresh cache for a specific mailbox
  Future<void> refreshMailboxCache(Mailbox mailbox) async {
    try {
      final account = _mailService.client.account;
      if (account == null) {
        logger.e("Cannot refresh mailbox cache: No account available");
        return;
      }

      // Initialize storage if needed
      if (mailboxStorage[mailbox] == null) {
        await initializeMailboxStorage(mailbox);
      }

      // Force refresh cache
      await mailboxStorage[mailbox]?.refreshCache();

      // Update invalidation timestamp
      _invalidateCache(account.email, mailbox.encodedPath);

      logger.d("Refreshed cache for mailbox: ${mailbox.name}");
    } catch (e) {
      logger.e("Error refreshing mailbox cache: $e");
    }
  }

  /// Save messages to storage
  Future<void> saveMessagesToStorage(List<MimeMessage> messages, Mailbox mailbox) async {
    await saveMessageEnvelopes(messages, mailbox);
  }

  /// Delete messages from storage
  Future<void> deleteMessagesFromStorage(List<MimeMessage> messages, Mailbox mailbox) async {
    await deleteMessagesBatch(messages, mailbox);
  }

  /// Mark message as seen
  Future<void> markMessageAsSeen(MimeMessage message, Mailbox mailbox) async {
    message.isSeen = true;
    await updateMessageFlags(message, mailbox);
  }

  /// Mark messages as seen
  Future<void> markMessagesAsSeen(List<MimeMessage> messages, Mailbox mailbox) async {
    for (var message in messages) {
      message.isSeen = true;
    }
    await updateMessageFlagsBatch(messages, mailbox);
  }

  @override
  void onClose() {
    // Dispose all storage instances
    for (var storage in mailboxStorage.values) {
      storage.dispose();
    }
    mailboxStorage.clear();
    super.onClose();
  }
}
