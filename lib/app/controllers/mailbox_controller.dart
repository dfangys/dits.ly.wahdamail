import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/services/background_service.dart';
import 'package:wahda_bank/services/internet_service.dart';
import 'package:wahda_bank/views/box/mailbox_view.dart';
import 'package:wahda_bank/views/settings/data/swap_data.dart';
import 'package:wahda_bank/widgets/dialogs/process_dialog.dart';
import '../../models/hive_mime_storage.dart';
import '../../services/mail_service.dart';
import '../../views/view/models/box_model.dart';

class MailBoxController extends GetxController {
  late MailService mailService;
  final RxBool isBusy = true.obs;
  final getStoarage = GetStorage();

  final RxMap<Mailbox, HiveMailboxMimeStorage> mailboxStorage =
      <Mailbox, HiveMailboxMimeStorage>{}.obs;
  final RxMap<Mailbox, List<MimeMessage>> emails =
      <Mailbox, List<MimeMessage>>{}.obs;

  List<MimeMessage> get boxMails =>
      emails[mailService.client.selectedMailbox] ?? [];

  SettingController settingController = Get.find<SettingController>();

  Mailbox mailBoxInbox = Mailbox(
    encodedName: 'inbox',
    encodedPath: 'inbox',
    flags: [],
    pathSeparator: '',
  );

  final Logger logger = Logger();

  Rx<Mailbox>? selected;
  RxList<Mailbox> mailboxes = <Mailbox>[].obs;

  List<Mailbox> get drawerBoxes =>
      mailboxes.where((e) => e.name.toLowerCase() != 'inbox').toList();

  @override
  void onInit() async {
    // try {
    mailService = MailService.instance;
    await mailService.init();
    if (mailService.client.mailboxes == null) {
      await mailService.connect();
      await loadMailBoxes();
    } else {
      mailboxes(mailService.client.mailboxes!);
      await loadMailBoxes();
    }
    super.onInit();
    // } catch (e) {
    //   logger.e(e);
    // }
  }

  Future<void> initInbox() async {
    isBusy(true);
    mailBoxInbox = mailboxes[0];
    loadEmailsForBox(mailBoxInbox);
    isBusy(false);
  }

  Future loadMailBoxes() async {
    if (mailService.client.mailboxes == null) {
      var b = getStoarage.read('boxes');
      if (b == null) {
        mailboxes(await mailService.client.listMailboxes());
      } else {
        mailboxes(b.map((e) => BoxModel.fromJson(e)).toList());
      }
    } else {
      mailboxes(mailService.client.mailboxes!);
    }
    for (var mailbox in mailboxes) {
      if (mailboxStorage[mailbox] != null) continue;
      mailboxStorage[mailbox] = HiveMailboxMimeStorage(
        mailAccount: mailService.account,
        mailbox: mailbox,
      );
      emails[mailbox] = <MimeMessage>[];
      await mailboxStorage[mailbox]!.init();
    }
    isBusy(false);
    initInbox();
  }

  Future loadEmailsForBox(Mailbox mailbox) async {
    if (!mailService.client.isConnected) {
      await mailService.connect();
    }
    await mailService.client.selectMailbox(mailbox);
    await fetchMailbox(mailbox);
  }

  // Pagination for emails
  int page = 1;
  int pageSize = 20;

  Future<void> fetchMailbox(Mailbox mailbox) async {
    int max = mailbox.messagesExists;
    if (mailbox.uidNext != null && mailbox.isInbox) {
      await GetStorage().write(
        BackgroundService.keyInboxLastUid,
        mailbox.uidNext,
      );
    }
    if (max == 0) return;
    if (emails[mailbox] == null) {
      emails[mailbox] = <MimeMessage>[];
    }
    page = 1;
    //

    if (mailboxStorage[mailbox] == null) {
      mailboxStorage[mailbox] = HiveMailboxMimeStorage(
        mailAccount: mailService.account,
        mailbox: mailbox,
      );
      await mailboxStorage[mailbox]!.init();
    }

    while (emails[mailbox]!.length < max) {
      logger.d('Fetching page $page for $mailbox $pageSize $max');
      MessageSequence sequence = MessageSequence.fromPage(page, pageSize, max);
      final messages =
          await mailboxStorage[mailbox]!.loadMessageEnvelopes(sequence);
      if (messages != null && messages.isNotEmpty) {
        emails[mailbox]!.addAll(messages);
      } else {
        List<MimeMessage> newMessages = await queue(sequence);
        emails[mailbox]!.addAll(newMessages);
        await mailboxStorage[mailbox]!.saveMessageEnvelopes(newMessages);
      }
      page += 1;
    }
    if (mailbox.isInbox) {
      BackgroundService.checkForNewMail(false);
    }
  }

