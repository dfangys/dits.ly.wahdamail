import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'dart:ui';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wahda_bank/models/sqlite_database_helper.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/services/notifications_service.dart';
import 'package:workmanager/workmanager.dart';

/// Service responsible for handling email notifications using IMAP IDLE with SQLite support
///
/// This service implements real-time notifications for incoming emails
/// using IMAP IDLE in foreground and periodic checks in background.
class EmailNotificationService {
  static EmailNotificationService? _instance;
  static EmailNotificationService get instance {
    return _instance ??= EmailNotificationService._();
  }

  EmailNotificationService._();

  // Constants
  static const String backgroundTaskName = 'com.wahda_bank.emailCheck';
  static const Duration idleRefreshInterval = Duration(minutes: 28);
  static const Duration backgroundCheckInterval = Duration(minutes: 15);
  static const String portName = 'email_notification_port';
  static const String lastEmailCheckTimeKey = 'last_email_check_time';
  static const String lastSeenUidKey = 'last_seen_uid';

  // State variables
  bool _isInitialized = false;
  bool _isListening = false;
  Timer? _idleRefreshTimer;
  final List<StreamSubscription> _subscriptions = [];
  final GetStorage _storage = GetStorage();

  /// Initialize the email notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    await NotificationService.instance.setup();
    await GetStorage.init();

    // Initialize SQLite database
    await SQLiteDatabaseHelper.instance.database;

    // Register port for background to UI communication
    final receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(
        receivePort.sendPort,
        portName
    );

    receivePort.listen((message) {
      if (message is Map && message['type'] == 'new_email') {
        _handleNewEmailNotification(message);
      }
    });

    // Initialize Workmanager for background tasks
    if (Platform.isAndroid || Platform.isIOS) {
      await Workmanager().initialize(
        backgroundTaskCallback,
        isInDebugMode: kDebugMode,
      );
    }

