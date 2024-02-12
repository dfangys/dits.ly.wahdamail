import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:wahda_bank/views/box/mailbox_view.dart';
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

  late Mailbox mailBoxInbox;

  final Logger logger = Logger();

  Rx<Mailbox>? selected;
  RxList<Mailbox> mailboxes = <Mailbox>[].obs;

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

  Future navigatToMailBox(Mailbox mailbox) async {
    await loadEmailsForBox(mailbox);
    String hiveKey = HiveMailboxMimeStorage.getBoxName(
      mailService.account,
      mailbox,
      'envelopes',
    );
    Get.to(() => MailBoxView(hiveKey: hiveKey, box: mailbox));
  }
}
