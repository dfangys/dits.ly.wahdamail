import 'dart:async';
import 'dart:io';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/app/controllers/email_fetch_controller.dart';
import 'package:wahda_bank/app/controllers/email_operation_controller.dart';
import 'package:wahda_bank/app/controllers/background_task_controller.dart';
import 'package:wahda_bank/app/controllers/email_ui_state_controller.dart';
import 'package:wahda_bank/services/email_notification_service.dart';
import 'package:wahda_bank/services/internet_service.dart';
import 'package:synchronized/synchronized.dart';

/// Enhanced mail service with improved connection management and error handling
///
/// This service handles all mail client operations with proper connection
/// management, event handling, and error recovery.
class MailService {
  // Singleton instance
  static MailService? _instance;
  static MailService get instance {
    return _instance ??= MailService._();
  }

  // Private constructor
  MailService._();

  // Mail client properties
  late MailAccount account;
  final storage = GetStorage();
  MailClient? _client;

  // Safe client getter with reconnection logic for hot restart recovery
  MailClient get client {
    if (_client == null) {
      throw Exception('Mail client not initialized');
    }

    // Check if socket is initialized by trying to access a property that uses it
    try {
      // This will throw if socket is not initialized
      if (!_client!.isConnected && !_isConnecting.value) {
        // Schedule reconnection but don't block the getter
        Future.microtask(() => _handleHotRestartRecovery());
      }
    } catch (e) {
      // Socket initialization error detected, trigger recovery
      Future.microtask(() => _handleHotRestartRecovery());
    }

    return _client!;
  }

  // Check if client is properly initialized and connected
  bool get isClientReady {
    if (_client == null) return false;

    try {
      // This will throw if socket is not initialized
      return _client!.isConnected;
    } catch (e) {
      return false;
    }
  }

  Mailbox? selectedBox;

  // State tracking
  final RxBool _isConnected = false.obs;
  final RxBool _isConnecting = false.obs;
  final RxBool _isInitialized = false.obs;
  final RxBool _isIdleActive = false.obs;

  // Getters for reactive state
  bool get isConnected => _isConnected.value;
  bool get isConnecting => _isConnecting.value;
  bool get isInitialized => _isInitialized.value;
  bool get isIdleActive => _isIdleActive.value;
  bool get isClientSet => _isInitialized.value;

  // Event subscriptions
  StreamSubscription<MailLoadEvent>? _mailLoadEventSubscription;
  StreamSubscription<MailVanishedEvent>? _mailVanishedEventSubscription;
  StreamSubscription<MailUpdateEvent>? _mailUpdatedEventSubscription;
  StreamSubscription<MailConnectionReEstablishedEvent>? _mailReconnectedEventSubscription;
  StreamSubscription<MailConnectionLostEvent>? _mailConnectionLostEventSubscription;

  // Connection management
  final Lock _connectionLock = Lock();
  bool _isSubscribed = false;
  Timer? _keepAliveTimer;
  DateTime? _lastConnectionAttempt;
  String? _lastError;

  // Connection retry settings
  int _connectionRetries = 0;
  static const int _maxConnectionRetries = 5;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const Duration _maxRetryDelay = Duration(minutes: 2);
  static const Duration _keepAliveInterval = Duration(minutes: 5);


  Future<void> appendToSentFolder(Mailbox mailbox, MimeMessage message) async {
    if (!_isConnected.value) {
      final connected = await connect();
      if (!connected) return;
    }

    try {
      await client.appendMessage(message, mailbox);   // ← correct order
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error appending message to sent folder: $e');
    }
  }
  /// Initialize the mail service
  Future<bool> init({String? mail, String? pass}) async {
    if (_isInitialized.value) return true;

    try {
      String? email = mail ?? storage.read('email');
      String? password = pass ?? storage.read('password');

      if (email == null || password == null) {
        throw "Please login first";
      }

      if (mail != null && pass != null) {
        await setAccount(mail, pass);
      }

      // Initialize the email notification service
      await EmailNotificationService.instance.initialize();

      // Set up the mail client
      final result = setClientAndAccount(email, password);
      _isInitialized.value = result;

      // Start keep-alive timer
      _startKeepAliveTimer();

      return result;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error initializing mail service: $e');
      return false;
    }
  }

  /// Save account credentials
  Future<bool> setAccount(String email, String pass) async {
    try {
      await storage.write('email', email);
      await storage.write('password', pass);
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error saving account: $e');
      return false;
    }
  }

