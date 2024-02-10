import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
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

  final Logger logger = Logger();

  @override
  void onInit() async {
    mailService = MailService.instance;
    await mailService.init();
    initInbox();
    super.onInit();
  }

  Future<void> initInbox() async {
    printError(info: 'Loading inbox');
    isBusy(true);
    var box = await mailService.client.selectInbox();
    loadEmailsForBox(box);
    isBusy(false);
    printError(info: 'Loaded inbox');
  }

  Future loadMailBoxes() async {
    if (!mailService.isConnected) {
      await mailService.connect();
    }
    List<Mailbox> mailboxes = mailService.client.mailboxes ?? [];
    for (var mailbox in mailboxes) {
      mailboxStorage[mailbox] = HiveMailboxMimeStorage(
        mailAccount: mailService.account,
        mailbox: mailbox,
      );
      emails[mailbox] = <MimeMessage>[];
      await mailboxStorage[mailbox]!.init();
    }
  }

  Future loadEmailsForBox(Mailbox mailbox) async {
    if (!mailService.isConnected) {
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
    while (emails[mailbox]!.length < max) {
      logger.d('Fetching page $page for $mailbox $pageSize $max');
      MessageSequence sequence = MessageSequence.fromPage(page, pageSize, max);
      final storage = mailboxStorage[mailbox];
      if (storage == null) {
        mailboxStorage[mailbox] = HiveMailboxMimeStorage(
          mailAccount: mailService.account,
          mailbox: mailbox,
        );
        await mailboxStorage[mailbox]!.init();
      }
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
}
