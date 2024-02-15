import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/services/background_service.dart';
import 'package:wahda_bank/views/box/mailbox_view.dart';
import 'package:wahda_bank/views/settings/data/swap_data.dart';
import '../../models/hive_mime_storage.dart';
import '../../services/mail_service.dart';

class MailBoxController extends GetxController {
  late MailService mailService;
  final RxBool isBusy = true.obs;

  final RxMap<Mailbox, HiveMailboxMimeStorage> mailboxStorage =
      <Mailbox, HiveMailboxMimeStorage>{}.obs;
  final RxMap<Mailbox, List<MimeMessage>> emails =
      <Mailbox, List<MimeMessage>>{}.obs;

  List<MimeMessage> get boxMails =>
      emails[mailService.client.selectedMailbox] ?? [];

  SettingController settingController = Get.find<SettingController>();

  late Mailbox mailBoxInbox;

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
      mailboxes(await mailService.client.listMailboxes());
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
  Future markAsRead(int uId) async {
    final storage = mailboxStorage[mailService.client.selectedMailbox];
    if (storage == null) return;
    final messages = emails[mailService.client.selectedMailbox];
    if (messages == null) return;
    final index = messages.indexWhere((element) => element.uid == uId);
    if (index == -1) return;
    final message = messages[index];
    message.isSeen = !message.isSeen;
    messages[index] = message;
    emails[mailService.client.selectedMailbox!] = messages;
    await storage.saveMessageContents(message);
    var sequence = MessageSequence.fromUid(message);
    mailService.client.markSeen(sequence);
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
    Get.to(() => MailBoxView(hiveKey: hiveKey, box: mailbox));
    await loadEmailsForBox(mailbox);
  }

  @override
  void dispose() {
    MailService.instance.dispose();
    super.dispose();
  }
}
