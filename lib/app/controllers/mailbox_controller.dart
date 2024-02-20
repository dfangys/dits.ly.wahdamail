import 'package:background_fetch/background_fetch.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart';
import 'package:wahda_bank/app/controllers/mail_count_controller.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/services/background_service.dart';
import 'package:wahda_bank/services/internet_service.dart';
import 'package:wahda_bank/views/box/mailbox_view.dart';
import 'package:wahda_bank/views/settings/data/swap_data.dart';
import '../../models/hive_mime_storage.dart';
import '../../services/mail_service.dart';
import '../../views/authantication/screens/login/login.dart';
import '../../views/view/models/box_model.dart';

class MailBoxController extends GetxController {
  late MailService mailService;
  final RxBool isBusy = true.obs;
  final RxBool isBoxBusy = true.obs;
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
  RxList<Mailbox> mailboxes = <Mailbox>[].obs;

  List<String> predefinedOrder = [
    'inbox',
    'sent',
    'drafts',
    'trash',
    'junk',
    'archive',
  ];

  List<Mailbox> get sortedMailBoxes {
    return mailboxes.toList()
      ..sort((a, b) {
        // Get the index of each item in the predefined order
        int indexA = predefinedOrder.indexOf(a.name.toLowerCase());
        int indexB = predefinedOrder.indexOf(b.name.toLowerCase());
        // Handle cases where the item is not in the predefined order
        if (indexA == -1) indexA = predefinedOrder.length;
        if (indexB == -1) indexB = predefinedOrder.length;
        // Compare based on the indices
        return indexA.compareTo(indexB);
      });
  }

  @override
  void onInit() async {
    try {
      mailService = MailService.instance;
      await mailService.init();
      await loadMailBoxes();
      super.onInit();
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> initInbox() async {
    mailBoxInbox = mailboxes.firstWhere(
      (element) => element.isInbox,
      orElse: () => mailboxes.first,
    );
    loadEmailsForBox(mailBoxInbox);
  }

  Future loadMailBoxes() async {
    List b = getStoarage.read('boxes') ?? [];
    if (b.isEmpty) {
      await mailService.connect();
      mailboxes(await mailService.client.listMailboxes());
    } else {
      mailboxes(
        b.map((e) => BoxModel.fromJson(e as Map<String, dynamic>)).toList(),
      );
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
    if (Get.isRegistered<MailCountController>()) {
      final countControll = Get.find<MailCountController>();
      String key = "${mailbox.name.toLowerCase()}_count";
      countControll.counts[key] =
          emails[mailbox]!.where((e) => !e.isSeen).length;
    }
    storeContactMails(emails[mailbox]!);
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

  //
  DeleteResult? deleteResult;
  Map<Mailbox, List<MimeMessage>> deletedMessages = {};

  Future deleteMails(List<MimeMessage> messages, Mailbox mailbox) async {
    for (var message in messages) {
      if (mailboxStorage[mailbox] != null) {
        await mailboxStorage[mailbox]!.deleteMessage(message);
      }
    }
    deletedMessages[mailbox] = messages;
    // set on server
    if (mailService.client.isConnected) {
      deleteResult = await mailService.client.deleteMessages(
        MessageSequence.fromMessages(messages),
        messages: messages,
        expunge: false,
      );
    }
    if (deleteResult != null && deleteResult!.canUndo) {
      Get.showSnackbar(
        GetSnackBar(
          message: 'messages_deleted'.tr,
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
          mainButton: TextButton(
            onPressed: () async {
              await undoDelete();
            },
            child: Text('undo'.tr),
          ),
        ),
      );
    }
  }

  Future undoDelete() async {
    if (deleteResult != null) {
      await mailService.client.undoDeleteMessages(deleteResult!);
      deleteResult = null;
      for (var mailbox in deletedMessages.keys) {
        await mailboxStorage[mailbox]!
            .saveMessageEnvelopes(deletedMessages[mailbox]!);
      }
      deletedMessages.clear();
    }
  }

  Future moveMails(List<MimeMessage> messages, Mailbox from, Mailbox to) async {
    for (var message in messages) {
      if (mailboxStorage[from] != null) {
        await mailboxStorage[from]!.deleteMessage(message);
      }
      if (mailboxStorage[to] != null) {
        await mailboxStorage[to]!.saveMessageEnvelopes([message]);
      }
    }
    // set on server
    if (mailService.client.isConnected) {
      for (var message in messages) {
        await mailService.client.moveMessage(message, to);
      }
    }
  }

  // update flage on messages on server
  Future updateFlag(List<MimeMessage> messages, Mailbox mailbox) async {
    for (var message in messages) {
      message.isFlagged = !message.isFlagged;
      if (mailboxStorage[mailbox] != null) {
        await mailboxStorage[mailbox]!.saveMessageEnvelopes([message]);
      }
    }
    // set on server
    if (mailService.client.isConnected) {
      for (var message in messages) {
        await mailService.client.flagMessage(
          message,
          isFlagged: message.isFlagged,
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

  Future ltrTap(MimeMessage message, Mailbox mailbox) async {
    SwapAction action =
        getSwapActionFromString(settingController.swipeGesturesLTR());
    _doSwapAction(
      action,
      message,
      mailbox,
    );
  }

  Future rtlTap(MimeMessage message, Mailbox mailbox) async {
    SwapAction action =
        getSwapActionFromString(settingController.swipeGesturesRTL());
    _doSwapAction(
      action,
      message,
      mailbox,
    );
  }

  Future _doSwapAction(
      SwapAction action, MimeMessage message, Mailbox box) async {
    if (action == SwapAction.readUnread) {
      await markAsReadUnread([message], box, !message.isSeen);
    } else if (action == SwapAction.delete) {
      await deleteMails([message], box);
    } else if (action == SwapAction.archive) {
      Mailbox? archive = mailboxes.firstWhereOrNull((e) => e.isArchive);
      if (archive != null) {
        await moveMails([message], box, archive);
      }
    } else if (action == SwapAction.toggleFlag) {
      await updateFlag([message], box);
    } else if (action == SwapAction.markAsJunk) {
      Mailbox? junk = mailboxes.firstWhereOrNull((e) => e.isJunk);
      if (junk != null) {
        await moveMails([message], box, junk);
      }
    }
  }

  Future handleIncomingMail(MimeMessage message) async {
    // detect the mailbox from the message
    Mailbox? mailbox = mailboxes.firstWhereOrNull(
      (element) => element.flags.any((e) => message.hasFlag(e.name)),
    );
    if (mailbox != null) {
      await mailboxStorage[mailbox]!.saveMessageEnvelopes([message]);
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
    Get.to(() => MailBoxView(mailBox: mailbox));
    await loadEmailsForBox(mailbox);
  }

  void storeContactMails(List<MimeMessage> messages) {
    Set<String> mails = {};
    mails.addAll((getStoarage.read('mails') ?? []).cast<String>());
    for (var msg in messages) {
      if (msg.from != null) {
        for (var e in msg.from!) {
          try {
            mails.add(e.email);
          } catch (e) {
            logger.e(e);
          }
        }
      }
    }
    getStoarage.write('mails', mails.cast<String>().toList());
  }

  Future logout() async {
    try {
      await GetStorage().erase();
      MailService.instance.client.disconnect();
      MailService.instance.dispose();
      await deleteAccount();
      await BackgroundFetch.stop();
      Get.offAll(() => LoginScreen());
    } catch (e) {
      logger.e(e);
    }
  }

  @override
  void dispose() {
    MailService.instance.dispose();
    super.dispose();
  }
}
