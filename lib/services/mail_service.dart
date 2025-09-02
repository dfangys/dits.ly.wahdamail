import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/services/email_notification_service.dart';
import 'package:wahda_bank/services/internet_service.dart';
import 'package:wahda_bank/services/realtime_update_service.dart';
import 'package:wahda_bank/services/optimized_idle_service.dart';
import 'package:wahda_bank/services/connection_lease.dart';

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

  // Foreground heartbeat and connection state
  Completer<bool>? _connectingCompleter;
  DateTime? _ipLimitCooldownUntil;

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
      isLogEnabled: kDebugMode,
      onBadCertificate: (x509Certificate) {
        return true;
      },
    );
    isClientSet = true;
    return isClientSet;
  }

  Future<bool> connect() async {
    // If a cooldown is active due to IP limit, avoid hammering the server
    if (_ipLimitCooldownUntil != null &&
        DateTime.now().isBefore(_ipLimitCooldownUntil!)) {
      if (kDebugMode) {
        final secs =
            _ipLimitCooldownUntil!.difference(DateTime.now()).inSeconds;
        print(
          'Connection cooldown active due to IP limit. Retrying in ~${secs}s',
        );
      }
      return false;
    }

    // Coalesce concurrent connect() calls so only one connection attempt runs
    if (_connectingCompleter != null) {
      return _connectingCompleter!.future;
    }
    _connectingCompleter = Completer<bool>();

    try {
      if (!client.isConnected) {
        await client.connect();
        // Do not start polling here; a single service will manage it to avoid race conditions
        if (isSubscribed == false) {
          _subscribeEvents();
        }

        // Ensure a mailbox is selected to prevent "No mailbox selected" errors on early fetches
        try {
          if (client.selectedMailbox == null) {
            await client.selectInbox();
          }
        } catch (_) {}

        // Start/refresh heartbeat so background tasks can defer their own connections
        try {
          ConnectionLease.instance.startHeartbeat(owner: 'foreground');
        } catch (_) {}

        // Reset connection retries on successful connection
        _connectionRetries = 0;
      }
      _connectingCompleter?.complete(client.isConnected);
      return client.isConnected;
    } catch (e) {
      if (kDebugMode) {
        print('Connection error: $e');
      }

      // Detect server-side IP/user limit and set a cooldown to avoid rapid retries
      try {
        final msg = e.toString();
        if (msg.contains(
              'Maximum number of connections from user+IP exceeded',
            ) ||
            msg.contains('mail_max_userip_connections')) {
          // Back off for 90 seconds; adjust as needed for server policy
          _ipLimitCooldownUntil = DateTime.now().add(
            const Duration(seconds: 90),
          );
          if (kDebugMode) {
            print(
              'IP limit detected; cooling down until ${_ipLimitCooldownUntil!.toIso8601String()}',
            );
          }
        }
      } catch (_) {}

      // Implement connection retry with backoff
      if (_connectionRetries < _maxConnectionRetries) {
        _connectionRetries++;
        await Future.delayed(_retryDelay * _connectionRetries);
        try {
          final ok = await connect(); // Retry connection (respects cooldown)
          _connectingCompleter?.complete(ok);
          return ok;
        } catch (err) {
          _connectingCompleter?.completeError(err);
          rethrow;
        }
      }

      _connectingCompleter?.completeError(e);
      rethrow;
    } finally {
      // Allow future connect attempts; keep cooldown if set
      _connectingCompleter = null;
    }
  }

  Future<void> startIdleMode() async {
    if (_isIdleActive || !client.isConnected) return;

    try {
      // Ensure a mailbox is selected before starting IDLE
      if (client.selectedMailbox == null) {
        if (kDebugMode) {
          print('Cannot start IDLE mode: no mailbox selected');
        }
        return;
      }

      // Prefer the optimized IDLE service as the single owner of the IDLE lifecycle
      final idle = OptimizedIdleService.instance;
      if (idle.isRunning || idle.isIdleActive) {
        if (kDebugMode) {
          print('Skipping legacy IDLE: optimized IDLE is already active');
        }
        _isIdleActive = true;
        return;
      }

      await idle.startOptimizedIdle();
      _isIdleActive = true;
      if (kDebugMode) {
        print(
          'IDLE mode started via OptimizedIdleService for mailbox: ${client.selectedMailbox?.name}',
        );
      }
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
    _mailLoadEventSubscription = client.eventBus.on<MailLoadEvent>().listen(
      (event) {
        try {
          if (event.mailClient == client) {
            if (kDebugMode) {
              print(
                '📧 MailLoadEvent received for: ${event.message.decodeSubject()}',
              );
            }
            // Forward to RealtimeUpdateService as the single source of truth
            Future.microtask(() async {
              try {
                await RealtimeUpdateService.instance.notifyNewMessages([
                  event.message,
                ], mailbox: client.selectedMailbox);
              } catch (e) {
                if (kDebugMode) {
                  print('📧 Error forwarding to RealtimeUpdateService: $e');
                }
              }
            });
          }
        } catch (e) {
          if (kDebugMode) {
            print('📧 Error processing MailLoadEvent: $e');
          }
          // Don't rethrow - just log the error to prevent stream crashes
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('📧 MailLoadEvent stream error: $error');
        }
      },
    );
    _mailVanishedEventSubscription = client.eventBus
        .on<MailVanishedEvent>()
        .listen((event) async {
          if (kDebugMode) {
            print('📧 MailVanishedEvent');
          }
          final sequence = event.sequence;
          if (sequence != null) {
            final msgs = await client.fetchMessageSequence(sequence);
            for (final m in msgs) {
              try {
                await RealtimeUpdateService.instance.deleteMessage(m);
              } catch (e) {
                if (kDebugMode) {
                  print(
                    '📧 Error forwarding vanish to RealtimeUpdateService: $e',
                  );
                }
              }
            }
          }
        });
    _mailUpdatedEventSubscription = client.eventBus.on<MailUpdateEvent>().listen((
      event,
    ) {
      if (event.mailClient == client) {
        if (kDebugMode) {
          print('📧 MailUpdateEvent');
        }
        // Forward to RealtimeUpdateService; it will de-duplicate and update state
        Future.microtask(() async {
          try {
            await RealtimeUpdateService.instance.notifyNewMessages([
              event.message,
            ], mailbox: client.selectedMailbox);
          } catch (e) {
            if (kDebugMode) {
              print('📧 Error forwarding update to RealtimeUpdateService: $e');
            }
          }
        });
      }
    });
    _mailReconnectedEventSubscription = client.eventBus
        .on<MailConnectionReEstablishedEvent>()
        .listen((data) {
          if (data.mailClient == client) {
            data.mailClient.isConnected;

            // Restart IDLE mode on reconnection (only if mailbox is selected)
            startIdleMode();
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
    try {
      ConnectionLease.instance.stopHeartbeat();
    } catch (_) {}
    client.disconnect();
  }
}
