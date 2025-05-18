import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/services/email_notification_service.dart';
import 'package:wahda_bank/services/notifications_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wahda_bank/models/mailbox_storage.dart';

class MailService {
  static MailService? _instance;
  static MailService get instance {
    return _instance ??= MailService._();
  }

  MailService._();

  // Getters
  late MailAccount account;
  final storage = GetStorage();
  late MailClient client;
  late Mailbox selectedBox;
  bool isClientSet = false;
  bool isSubscribed = false;

  // Enhanced cache management
  final Map<String, MailboxStorage> _mailboxStorages = {};
  final Map<String, MimeMessage> _messageCache = {};
  final Map<String, DateTime> _messageCacheTimestamps = {}; // Track when messages were cached
  final Duration _cacheDuration = const Duration(hours: 1); // Cache validity period

  Future<bool> init({String? mail, String? pass}) async {
    String? email = mail ?? storage.read('email');
    String? password = pass ?? storage.read('password');
    if (email == null || password == null) {
      throw "Please login first";
    }
    if (mail != null && pass != null) {
      await setAccount(mail, pass);
    }

    // Initialize Hive for caching
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(MessageStorageAdapter());
    }

    // Set up client and connect first
    isClientSet = setClientAndAccount(email, password);
    await connect(); // Make sure we're connected first

    // Then start notification service
    await EmailNotificationService.instance.connectAndListen();

