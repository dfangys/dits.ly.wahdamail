import 'dart:async';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart';
import 'package:wahda_bank/app/controllers/mail_count_controller.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';
import 'package:wahda_bank/models/sqlite_draft_repository.dart';
import 'package:wahda_bank/views/compose/models/draft_model.dart';
import 'package:wahda_bank/services/background_service.dart';
import 'package:wahda_bank/services/internet_service.dart';
import 'package:wahda_bank/views/box/mailbox_view.dart';
import 'package:wahda_bank/views/settings/data/swap_data.dart';
import 'package:workmanager/workmanager.dart';
import '../../services/mail_service.dart';
import '../../views/authantication/screens/login/login.dart';
import '../../views/view/models/box_model.dart';

class MailBoxController extends GetxController {
  late MailService mailService;
  final RxBool isBusy = true.obs;
  final RxBool isBoxBusy = true.obs;
  final getStoarage = GetStorage();

  // Replace Hive storage with SQLite storage
  final RxMap<Mailbox, SQLiteMailboxMimeStorage> mailboxStorage =
      <Mailbox, SQLiteMailboxMimeStorage>{}.obs;
  final RxMap<Mailbox, List<MimeMessage>> emails =
      <Mailbox, List<MimeMessage>>{}.obs;

  // Track current mailbox to fix fetch error when switching
  final Rx<Mailbox?> _currentMailbox = Rx<Mailbox?>(null);
  Mailbox? get currentMailbox => _currentMailbox.value;
  set currentMailbox(Mailbox? value) => _currentMailbox.value = value;