  /// Set up mail client and account
  bool setClientAndAccount(String email, String password) {
    try {
      // Create mail account with proper settings
      account = MailAccount.fromManualSettings(
        name: email,
        email: email,
        incomingHost: 'wbmail.wahdabank.com.ly',
        outgoingHost: 'wbmail.wahdabank.com.ly',
        password: password,
        incomingType: ServerType.imap,
        outgoingType: ServerType.smtp,
        incomingPort: 43245,
        outgoingPort: 43244,
        incomingSocketType: SocketType.ssl,
        outgoingSocketType: SocketType.plain,
        userName: email,
        outgoingClientDomain: 'wahdabank.com.ly',
      );

      // Create mail client with proper settings
      _client = MailClient(
        account,
        isLogEnabled: kDebugMode,
        logName: 'WahdaMailClient',
        onBadCertificate: (x509Certificate) {
          // Accept all certificates for now
          // TODO: Implement proper certificate validation
          return true;
        },
        // connectionTimeout: const Duration(seconds: 30),
        defaultWriteTimeout: const Duration(seconds: 30),
        defaultResponseTimeout: const Duration(seconds: 30),
      );

      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error setting up mail client: $e');
      return false;
    }
  }



  /// Handle hot restart recovery by recreating client and reconnecting
  Future<bool> _handleHotRestartRecovery() async {
    debugPrint('Hot restart recovery triggered - recreating mail client');

    // Reset connection state
    _isConnected.value = false;

    // Recreate client from stored credentials
    String? email = storage.read('email');
    String? password = storage.read('password');

    if (email == null || password == null) {
      debugPrint('Cannot recover from hot restart: missing credentials');
      return false;
    }

    // Recreate client
    setClientAndAccount(email, password);

    // Connect with the new client
    final success = await connect();

    // Trigger a full reload after reconnect
    if (success && Get.isRegistered<EmailFetchController>()) {
      debugPrint('Reconnection successful—reloading all mailboxes');
      final fetchController = Get.find<EmailFetchController>();
      fetchController.reloadAllMailboxes();
    }

    return success;
  }
  /// Connect to mail server with retry logic
  Future<bool> connect() async {
    if (_isConnecting.value) return false;

    return await _connectionLock.synchronized(() async {
      // 0) Ensure client instance exists
      if (_client == null) {
        final email = storage.read('email');
        final password = storage.read('password');
        if (email == null || password == null) {
          debugPrint('Cannot connect: missing credentials');
          return false;
        }
        setClientAndAccount(email, password);
      }

      // 0a) Quick already-connected check
      try {
        if (_isConnected.value && _client!.isConnected) {
          return true;
        }
      } catch (_) {}

      _isConnecting.value = true;
      _lastConnectionAttempt = DateTime.now();

      try {
        // 1) Internet check
        if (!await InternetService.instance.checkConnectivity()) {
          throw Exception('No internet connection');
        }

        // 2) Low-level connect & wait for isConnected
        await _client!.connect();
        var attempts = 0;
        while (!_client!.isConnected && attempts++ < 20) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
        if (!_client!.isConnected) {
          throw Exception('Timed out waiting for IMAP connection');
        }

        // — Ensure serverInfo is populated on the low-level IMAP client —
        final imap = _client!.lowLevelIncomingMailClient as ImapClient;
        if (imap.serverInfo == null) {
          debugPrint('serverInfo missing; forcing LOGIN to reinitialize');
          await _client!.connect();        // reconnect
          // await _client!.login();          // explicit login if needed
          // (after this, `imap.serverInfo` should be non-null)
        }

        // 3) Select INBOX
        await _client!.selectInbox();
        selectedBox = _client!.selectedMailbox;

        // 4) Start polling/IDLE
        await _client!.startPolling(const Duration(minutes: 5));
        if (Platform.isAndroid) {
          await _client!.startPolling();
        }

        // 5) Subscribe events if not yet done
        if (!_isSubscribed) _subscribeEvents();

        // 6) Kick off IDLE notifications
        await _startIdleMode();

        // 7) Success: reset and notify UI
        _connectionRetries = 0;
        _isConnected.value = true;
        _isConnecting.value = false;
        if (Get.isRegistered<EmailUiStateController>()) {
          Get.find<EmailUiStateController>().setConnectionState(true);
        }
        return true;
      } catch (e) {
        _lastError = e.toString();
        debugPrint('Connection error: $e');

        // notify UI offline
        if (Get.isRegistered<EmailUiStateController>()) {
          Get.find<EmailUiStateController>().setConnectionState(false);
        }

        // retry with exponential backoff
        if (_connectionRetries < _maxConnectionRetries) {
          _connectionRetries++;
          final delay = Duration(
            milliseconds: _initialRetryDelay.inMilliseconds *
                (1 << (_connectionRetries - 1)),
          );
          final actualDelay =
          delay.compareTo(_maxRetryDelay) > 0 ? _maxRetryDelay : delay;
          debugPrint(
              'Retrying connection in ${actualDelay.inSeconds}s (attempt $_connectionRetries)');
          _isConnecting.value = false;
          await Future.delayed(actualDelay);
          return connect();
        }

        // give up
        _isConnecting.value = false;
        return false;
      }
    });
  }

