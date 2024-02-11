import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../models/indexed_cache.dart';

class MailService {
  static MailService? _instance;
  static MailService get instance {
    return _instance ??= MailService._();
  }

  MailService._();

  // Gettters
  late MailAccount account;
  final storage = GetStorage();
  late MailClient client;
  late Mailbox selectedBox;
  bool isClientSet = false;

  Future<bool> init({String? mail, String? pass}) async {
    String? email = mail ?? storage.read('email');
    String? password = pass ?? storage.read('password');
    if (email == null || password == null) {
      throw "Please login first";
    }
    if (mail != null && pass != null) {
      await setAccount(mail, pass);
    }
    return setClientAndAccount(email, password);
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
      incomingHost: 'schooloftechnologies.com',
      outgoingHost: 'schooloftechnologies.com',
      password: password,
      incomingType: ServerType.imap,
      outgoingType: ServerType.smtp,
      incomingPort: 993,
      outgoingPort: 465,
      incomingSocketType: SocketType.ssl,
      outgoingSocketType: SocketType.starttls,
      userName: email,
      outgoingClientDomain: 'schooloftechnologies.com',
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
        _subscribeEvents();
      }
    } catch (e) {
      rethrow;
    }
    return client.isConnected;
  }

  late StreamSubscription<MailLoadEvent> _mailLoadEventSubscription;
  late StreamSubscription<MailVanishedEvent> _mailVanishedEventSubscription;
  late StreamSubscription<MailUpdateEvent> _mailUpdatedEventSubscription;
  late StreamSubscription<MailConnectionReEstablishedEvent>
      _mailReconnectedEventSubscription;

  void _subscribeEvents() {
    _mailLoadEventSubscription =
        client.eventBus.on<MailLoadEvent>().listen((event) {
      if (event.mailClient == client) {
        printError(info: 'MailLoadEvent');
        // onMessageArrived(event.message);
      }
    });
    _mailVanishedEventSubscription =
        client.eventBus.on<MailVanishedEvent>().listen((event) {
      final sequence = event.sequence;
      if (sequence != null && event.mailClient == client) {
        // onMessagesVanished(sequence);
      }
    });
    _mailUpdatedEventSubscription =
        client.eventBus.on<MailUpdateEvent>().listen((event) {
      if (event.mailClient == client) {
        // onMessageFlagsUpdated(event.message);
        printError(info: 'MailUpdateEvent');
      }
    });
    _mailReconnectedEventSubscription =
        client.eventBus.on<MailConnectionReEstablishedEvent>().listen((data) {
      if (data.mailClient == client) {
        data.mailClient.isConnected;
      }
    });
  }

  void _unsubscribeEvents() {
    _mailLoadEventSubscription.cancel();
    _mailVanishedEventSubscription.cancel();
    _mailUpdatedEventSubscription.cancel();
    _mailReconnectedEventSubscription.cancel();
  }

  void dispose() {
    _unsubscribeEvents();
  }

  late IndexedCache<MimeMessage> cache;
}
