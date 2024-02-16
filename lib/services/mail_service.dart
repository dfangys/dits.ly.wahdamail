import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';

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
      // storage.erase();
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
    printInfo(info: 'Subscribing to events');
    _mailLoadEventSubscription =
        client.eventBus.on<MailLoadEvent>().listen((event) {
      if (event.mailClient == client) {
        printError(info: 'MailLoadEvent');
        if (Get.isRegistered<MailBoxController>()) {
          Get.find<MailBoxController>().handleIncomingMail(event.message);
        }
      }
    });
    _mailVanishedEventSubscription =
        client.eventBus.on<MailVanishedEvent>().listen((event) async {
      final sequence = event.sequence;
      if (sequence != null) {
        List<MimeMessage> msgs = await client.fetchMessageSequence(
          sequence,
        );
        if (Get.isRegistered<MailBoxController>()) {
          Get.find<MailBoxController>().vanishMails(msgs);
        }
      }
      printError(info: "MailVanishedEvent");
    });
    _mailUpdatedEventSubscription =
        client.eventBus.on<MailUpdateEvent>().listen((event) {
      if (event.mailClient == client) {
        // onMessageFlagsUpdated(event.message);
        printError(info: 'MailUpdateEvent');
        if (Get.isRegistered<MailBoxController>()) {
          Get.find<MailBoxController>().handleIncomingMail(event.message);
        }
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
    client.disconnect();
  }
}