    _isInitialized = true;
  }

  /// Start listening for new emails
  Future<void> startListening() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isListening) return;

    // Start IMAP IDLE in foreground
    await _startImapIdle();

    // Schedule background checks
    await _scheduleBackgroundChecks();

    _isListening = true;
  }

  /// Stop listening for new emails
  void stopListening() {
    _idleRefreshTimer?.cancel();

    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    _isListening = false;
  }

  /// Start IMAP IDLE for real-time notifications in foreground
  Future<void> _startImapIdle() async {
    final mailService = MailService.instance;

    // Ensure mail client is connected
    if (!mailService.isClientSet) {
      await mailService.init();
    }

    if (!mailService.client.isConnected) {
      await mailService.connect();
    }

    // Set up IDLE refresh timer to prevent timeout
    _idleRefreshTimer = Timer.periodic(idleRefreshInterval, (_) async {
      if (mailService.client.isConnected) {
        try {
          // Refresh IDLE connection to prevent timeout
          // Note: Using polling instead of direct IDLE control
          // as stopIdle() is not available in the current API
          await mailService.client.stopPolling();
          await mailService.client.startPolling();
        } catch (e) {
          if (kDebugMode) {
            print('Error refreshing IDLE connection: $e');
          }

          // Try to reconnect if there was an error
          try {
            await mailService.connect();
          } catch (e) {
            if (kDebugMode) {
              print('Failed to reconnect: $e');
            }
          }
        }
      } else {
        // Try to reconnect if disconnected
        try {
          await mailService.connect();
        } catch (e) {
          if (kDebugMode) {
            print('Failed to reconnect: $e');
          }
        }
      }
    });

    // Subscribe to mail events
    _subscribeToMailEvents(mailService);
  }

  /// Subscribe to mail client events for new message notifications
  void _subscribeToMailEvents(MailService mailService) {
    // Listen for new messages
    final loadSubscription = mailService.client.eventBus
        .on<MailLoadEvent>()
        .listen(_handleMailLoadEvent);

    // Listen for message updates
    final updateSubscription = mailService.client.eventBus
        .on<MailUpdateEvent>()
        .listen(_handleMailUpdateEvent);

    // Listen for reconnection events
    final reconnectSubscription = mailService.client.eventBus
        .on<MailConnectionReEstablishedEvent>()
        .listen(_handleReconnectionEvent);

    _subscriptions.addAll([
      loadSubscription,
      updateSubscription,
      reconnectSubscription,
    ]);
  }

  /// Handle new mail event
  void _handleMailLoadEvent(MailLoadEvent event) {
    final message = event.message;

    // Skip if message is already seen
    if (message.isSeen) return;

    // Process and show notification
    _processNewMessage(message);
  }

  /// Handle mail update event
  void _handleMailUpdateEvent(MailUpdateEvent event) {
    final message = event.message;

    // Skip if message is already seen
    if (message.isSeen) return;

    // Process and show notification
    _processNewMessage(message);
  }

  /// Handle reconnection event
  void _handleReconnectionEvent(MailConnectionReEstablishedEvent event) {
    // Check for new messages since last connection
    checkForNewMessages();
  }

  /// Process a new message and show notification
  void _processNewMessage(MimeMessage message) async {
    // Skip if not from inbox (customize this based on requirements)
    final mailbox = MailService.instance.client.selectedMailbox;
    if (mailbox == null || !mailbox.isInbox) return;

    // Extract message details
    final from = message.from != null && message.from!.isNotEmpty
        ? message.from!.first.personalName ?? message.from!.first.email
        : 'Unknown Sender';

    final subject = message.decodeSubject() ?? 'No Subject';

    // Get message preview (first 150 chars of text content)
    String preview = '';
    try {
      final textPlain = message.decodeTextPlainPart();
      if (textPlain != null && textPlain.isNotEmpty) {
        preview = textPlain.trim();
        if (preview.length > 150) {
          preview = '${preview.substring(0, 147)}...';
        }
      }
    } catch (e) {
      // Ignore errors in preview generation
    }

    // Store the message UID as last seen
    final uid = message.uid;
    if (uid != null) {
      await _storage.write(lastSeenUidKey, uid);
    }

    // Save message to SQLite database
    try {
      // Get mailbox ID from database
      final db = await SQLiteDatabaseHelper.instance.database;
      final List<Map<String, dynamic>> mailboxResult = await db.query(
        SQLiteDatabaseHelper.tableMailboxes,
        columns: [SQLiteDatabaseHelper.columnId],
        where: '${SQLiteDatabaseHelper.columnPath} = ?',
        whereArgs: [mailbox.path],
      );

      if (mailboxResult.isNotEmpty) {
        final mailboxId = mailboxResult.first[SQLiteDatabaseHelper.columnId] as int;

        // Convert message to map for database
        final Map<String, dynamic> messageMap = {
          SQLiteDatabaseHelper.columnMailboxId: mailboxId,
          SQLiteDatabaseHelper.columnUid: message.uid,
          SQLiteDatabaseHelper.columnMessageId: message.getHeaderValue('message-id')?.replaceAll('<', '').replaceAll('>', ''),
          SQLiteDatabaseHelper.columnSubject: message.decodeSubject(),
          SQLiteDatabaseHelper.columnFrom: from,
          SQLiteDatabaseHelper.columnDate: message.decodeDate()?.millisecondsSinceEpoch,
          SQLiteDatabaseHelper.columnContent: message.decodeTextPlainPart(),
          SQLiteDatabaseHelper.columnHtmlContent: message.decodeTextHtmlPart(),
          SQLiteDatabaseHelper.columnIsSeen: SQLiteDatabaseHelper.boolToInt(message.isSeen),
          SQLiteDatabaseHelper.columnIsFlagged: SQLiteDatabaseHelper.boolToInt(message.isFlagged),
          SQLiteDatabaseHelper.columnIsDeleted: SQLiteDatabaseHelper.boolToInt(message.isDeleted),
          SQLiteDatabaseHelper.columnIsAnswered: SQLiteDatabaseHelper.boolToInt(message.isAnswered),
          SQLiteDatabaseHelper.columnIsDraft: SQLiteDatabaseHelper.boolToInt(false),
          SQLiteDatabaseHelper.columnIsRecent: SQLiteDatabaseHelper.boolToInt(false),
          SQLiteDatabaseHelper.columnHasAttachments: SQLiteDatabaseHelper.boolToInt(message.hasAttachments()),
          SQLiteDatabaseHelper.columnSize: message.size,
        };

        // Insert or update message in database
        await db.insert(
          SQLiteDatabaseHelper.tableEmails,
          messageMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving message to SQLite: $e');
      }
    }

    // Build notification body as subject + preview
    final bodyText = (preview.isNotEmpty) ? '$subject — $preview' : subject;

    // Show notification
    NotificationService.instance.showFlutterNotification(
      from,
      bodyText,
      {
        'action': 'view_message',
        'message_uid': uid?.toString() ?? '',
        'mailbox': mailbox.path,
        'preview': preview,
      },
      // Use message UID as notification ID to prevent duplicates
      uid?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Schedule periodic background checks for new emails
  Future<void> _scheduleBackgroundChecks() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    try {
      // Cancel any existing tasks
      await Workmanager().cancelByUniqueName(backgroundTaskName);

      // Schedule periodic task with error handling
      await Workmanager().registerPeriodicTask(
        backgroundTaskName,
        backgroundTaskName,
        frequency: backgroundCheckInterval,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 5),
      );
      
      if (kDebugMode) {
        print('Background email checks scheduled successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to schedule background email checks: $e');
        print('Background notifications will not be available, but foreground IDLE will still work');
      }
      // Don't throw the error - the app should continue working without background tasks
    }
  }

  /// Check for new messages since last check
  Future<void> checkForNewMessages() async {
    try {
      final mailService = MailService.instance;

      // Ensure mail client is connected
      if (!mailService.isClientSet) {
        await mailService.init();
      }

      if (!mailService.client.isConnected) {
        await mailService.connect();
      }

      // Select inbox
      final inbox = await mailService.client.selectInbox();

      // Get last seen UID
      final lastSeenUid = _storage.read<int>(lastSeenUidKey) ?? 0;

      // If no messages or no new messages, return
      if (inbox.messagesExists == 0 || inbox.uidNext == null || inbox.uidNext! <= lastSeenUid) {
        return;
      }

      // Create sequence for new messages
      final sequence = MessageSequence.fromRangeToLast(
        lastSeenUid + 1,
        isUidSequence: true,
      );

      // Fetch new messages
      final messages = await mailService.client.fetchMessageSequence(
        sequence,
        fetchPreference: FetchPreference.envelope,
      );

      // Process new messages
      for (final message in messages) {
        if (!message.isSeen) {
          _processNewMessage(message);
        }
      }

      // Update last check time
      await _storage.write(lastEmailCheckTimeKey, DateTime.now().toIso8601String());

      // Update last seen UID if we have new messages
      if (messages.isNotEmpty && inbox.uidNext != null) {
        await _storage.write(lastSeenUidKey, inbox.uidNext! - 1);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking for new messages: $e');
      }
    }
  }

  /// Handle new email notification from background task
  void _handleNewEmailNotification(Map message) {
    final from = message['from'] as String? ?? 'New Email';
    final subject = message['subject'] as String? ?? '';
    final preview = message['preview'] as String? ?? '';
    final uid = message['uid'] as int? ?? DateTime.now().millisecondsSinceEpoch;

    NotificationService.instance.showFlutterNotification(
      from,
      subject,
      {
        'action': 'view_message',
        'message_uid': uid.toString(),
        'mailbox': 'INBOX',
        'preview': preview,
      },
      uid,
    );
  }

  /// Request battery optimization exemption
  Future<void> requestBatteryOptimizationExemption() async {
    if (Platform.isAndroid) {
      try {
        // For now, just show a notification guiding the user
        NotificationService.instance.showFlutterNotification(
          'Battery Optimization',
          'Please disable battery optimization for this app to receive email notifications reliably.',
          {'action': 'battery_optimization'},
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error requesting battery optimization exemption: $e');
        }
      }
    }
  }
}