  List<MimeMessage> get boxMails =>
      emails[currentMailbox ?? mailService.client.selectedMailbox] ?? [];

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
    try {
      mailBoxInbox = mailboxes.firstWhere(
            (element) => element.isInbox,
        orElse: () => mailboxes.first,
      );
      await loadEmailsForBox(mailBoxInbox);
    } catch (e) {
      logger.e("Error in initInbox: $e");
      // Reset loading state in case of error
      isBoxBusy(false);
    }
  }

  Future loadMailBoxes() async {
    try {
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
        mailboxStorage[mailbox] = SQLiteMailboxMimeStorage(
          mailAccount: mailService.account,
          mailbox: mailbox,
        );
        emails[mailbox] = <MimeMessage>[];
        await mailboxStorage[mailbox]!.init();
      }
      isBusy(false);
      await initInbox();
    } catch (e) {
      logger.e("Error in loadMailBoxes: $e");
      isBusy(false);
      // Show error to user
      Get.snackbar(
        'Error',
        'Failed to load mailboxes. Please check your connection and try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future loadEmailsForBox(Mailbox mailbox) async {
    try {
      // Set loading state
      isBoxBusy(true);
      
      // Set current mailbox to fix fetch error when switching
      currentMailbox = mailbox;

      if (!mailService.client.isConnected) {
        await mailService.connect();
      }

      await mailService.client.selectMailbox(mailbox);
      
      // Add timeout to prevent infinite loading
      await fetchMailbox(mailbox).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          logger.e("Timeout while fetching mailbox: ${mailbox.name}");
          throw TimeoutException("Loading emails timed out", const Duration(seconds: 30));
        },
      );
    } catch (e) {
      logger.e("Error selecting mailbox: $e");
      // Try to reconnect and retry
      try {
        await mailService.connect();
        await mailService.client.selectMailbox(mailbox);
        await fetchMailbox(mailbox).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            logger.e("Timeout while fetching mailbox on retry: ${mailbox.name}");
            throw TimeoutException("Loading emails timed out on retry", const Duration(seconds: 30));
          },
        );
      } catch (e) {
        logger.e("Failed to reconnect and select mailbox: $e");
        // Show error to user
        Get.snackbar(
          'Error',
          'Failed to load emails. Please check your connection and try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } finally {
      // Always reset loading state
      isBoxBusy(false);
    }
  }

  // Pagination for emails
  int page = 1;
  int pageSize = 20;

  Future<void> fetchMailbox(Mailbox mailbox) async {
    try {
      // Ensure we're working with the correct mailbox
      if (currentMailbox != mailbox) {
        currentMailbox = mailbox;
      }

      // Special handling for draft mailbox
      if (mailbox.name.toLowerCase() == 'drafts' || mailbox.name.toLowerCase() == 'draft') {
        await _loadDraftsFromLocal(mailbox);
        return;
      }

      int max = mailbox.messagesExists;
      if (mailbox.uidNext != null && mailbox.isInbox) {
        await GetStorage().write(
          BackgroundService.keyInboxLastUid,
          mailbox.uidNext,
        );
      }
      if (max == 0) {
        // No messages, but still update the storage to trigger UI update
        if (mailboxStorage[mailbox] != null) {
          await mailboxStorage[mailbox]!.saveMessageEnvelopes([]);
        }
        return;
      }
      
      if (emails[mailbox] == null) {
        emails[mailbox] = <MimeMessage>[];
      }
      page = 1;
      emails[mailbox]!.clear();

      if (mailboxStorage[mailbox] == null) {
        mailboxStorage[mailbox] = SQLiteMailboxMimeStorage(
          mailAccount: mailService.account,
          mailbox: mailbox,
        );
        await mailboxStorage[mailbox]!.init();
      }

      // Load messages in batches to avoid sequence issues
      int loaded = 0;
      while (loaded < max) {
        int batchSize = pageSize;
        if (loaded + batchSize > max) {
          batchSize = max - loaded;
        }
        
        int start = loaded + 1;
        int end = loaded + batchSize;
        
        // Create a safe sequence
        MessageSequence sequence;
        try {
          if (end > max) {
            end = max;
          }
          sequence = MessageSequence.fromRange(start, end);
        } catch (e) {
          logger.e("Error creating sequence for range $start:$end: $e");
          break;
        }
        
        try {
          final messages = await mailboxStorage[mailbox]!.loadMessageEnvelopes(sequence);
          if (messages.isNotEmpty) {
            emails[mailbox]!.addAll(messages);
            loaded += messages.length;
          } else {
            List<MimeMessage> newMessages = await queue(sequence);
            if (newMessages.isNotEmpty) {
              emails[mailbox]!.addAll(newMessages);
              await mailboxStorage[mailbox]!.saveMessageEnvelopes(newMessages);
              loaded += newMessages.length;
            } else {
              // No more messages to load
              break;
            }
          }
        } catch (e) {
          logger.e("Error loading messages for sequence $start:$end: $e");
          // Try to continue with next batch
          loaded += batchSize;
        }
        
        // Prevent infinite loop
        if (loaded >= max || batchSize == 0) {
          break;
        }
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
    } catch (e) {
      logger.e("Error in fetchMailbox: $e");
      // Don't rethrow, let the calling method handle the error
    }
  }

  Future<void> _loadDraftsFromLocal(Mailbox mailbox) async {
    try {
      // Initialize storage for drafts if not exists
      if (mailboxStorage[mailbox] == null) {
        mailboxStorage[mailbox] = SQLiteMailboxMimeStorage(
          mailAccount: mailService.account,
          mailbox: mailbox,
        );
        await mailboxStorage[mailbox]!.init();
      }

      if (emails[mailbox] == null) {
        emails[mailbox] = <MimeMessage>[];
      }
      emails[mailbox]!.clear();

      // Load drafts from local SQLite database
      final draftRepository = SQLiteDraftRepository.instance;
      final drafts = await draftRepository.getAllDrafts();
      
      // Convert drafts to MimeMessage objects
      List<MimeMessage> draftMessages = [];
      for (var draft in drafts) {
        try {
          final mimeMessage = _convertDraftToMimeMessage(draft);
          draftMessages.add(mimeMessage);
        } catch (e) {
          logger.e("Error converting draft to MimeMessage: $e");
        }
      }

      emails[mailbox]!.addAll(draftMessages);
      
      // Save to storage and notify listeners
      await mailboxStorage[mailbox]!.saveMessageEnvelopes(draftMessages);
      
      if (Get.isRegistered<MailCountController>()) {
        final countControll = Get.find<MailCountController>();
        String key = "${mailbox.name.toLowerCase()}_count";
        countControll.counts[key] = draftMessages.length;
      }
    } catch (e) {
      logger.e("Error loading drafts from local: $e");
    }
  }

  MimeMessage _convertDraftToMimeMessage(DraftModel draft) {
    final message = MimeMessage();
    
    // Set basic properties
    message.setHeader('subject', draft.subject);
    
    // Set recipients
    if (draft.to.isNotEmpty) {
      message.setHeader('to', draft.to.join(', '));
    }
    if (draft.cc.isNotEmpty) {
      message.setHeader('cc', draft.cc.join(', '));
    }
    if (draft.bcc.isNotEmpty) {
      message.setHeader('bcc', draft.bcc.join(', '));
    }
    
    // Set date
    message.setHeader('date', draft.createdAt.toIso8601String());
    
    // Set content using the correct MimePart API
    if (draft.body.isNotEmpty) {
      final part = MimePart();
      if (draft.isHtml) {
        part.addHeader('Content-Type', 'text/html; charset=utf-8');
      } else {
        part.addHeader('Content-Type', 'text/plain; charset=utf-8');
      }
      part.addHeader('Content-Transfer-Encoding', 'quoted-printable');
      part.mimeData = TextMimeData(draft.body, containsHeader: false);
      message.addPart(part);
    }
    
    // Mark as draft with custom headers
    message.setHeader('x-draft-id', draft.id?.toString() ?? '');
    message.setHeader('x-is-draft', 'true');
    
    return message;
  }

  Future<List<MimeMessage>> queue(MessageSequence sequence) async {
    try {
      return await mailService.client.fetchMessageSequence(
        sequence,
        fetchPreference: FetchPreference.envelope,
      );
    } catch (e) {
      logger.e("Error in queue method: $e");
      return <MimeMessage>[];
    }
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
    try {
      // Reset current mailbox before navigation to fix fetch error
      currentMailbox = null;

      Get.to(() => MailBoxView(mailBox: mailbox));
      await loadEmailsForBox(mailbox);
    } catch (e) {
      logger.e("Error in navigatToMailBox: $e");
      // Reset loading state in case of error
      isBoxBusy(false);
    }
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

  Future sendMail(MimeMessage message, MimeMessage? msg) async {
    try {
      await mailService.client.sendMessage(message);
      if (msg != null) {
        await mailService.client.deleteMessage(msg);
      }
    } catch (e) {
      logger.e(e);
    }
  }

  Future logout() async {
    try {
      await GetStorage().erase();
      MailService.instance.client.disconnect();
      MailService.instance.dispose();
      await deleteAccount();
      await Workmanager().cancelAll();
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