    return isClientSet;
  }

  Future<bool> setAccount(String email, String pass) async {
    await storage.write('email', email);
    await storage.write('password', pass);
    return true;
  }

  bool setClientAndAccount(String email, String password) {
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
    client = MailClient(
      account,
      isLogEnabled: true,
      onBadCertificate: (X509Certificate) {
        return true;
      },
    );
    isClientSet = true;
    return isClientSet;
  }

  Future<bool> connect() async {
    try {
      if (!client.isConnected) {
        await client.connect();
        await client.startPolling();
        if (isSubscribed == false) {
          _subscribeEvents();
        }
      }
    } catch (e) {
      // storage.erase();
      rethrow;
    }
    return client.isConnected;
  }

  // Use proper import for StreamSubscription
  late StreamSubscription _mailLoadEventSubscription;
  late StreamSubscription _mailVanishedEventSubscription;
  late StreamSubscription _mailUpdatedEventSubscription;
  late StreamSubscription _mailReconnectedEventSubscription;

  void _subscribeEvents() {
    printInfo(info: 'Subscribing to events');
    _mailLoadEventSubscription =
        client.eventBus.on<MailLoadEvent>().listen((event) {
          if (event.mailClient == client) {
            printError(info: 'MailLoadEvent');
            if (Get.isRegistered<MailBoxController>()) {
              Get.find<MailBoxController>().handleIncomingMail(event.message);
            }

            // Cache the new message
            _cacheMessage(event.message);

            // Show notification for new messages
            if (!event.message.isSeen) {
              _showNotification(event.message);
            }
          }
        });
    _mailVanishedEventSubscription =
        client.eventBus.on<MailVanishedEvent>().listen((event) async {
          printError(info: "MailVanishedEvent");
          final sequence = event.sequence;
          if (sequence != null) {
            List<MimeMessage> msgs = await client.fetchMessageSequence(
              sequence,
            );
            if (Get.isRegistered<MailBoxController>()) {
              Get.find<MailBoxController>().vanishMails(msgs);
            }
          }
        });
    _mailUpdatedEventSubscription =
        client.eventBus.on<MailUpdateEvent>().listen((event) {
          if (event.mailClient == client) {
            printError(info: 'MailUpdateEvent');
            if (Get.isRegistered<MailBoxController>()) {
              Get.find<MailBoxController>().handleIncomingMail(event.message);
            }

            // Update the cached message
            _cacheMessage(event.message);

            // Show notification for new messages
            if (!event.message.isSeen) {
              _showNotification(event.message);
            }
          }
        });
    _mailReconnectedEventSubscription =
        client.eventBus.on<MailConnectionReEstablishedEvent>().listen((data) {
          if (data.mailClient == client) {
            data.mailClient.isConnected;
          }
        });
    isSubscribed = true;
  }

  // Show notification for new messages
  void _showNotification(MimeMessage message) {
    if (kDebugMode) {
      print('📨 Showing notification for new message:');
      print('From: ${message.from}');
      print('Subject: ${message.decodeSubject()}');
    }

    // Show notification directly from mail service
    NotificationService.instance.showFlutterNotification(
      message.from?[0].email ?? 'Unknown Sender',
      message.decodeSubject() ?? 'New Mail',
      {'action': 'inbox', 'message': message.decodeSubject() ?? ''},
    );
  }

  void _unsubscribeEvents() {
    _mailLoadEventSubscription.cancel();
    _mailVanishedEventSubscription.cancel();
    _mailUpdatedEventSubscription.cancel();
    _mailReconnectedEventSubscription.cancel();
  }

  // Get or create a storage for the specified mailbox
  Future<MailboxStorage> _getMailboxStorage(Mailbox mailbox) async {
    final key = '${account.email}_${mailbox.path}';
    if (!_mailboxStorages.containsKey(key)) {
      final storage = MailboxStorage(
        mailAccount: account,
        mailbox: mailbox,
      );
      await storage.init();
      _mailboxStorages[key] = storage;
    }
    return _mailboxStorages[key]!;
  }

  // Enhanced cache a message with timestamp
  Future<void> _cacheMessage(MimeMessage message) async {
    try {
      // Add to in-memory cache with timestamp
      final cacheKey = _getCacheKey(message);
      _messageCache[cacheKey] = message;
      _messageCacheTimestamps[cacheKey] = DateTime.now();

      if (kDebugMode) {
        print('Message cached with key: $cacheKey');
      }

      // Find the mailbox
      final mailboxes = await client.listMailboxes();
      final mailbox = mailboxes.firstWhere(
            (box) => box.path == message.mimeData?.toString().split(' ').last,
        orElse: () => selectedBox,
      );

      // Save to persistent storage
      final storage = await _getMailboxStorage(mailbox);
      await storage.saveMessage(message);
    } catch (e) {
      if (kDebugMode) {
        print('Error caching message: $e');
      }
    }
  }

  // Enhanced get a message from cache or fetch from server with improved caching
  Future<MimeMessage> getMessageWithCaching(MimeMessage message) async {
    final cacheKey = _getCacheKey(message);

    // Check if message is in cache and still valid
    if (_messageCache.containsKey(cacheKey)) {
      final cachedTimestamp = _messageCacheTimestamps[cacheKey];
      final now = DateTime.now();

      // If cache is still valid, use it
      if (cachedTimestamp != null &&
          now.difference(cachedTimestamp) < _cacheDuration) {
        if (kDebugMode) {
          print('Using cached message: $cacheKey');
        }
        return _messageCache[cacheKey]!;
      }

      if (kDebugMode) {
        print('Cache expired for: $cacheKey');
      }
    }

    try {
      // Check persistent storage
      final mailboxes = await client.listMailboxes();
      final mailbox = mailboxes.firstWhere(
            (box) => box.path == message.mimeData?.toString().split(' ').last,
        orElse: () => selectedBox,
      );

      final storage = await _getMailboxStorage(mailbox);
      final cachedMessage = await storage.getMessage(message.sequenceId!);

      if (cachedMessage != null) {
        // Add to in-memory cache with new timestamp
        _messageCache[cacheKey] = cachedMessage;
        _messageCacheTimestamps[cacheKey] = DateTime.now();

        if (kDebugMode) {
          print('Retrieved from persistent storage: $cacheKey');
        }

        return cachedMessage;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving cached message: $e');
      }
    }

    // If not in cache, fetch from server and cache
    if (kDebugMode) {
      print('Fetching message from server: $cacheKey');
    }

    final fetchedMessage = await client.fetchMessageContents(message);
    await _cacheMessage(fetchedMessage);
    return fetchedMessage;
  }

  // Generate a cache key for a message
  String _getCacheKey(MimeMessage message) {
    if (message.uid != null) {
      return 'uid_${message.uid}';
    } else if (message.guid != null) {
      return 'guid_${message.guid}';
    } else if (message.sequenceId != null) {
      return 'seq_${message.sequenceId}';
    } else {
      return 'msg_${message.hashCode}';
    }
  }

  // Clear all caches
  Future<void> clearCache() async {
    _messageCache.clear();
    _messageCacheTimestamps.clear();
    for (final storage in _mailboxStorages.values) {
      await storage.clear();
    }
    _mailboxStorages.clear();
  }

  void dispose() {
    _unsubscribeEvents();
    client.disconnect();
  }
}