  Future<List<MimeMessage>> queue(MessageSequence sequence) async {
    return await mailService.client.fetchMessageSequence(
      sequence,
      fetchPreference: FetchPreference.envelope,
    );
  }

  // Operations on emails
  Future markAsReadUnread(List<MimeMessage> messages, Mailbox box,
      [bool isSeen = true]) async {
    showDialog(
      context: Get.context!,
      builder: (c) => const ProcessDialog(),
    );
    for (var message in messages) {
      message.isSeen = isSeen;
      if (mailboxStorage[box] != null) {
        await mailboxStorage[box]!.saveMessageEnvelopes([message]);
      }
    }
    if (!InternetService.instance.connected) {
      return;
    }
    // set on server
    if (mailService.client.isConnected) {
      for (var message in messages) {
        await mailService.client.flagMessage(message, isSeen: isSeen);
      }
    }
  }

  Future deleteMails(List<MimeMessage> messages) async {
    for (var message in messages) {
      message.isDeleted = true;
      for (var element in mailboxStorage.values) {
        await element.deleteMessage(message);
      }
    }
    // set on server
    if (mailService.client.isConnected) {
      for (var message in messages) {
        await mailService.client.deleteMessage(message);
      }
    }
  }

  Future moveMails(List<MimeMessage> messages, Mailbox mailbox) async {
    for (var message in messages) {
      for (var element in mailboxStorage.values) {
        await element.deleteMessage(message);
      }
    }
    // set on server
    if (mailService.client.isConnected) {
      for (var message in messages) {
        await mailService.client.moveMessage(message, mailbox);
      }
    }
  }

  // update flage on messages on server
  Future updateFlag(List<MimeMessage> messages) async {
    for (var message in messages) {
      message.isFlagged = !message.isFlagged;
      if (mailboxStorage[mailService.client.selectedMailbox] != null) {
        await mailboxStorage[mailService.client.selectedMailbox]!
            .saveMessageEnvelopes([message]);
      }
    }
    // set on server
    if (mailService.client.isConnected) {
      for (var message in messages) {
        await mailService.client.flagMessage(
          message,
          isFlagged: !message.isFlagged,
        );
      }
    }
  }

  // Operations on emails
  Future deleteAccount() async {
    for (var mailbox in MailService.instance.client.mailboxes ?? []) {
      if (mailboxStorage[mailbox] != null) {
        await mailboxStorage[mailbox]!.onAccountRemoved();
      }
    }
  }

  Future ltrTap(MimeMessage message) async {
    SwapAction action =
        getSwapActionFromString(settingController.swipeGesturesLTR.value);
    if (action == SwapAction.readUnread) {
    } else if (action == SwapAction.delete) {
    } else if (action == SwapAction.archive) {
    } else if (action == SwapAction.toggleFlag) {
    } else if (action == SwapAction.markAsJunk) {}
  }

  Future rtlTap(MimeMessage message) async {
    SwapAction action =
        getSwapActionFromString(settingController.swipeGesturesRTL.value);
    if (action == SwapAction.readUnread) {
    } else if (action == SwapAction.delete) {
    } else if (action == SwapAction.archive) {
    } else if (action == SwapAction.toggleFlag) {
    } else if (action == SwapAction.markAsJunk) {}
  }

  Future handleIncomingMail(MimeMessage message) async {
    for (var element in mailboxStorage.values) {
      await element.saveMessageEnvelopes([message]);
    }
  }

  Future vanishMails(List<MimeMessage> msgs) async {
    for (var message in msgs) {
      if (message.isDeleted) {
        for (var element in mailboxStorage.values) {
          await element.deleteMessage(message);
        }
      }
    }
  }

  Future navigatToMailBox(Mailbox mailbox) async {
    String hiveKey = HiveMailboxMimeStorage.getBoxName(
      mailService.account,
      mailbox,
      'envelopes',
    );
    Get.to(() => MailBoxView(hiveKey: hiveKey, mailBox: mailbox));
    await loadEmailsForBox(mailbox);
  }

  @override
  void dispose() {
    MailService.instance.dispose();
    super.dispose();
  }
}