  /// Start keep-alive timer to maintain connection
  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(_keepAliveInterval, (timer) async {
      if (!_isConnected.value && !_isConnecting.value) {
        // Try to reconnect if not connected
        await connect();
      } else if (_isConnected.value) {
        // Send NOOP command to keep connection alive
        try {
          // await client.noop();
          await client.startPolling(const Duration(minutes: 5));

        } catch (e) {
          debugPrint('Error in keep-alive: $e');
          // Connection might be lost, try to reconnect
          _isConnected.value = false;
          await connect();
        }
      }
    });
  }

  /// Start IDLE mode for real-time updates
  Future<void> _startIdleMode() async {
    if (_isIdleActive.value || !client.isConnected) return;

    try {
      // Start email notification service for IDLE mode
      await EmailNotificationService.instance.startListening();
      _isIdleActive.value = true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error starting IDLE mode: $e');
    }
  }

  /// Stop IDLE mode
  Future<void> stopIdleMode() async {
    if (!_isIdleActive.value) return;

    try {
      // Stop email notification service
      EmailNotificationService.instance.stopListening();
      _isIdleActive.value = false;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error stopping IDLE mode: $e');
    }
  }

  /// Subscribe to mail client events
  void _subscribeEvents() {
    debugPrint('Subscribing to mail events');

    // New message event
    _mailLoadEventSubscription = client.eventBus.on<MailLoadEvent>().listen((event) {
      if (event.mailClient == client) {
        debugPrint('MailLoadEvent received');

        // Queue the operation in background task controller
        if (Get.isRegistered<BackgroundTaskController>() &&
            Get.isRegistered<EmailFetchController>()) {
          final taskController = Get.find<BackgroundTaskController>();
          final fetchController = Get.find<EmailFetchController>();

          taskController.queueOperation(() async {
            await fetchController.handleIncomingMail(event.message);
          }, priority: Priority.high);
        }
        // Fall back to direct call
        else if (Get.isRegistered<EmailFetchController>()) {
          Get.find<EmailFetchController>().handleIncomingMail(event.message);
        }
      }
    });

    // Message vanished event
    _mailVanishedEventSubscription = client.eventBus.on<MailVanishedEvent>().listen((event) async {
      debugPrint("MailVanishedEvent received");

      final sequence = event.sequence;
      if (sequence != null) {
        try {
          List<MimeMessage> msgs = await client.fetchMessageSequence(sequence);

          // Queue the operation in background task controller
          if (Get.isRegistered<BackgroundTaskController>() &&
              Get.isRegistered<EmailOperationController>()) {
            final taskController = Get.find<BackgroundTaskController>();
            final operationController = Get.find<EmailOperationController>();
            final mailbox = client.selectedMailbox;

            if (mailbox != null) {
              taskController.queueOperation(() async {
                await operationController.vanishMails(msgs, mailbox);
              }, priority: Priority.medium);
            }
          }
          // Fall back to direct call
          else if (Get.isRegistered<EmailOperationController>()) {
            final controller = Get.find<EmailOperationController>();
            final mailbox = client.selectedMailbox;

            if (mailbox != null) {
              await controller.vanishMails(msgs, mailbox);
            }
          }
        } catch (e) {
          debugPrint('Error processing vanished messages: $e');
        }
      }
    });

    // Message updated event
    _mailUpdatedEventSubscription = client.eventBus.on<MailUpdateEvent>().listen((event) {
      if (event.mailClient == client) {
        debugPrint('MailUpdateEvent received');

        // Queue the operation in background task controller
        if (Get.isRegistered<BackgroundTaskController>() &&
            Get.isRegistered<EmailFetchController>()) {
          final taskController = Get.find<BackgroundTaskController>();
          final fetchController = Get.find<EmailFetchController>();

          taskController.queueOperation(() async {
            await fetchController.handleIncomingMail(event.message);
          }, priority: Priority.high);
        }
        // Fall back to direct call
        else if (Get.isRegistered<EmailFetchController>()) {
          Get.find<EmailFetchController>().handleIncomingMail(event.message);

        }
      }
    });

    // Connection re-established event
    _mailReconnectedEventSubscription = client.eventBus.on<MailConnectionReEstablishedEvent>().listen((event) {
      if (event.mailClient == client) {
        debugPrint('MailConnectionReEstablishedEvent received');

        _isConnected.value = true;

        // Update UI state
        if (Get.isRegistered<EmailUiStateController>()) {
          Get.find<EmailUiStateController>().setConnectionState(true);
        }

        // Restart IDLE mode on reconnection
        _startIdleMode();
      }
    });

    // Connection lost event
    _mailConnectionLostEventSubscription = client.eventBus.on<MailConnectionLostEvent>().listen((event) {
      if (event.mailClient == client) {
        debugPrint('MailConnectionLostEvent received');

        _isConnected.value = false;

        // Update UI state
        if (Get.isRegistered<EmailUiStateController>()) {
          Get.find<EmailUiStateController>().setConnectionState(false);
        }

        // Try to reconnect
        connect();
      }
    });

    // Listen for connectivity changes to manage connection state
    InternetService.instance.init();
    InternetService.instance.connectivityStream.listen((hasConnectivity) {
      if (hasConnectivity && !_isConnected.value && !_isConnecting.value) {
        // Try to reconnect when internet becomes available
        connect();
      }
    });

    _isSubscribed = true;
  }

  /// Unsubscribe from mail client events
  void _unsubscribeEvents() {
    _mailLoadEventSubscription?.cancel();
    _mailVanishedEventSubscription?.cancel();
    _mailUpdatedEventSubscription?.cancel();
    _mailReconnectedEventSubscription?.cancel();
    _mailConnectionLostEventSubscription?.cancel();

    _mailLoadEventSubscription = null;
    _mailVanishedEventSubscription = null;
    _mailUpdatedEventSubscription = null;
    _mailReconnectedEventSubscription = null;
    _mailConnectionLostEventSubscription = null;

    _isSubscribed = false;
  }

  /// Select a mailbox
  Future<Mailbox?> selectMailbox(Mailbox mailbox) async {
    if (!_isConnected.value) {
      final connected = await connect();
      if (!connected) return null;
    }

    try {

      if (!client.isConnected) await connect();
      final selected = await client.selectMailbox(mailbox);
      selectedBox = selected;
      return selected;

    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error selecting mailbox: $e');
      return null;
    }
  }

  /// Get all mailboxes
  Future<List<Mailbox>> getMailboxes() async {
    if (!_isConnected.value) {
      final connected = await connect();
      if (!connected) return [];
    }

    try {
      return await client.listMailboxes();
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error getting mailboxes: $e');
      return [];
    }
  }

  /// Fetch messages from selected mailbox
  Future<List<MimeMessage>> fetchMessages({
    int count = 30,
    int page = 1,
    bool onlyUnread = false,
  })
  async {
    if (!_isConnected.value) {
      final connected = await connect();
      if (!connected) return [];
    }

    try {
      final mailbox = client.selectedMailbox;
      if (mailbox == null) {
        await client.selectInbox();
        selectedBox = client.selectedMailbox;
      }

      final messageCount = client.selectedMailbox?.messagesExists ?? 0;
      if (messageCount == 0) return [];

      final fetchEnd = messageCount - ((page - 1) * count);
      final fetchStart = fetchEnd - count + 1;

      if (fetchStart > fetchEnd) return [];

      final sequence = MessageSequence.fromRange(fetchStart, fetchEnd);
      final imapClient = client.lowLevelIncomingMailClient as ImapClient;
      final result = await imapClient.fetchMessages(sequence, 'FLAGS ENVELOPE');

      final messages = result.messages;

      if (onlyUnread) {
        // ✅ Filter locally by flags (no server-side filter)
        return messages.where((msg) => !(msg.flags?.contains(r'\Seen') ?? false)).toList();
      }

      return messages;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error fetching messages: $e');
      return [];
    }
  }

  /// Send a message
  Future<bool> sendMessage(MimeMessage message) async {
    if (!_isConnected.value) {
      final connected = await connect();
      if (!connected) return false;
    }

    try {
      await client.sendMessage(message);
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  /// Get last error
  String? getLastError() {
    return _lastError;
  }

  /// Reset error state
  void resetError() {
    _lastError = null;
  }

  /// Clean up resources
  void dispose() {
    _keepAliveTimer?.cancel();
    stopIdleMode();
    _unsubscribeEvents();

    // Disconnect client if connected
    if (client.isConnected) {
      client.disconnect();
    }

    _isConnected.value = false;
    _isConnecting.value = false;
    _isIdleActive.value = false;
  }
}
