import 'dart:math';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart';
import 'package:wahda_bank/models/hive_mime_storage.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/services/notifications_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BackgroundService {
  static const String keyInboxLastUid = 'inboxLastUid';

  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static Logger logger = Logger();

  Future<void> addNextUidFor() async {
    try {
      MailService mailService = MailService.instance;
      await mailService.init();
      await mailService.client.connect();
      if (mailService.client.isConnected) {
        var box = await mailService.client.selectInbox();
        final uidNext = box.uidNext;
        if (uidNext != null) {
          var prefs = GetStorage();
          await prefs.write(keyInboxLastUid, uidNext);
        }
      }
    } catch (e, s) {
      if (kDebugMode) {
        print('Error while getting Inbox.nextUids for : $e $s');
      }
    }
  }

  static Future checkForNewMail([bool showNotifications = true]) async {
    if (kDebugMode) {
      logger.d('background check at ${DateTime.now()}');
    }
    await NotificationService.instance.setup();
    await GetStorage.init();
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(StorageMessageIdAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(StorageMessageEnvelopeAdapter());
    }
    final prefs = GetStorage();
    int? previousUidNext = prefs.read(keyInboxLastUid);
    if (previousUidNext == null) {
      return;
    }
    await MailService.instance.init();
    if (!MailService.instance.client.isConnected) {
      await MailService.instance.connect();
    }
    if (!MailService.instance.client.isConnected) {
      return;
    }
    final inbox = await MailService.instance.client.selectInbox();
    final uidNext = inbox.uidNext;
    if (uidNext == previousUidNext || uidNext == null) {
      return;
    } else {
      MessageSequence sequence = MessageSequence.fromRangeToLast(
        previousUidNext == 0
            ? max(previousUidNext, uidNext - 10)
            : previousUidNext,
        isUidSequence: true,
      );
      final mimeMessages =
          await MailService.instance.client.fetchMessageSequence(
        sequence,
        fetchPreference: FetchPreference.envelope,
      );
      HiveMailboxMimeStorage mailStorage = HiveMailboxMimeStorage(
        mailAccount: MailService.instance.account,
        mailbox: inbox,
      );
      if (mimeMessages.isNotEmpty) {
        await GetStorage().write(keyInboxLastUid, uidNext);
        await mailStorage.init();
        await mailStorage.saveMessageEnvelopes(mimeMessages);
      }
      if (showNotifications) {
        for (final mimeMessage in mimeMessages) {
          if (!mimeMessage.isSeen) {
            NotificationService.instance.showFlutterNotification(
              mimeMessage.from![0].email,
              mimeMessage.decodeSubject() ?? 'New Mail',
              {'action': 'inbox', 'message': mimeMessage.decodeSubject() ?? ''},
            );
          }
        }
      }
    }
  }
}