/// Background task callback for Workmanager
@pragma('vm:entry-point')
void backgroundTaskCallback() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  Workmanager().executeTask((taskName, inputData) async {
    try {
      // Initialize required services
      await GetStorage.init();
      await SQLiteDatabaseHelper.instance.database;
      await NotificationService.instance.setup();

      // Check for new emails
      await _backgroundCheckForNewEmails();

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Background task error: $e');
      }
      return false;
    }
  });
}

/// Check for new emails in background
Future<void> _backgroundCheckForNewEmails() async {
  try {
    final storage = GetStorage();

    // Get last seen UID
    final lastSeenUid = storage.read<int>(EmailNotificationService.lastSeenUidKey) ?? 0;

    // Initialize mail service
    await MailService.instance.init();
    if (!MailService.instance.client.isConnected) {
      await MailService.instance.connect();
    }

    // Select inbox
    final inbox = await MailService.instance.client.selectInbox();

    // If no messages or no new messages, return
    if (inbox.messagesExists == 0 || inbox.uidNext == null || inbox.uidNext! <= lastSeenUid) {
      return;
    }

    // Create sequence for new messages
    final sequence = MessageSequence.fromRangeToLast(
      lastSeenUid + 1,
      isUidSequence: true,
    );

    // Fetch new messages
    final messages = await MailService.instance.client.fetchMessageSequence(
      sequence,
      fetchPreference: FetchPreference.envelope,
    );

    // Process new messages
    for (final message in messages) {
      if (!message.isSeen) {
        // Extract message details
        final from = message.from != null && message.from!.isNotEmpty
            ? message.from!.first.personalName ?? message.from!.first.email
            : 'Unknown Sender';

        final subject = message.decodeSubject() ?? 'No Subject';

        // Get message preview
        String preview = '';
        try {
          final textPlain = message.decodeTextPlainPart();
          if (textPlain != null && textPlain.isNotEmpty) {
            preview = textPlain.trim();
            if (preview.length > 150) {
              preview = '${preview.substring(0, 147)}...';
            }
          }
        } catch (e) {
          // Ignore errors in preview generation
        }

        // Save message to SQLite database
        try {
          // Get mailbox ID from database
          final db = await SQLiteDatabaseHelper.instance.database;
          final List<Map<String, dynamic>> mailboxResult = await db.query(
            SQLiteDatabaseHelper.tableMailboxes,
            columns: [SQLiteDatabaseHelper.columnId],
            where: '${SQLiteDatabaseHelper.columnPath} = ?',
            whereArgs: [inbox.path],
          );

          if (mailboxResult.isNotEmpty) {
            final mailboxId = mailboxResult.first[SQLiteDatabaseHelper.columnId] as int;

            // Convert message to map for database
            final Map<String, dynamic> messageMap = {
              SQLiteDatabaseHelper.columnMailboxId: mailboxId,
              SQLiteDatabaseHelper.columnUid: message.uid,
              SQLiteDatabaseHelper.columnMessageId: message.getHeaderValue('message-id')?.replaceAll('<', '').replaceAll('>', ''),
              SQLiteDatabaseHelper.columnSubject: message.decodeSubject(),
              SQLiteDatabaseHelper.columnFrom: from,
              SQLiteDatabaseHelper.columnDate: message.decodeDate()?.millisecondsSinceEpoch,
              SQLiteDatabaseHelper.columnContent: message.decodeTextPlainPart(),
              SQLiteDatabaseHelper.columnHtmlContent: message.decodeTextHtmlPart(),
              SQLiteDatabaseHelper.columnIsSeen: SQLiteDatabaseHelper.boolToInt(message.isSeen),
              SQLiteDatabaseHelper.columnIsFlagged: SQLiteDatabaseHelper.boolToInt(message.isFlagged),
              SQLiteDatabaseHelper.columnIsDeleted: SQLiteDatabaseHelper.boolToInt(message.isDeleted),
              SQLiteDatabaseHelper.columnIsAnswered: SQLiteDatabaseHelper.boolToInt(message.isAnswered),
              SQLiteDatabaseHelper.columnIsDraft: SQLiteDatabaseHelper.boolToInt(false),
              SQLiteDatabaseHelper.columnIsRecent: SQLiteDatabaseHelper.boolToInt(false),
              SQLiteDatabaseHelper.columnHasAttachments: SQLiteDatabaseHelper.boolToInt(message.hasAttachments()),
              SQLiteDatabaseHelper.columnSize: message.size,
            };

            // Insert or update message in database
            await db.insert(
              SQLiteDatabaseHelper.tableEmails,
              messageMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error saving message to SQLite: $e');
          }
        }

        // Build notification body as subject + preview
        final bodyText = (preview.isNotEmpty) ? '$subject — $preview' : subject;

        // Show notification
        NotificationService.instance.showFlutterNotification(
          from,
          bodyText,
          {
            'action': 'view_message',
            'message_uid': message.uid?.toString() ?? '',
            'mailbox': inbox.path,
            'preview': preview,
          },
          // Use message UID as notification ID to prevent duplicates
          message.uid?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        );
      }
    }

    // Update last check time
    await storage.write(EmailNotificationService.lastEmailCheckTimeKey, DateTime.now().toIso8601String());

    // Update last seen UID if we have new messages
    if (messages.isNotEmpty && inbox.uidNext != null) {
      await storage.write(EmailNotificationService.lastSeenUidKey, inbox.uidNext! - 1);
    }

    // Try to send notification to UI if app is running
    final sendPort = IsolateNameServer.lookupPortByName(EmailNotificationService.portName);
    if (sendPort != null && messages.isNotEmpty) {
      for (final message in messages) {
        if (!message.isSeen) {
          sendPort.send({
            'type': 'new_email',
            'from': message.from != null && message.from!.isNotEmpty
                ? message.from!.first.personalName ?? message.from!.first.email
                : 'Unknown Sender',
            'subject': message.decodeSubject() ?? 'No Subject',
            'preview': message.decodeTextPlainPart()?.substring(0, 150) ?? '',
            'uid': message.uid?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error in background email check: $e');
    }
  }
}
