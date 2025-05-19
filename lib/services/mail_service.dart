import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/app/controllers/email_fetch_controller.dart';
import 'package:wahda_bank/app/controllers/email_operation_controller.dart';
import 'package:wahda_bank/app/controllers/mailbox_list_controller.dart';
import 'package:wahda_bank/services/email_notification_service.dart';
import 'package:wahda_bank/services/internet_service.dart';

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
  bool _isIdleActive = false;

  // Connection retry settings
  int _connectionRetries = 0;
  static const int _maxConnectionRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);

  Future<bool> init({String? mail, String? pass}) async {
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

    return isClientSet = setClientAndAccount(email, password);
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
      onBadCertificate: (x509Certificate) {
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

        // Start IMAP IDLE for real-time notifications
        await _startIdleMode();

        // Reset connection retries on successful connection
        _connectionRetries = 0;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Connection error: $e');
      }

      // Implement connection retry with backoff
      if (_connectionRetries < _maxConnectionRetries) {
        _connectionRetries++;
        await Future.delayed(_retryDelay * _connectionRetries);
        return connect(); // Retry connection
      }

      rethrow;
    }
    return client.isConnected;
  }

  Future<void> _startIdleMode() async {
    if (_isIdleActive || !client.isConnected) return;

    try {
      // Start email notification service for IDLE mode
      await EmailNotificationService.instance.startListening();
      _isIdleActive = true;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting IDLE mode: $e');
      }
    }
  }

  Future<void> stopIdleMode() async {
    if (!_isIdleActive) return;

    try {
      // Stop email notification service
      EmailNotificationService.instance.stopListening();
      _isIdleActive = false;
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping IDLE mode: $e');
      }
    }
  }

  late StreamSubscription<MailLoadEvent> _mailLoadEventSubscription;
  late StreamSubscription<MailVanishedEvent> _mailVanishedEventSubscription;
  late StreamSubscription<MailUpdateEvent> _mailUpdatedEventSubscription;
  late StreamSubscription<MailConnectionReEstablishedEvent>
  _mailReconnectedEventSubscription;

  void _subscribeEvents() {
    printInfo(info: 'Subscribing to events');
    _mailLoadEventSubscription =
        client.eventBus.on<MailLoadEvent>().listen((event) {
          if (event.mailClient == client) {
            printError(info: 'MailLoadEvent');
            if (Get.isRegistered<EmailFetchController>()) {
              Get.find<EmailFetchController>().handleIncomingMail(event.message);
            }
          }
        });
    _mailVanishedEventSubscription =
        client.eventBus.on<MailVanishedEvent>().listen((event) async {
          printError(info: "MailVanishedEvent");
          final sequence = event.sequence;
          if (sequence != null) {
            List<MimeMessage> msgs = await client.fetchMessageSequence(sequence);

            if (Get.isRegistered<EmailOperationController>()) {
              final controller = Get.find<EmailOperationController>();
              final mailbox = client.selectedMailbox;

              if (mailbox != null) {
                controller.vanishMails(msgs, mailbox);
              }
            }
          }
        });
    _mailUpdatedEventSubscription =
        client.eventBus.on<MailUpdateEvent>().listen((event) {
          if (event.mailClient == client) {
            printError(info: 'MailUpdateEvent');
            if (Get.isRegistered<EmailFetchController>()) {
              Get.find<EmailFetchController>().handleIncomingMail(event.message);
            }
          }
        });
    _mailReconnectedEventSubscription =
        client.eventBus.on<MailConnectionReEstablishedEvent>().listen((data) {
          if (data.mailClient == client) {
            data.mailClient.isConnected;

            // Restart IDLE mode on reconnection
            _startIdleMode();
          }
        });

    // Listen for connectivity changes to manage IDLE state
    InternetService.instance.init();

    isSubscribed = true;
  }

  void _unsubscribeEvents() {
    _mailLoadEventSubscription.cancel();
    _mailVanishedEventSubscription.cancel();
    _mailUpdatedEventSubscription.cancel();
    _mailReconnectedEventSubscription.cancel();
  }

  void dispose() {
    stopIdleMode();
    _unsubscribeEvents();
    client.disconnect();
  }
}
