import 'dart:io';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/models/hive_mime_storage.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/views/view/models/box_model.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/authantication/screens/login/login.dart';
import 'package:wahda_bank/utills/extensions/mail_service_extensions.dart';

/// Email validation extension
extension EmailValidator on String {
  bool isValidEmail() {
    return RegExp(
        r"[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?")
        .hasMatch(this);
  }
}

/// Controller for compose screen
class ComposeController extends GetxController {
  MailAccount account = MailService.instance.account;
  MailClient client = MailService.instance.client;

  // Reactive lists for email recipients
  RxList<MailAddress> toList = <MailAddress>[].obs;
  RxList<MailAddress> cclist = <MailAddress>[].obs;
  RxList<MailAddress> bcclist = <MailAddress>[].obs;

  // Form controllers
  TextEditingController subjectController = TextEditingController();
  TextEditingController fromController = TextEditingController();
  final HtmlEditorController htmlController = HtmlEditorController();
  TextEditingController plainTextController = TextEditingController();

  // Message builder and attachments
  late MessageBuilder messageBuilder;
  RxList<File> attachments = <File>[].obs;

  // Content variables
  String bodyPart = '';
  String signature = '';

  // UI state variables
  RxBool canPop = false.obs;
  RxBool isCcAndBccVisible = false.obs;
  RxBool isHtml = true.obs;
  RxBool isSending = false.obs;
  RxBool isSavingDraft = false.obs;
  RxDouble uploadProgress = 0.0.obs;

  // Cache for HTML content
  String htmlBody = '';

  // Flag to prevent multiple simultaneous operations
  bool isUiBusy = false;

  // Get saved email addresses for autocomplete
  List<MailAddress> get mailAddresses =>
      (GetStorage().read('mails') ?? []).map<MailAddress>((e) {
        return MailAddress.parse(e.toString());
      }).toList();

  // Storage and settings
  final storage = GetStorage();
  final settingController = Get.find<SettingController>();

  // Email properties
  String get email => account.email;
  String get name => storage.read('accountName') ?? account.name;

  // Message properties for reply/forward
  MimeMessage? msg;
  String? type;

  // Storage for mailbox operations
  final Map<Mailbox, HiveMailboxMimeStorage> mailboxStorage = {};

  @override
  void onInit() {
    super.onInit();
    _initializeCompose();
  }

  void _initializeCompose() {
    // Set up from field
    if (name.isNotEmpty) {
      fromController.text = "$name <$email>";
    } else {
      fromController.text = email;
    }

    // Check for arguments (reply, forward, draft)
    if (Get.arguments != null) {
      _processArguments();
    } else {
      // New message
      signature = settingController.signatureNewMessage()
          ? settingController.signature()
          : '';
      messageBuilder = MessageBuilder();
    }
  }

  void _processArguments() {
    type = Get.arguments['type'];
    msg = Get.arguments['message'];
    String? toMails = Get.arguments['to'];
    String? support = Get.arguments['support'];

    // Handle direct recipients if provided
    if (toMails != null) {
      toMails.split(' ').forEach((e) {
        toList.add(MailAddress("", e));
      });
    }

    // Handle support email if provided
    if (support != null) {
      toList.add(MailAddress("", support));
      messageBuilder = MessageBuilder();
    }

    // Process message if provided (reply, forward, draft)
    if (msg != null) {
      _setupMessageFromType();
    }
  }

  void _setupMessageFromType() {
    switch (type) {
      case 'reply':
        _setupReply(false);
        break;
      case 'reply_all':
        _setupReply(true);
        break;
      case 'forward':
        _setupForward();
        break;
      case 'draft':
        _setupDraft();
        break;
      default:
        messageBuilder = MessageBuilder();
        signature = settingController.signatureNewMessage()
            ? settingController.signature()
            : '';
    }

    // Set body part from message
    bodyPart = (msg!.decodeTextHtmlPart() ?? msg!.decodeTextPlainPart() ?? '');
    debugPrint("Init body part $bodyPart");
  }

  void _setupReply(bool replyAll) {
    // Add recipients
    toList.addAll(msg!.from ?? []);

    if (replyAll) {
      toList.addAll(msg!.to ?? []);
      cclist.addAll(msg!.cc ?? []);
      bcclist.addAll(msg!.bcc ?? []);
    }

    // Set subject with Re: prefix
    subjectController.text = 'Re: ${msg!.decodeSubject()}';

    // Add signature if enabled
    signature = settingController.signatureReply()
        ? settingController.signature()
        : '';

    // Create message builder
    messageBuilder = MessageBuilder.prepareReplyToMessage(
      msg!,
      MailAddress(name, email),
      replyAll: replyAll,
    );
  }

  void _setupForward() {
    // Set subject with Fwd: prefix
    subjectController.text = 'Fwd: ${msg!.decodeSubject()}';

    // Add signature if enabled
    signature = settingController.signatureForward()
        ? settingController.signature()
        : '';

    // Create message builder
    messageBuilder = MessageBuilder.prepareForwardMessage(msg!);
  }

  void _setupDraft() {
    // Add recipients
    toList.addAll(msg!.to ?? []);
    cclist.addAll(msg!.cc ?? []);
    bcclist.addAll(msg!.bcc ?? []);

    // Set subject
    subjectController.text = '${msg!.decodeSubject()}';

    // Add signature if enabled
    signature = settingController.signatureNewMessage()
        ? settingController.signature()
        : '';

    // Create message builder
    messageBuilder = MessageBuilder.prepareFromDraft(msg!);
  }

  // Load a draft message
  void loadDraft(MimeMessage draftMessage) {
    msg = draftMessage;
    type = 'draft';

    // Add recipients
    toList.addAll(draftMessage.to ?? []);
    cclist.addAll(draftMessage.cc ?? []);
    bcclist.addAll(draftMessage.bcc ?? []);

    // Set subject
    subjectController.text = draftMessage.decodeSubject() ?? '';

    // Set body
    bodyPart = draftMessage.decodeTextHtmlPart() ?? draftMessage.decodeTextPlainPart() ?? '';
    htmlController.setText(bodyPart);

    // Add signature if enabled
    signature = settingController.signatureNewMessage()
        ? settingController.signature()
        : '';

    // Create message builder
    messageBuilder = MessageBuilder.prepareFromDraft(draftMessage);

    // Show CC/BCC if they have recipients
    if (cclist.isNotEmpty || bcclist.isNotEmpty) {
      isCcAndBccVisible.value = true;
    }

    // Update UI
    update();
  }

  // Recipient management methods
  void addTo(MailAddress mailAddress) {
    if (toList.any((e) => e.email == mailAddress.email)) {
      return;
    } else if (mailAddress.email.isValidEmail()) {
      toList.add(mailAddress);
      _saveEmailToHistory(mailAddress);
    }

    // Remove from other lists if present
    if (bcclist.any((e) => e.email == mailAddress.email)) {
      bcclist.removeWhere((e) => e.email == mailAddress.email);
    }
    if (cclist.any((e) => e.email == mailAddress.email)) {
      cclist.removeWhere((e) => e.email == mailAddress.email);
    }
  }

  void removeFromToList(int index) => toList.removeAt(index);

  void addToCC(MailAddress mailAddress) {
    if (cclist.any((e) => e.email == mailAddress.email)) {
      return;
    } else if (mailAddress.email.isValidEmail()) {
      cclist.add(mailAddress);
      _saveEmailToHistory(mailAddress);
    }

    // Remove from other lists if present
    if (toList.any((e) => e.email == mailAddress.email)) {
      toList.removeWhere((e) => e.email == mailAddress.email);
    }
    if (bcclist.any((e) => e.email == mailAddress.email)) {
      bcclist.removeWhere((e) => e.email == mailAddress.email);
    }
  }

  void removeFromCcList(int index) => cclist.removeAt(index);

  void addToBcc(MailAddress mailAddress) {
    if (bcclist.any((e) => e.email == mailAddress.email)) {
      return;
    } else if (mailAddress.email.isValidEmail()) {
      bcclist.add(mailAddress);
      _saveEmailToHistory(mailAddress);
    }

    // Remove from other lists if present
    if (toList.any((e) => e.email == mailAddress.email)) {
      toList.removeWhere((e) => e.email == mailAddress.email);
    }
    if (cclist.any((e) => e.email == mailAddress.email)) {
      cclist.removeWhere((e) => e.email == mailAddress.email);
    }
  }

  void removeFromBccList(int index) => bcclist.removeAt(index);

  // Save email to history for autocomplete
  void _saveEmailToHistory(MailAddress address) {
    try {
      List<String> emails = storage.read('mails') ?? [];
      if (!emails.contains(address.toString())) {
        emails.add(address.toString());
        storage.write('mails', emails);
      }
    } catch (e) {
      debugPrint('Error saving email to history: $e');
    }
  }

  // File attachment methods
  Future<void> pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null) {
        for (PlatformFile file in result.files) {
          if (file.path != null) {
            // Check file size (limit to 25MB per file)
            final fileSize = File(file.path!).lengthSync();
            if (fileSize > 25 * 1024 * 1024) {
              Get.snackbar(
                'File Too Large',
                'Maximum file size is 25MB',
                backgroundColor: Colors.red,
                colorText: Colors.white,
                snackPosition: SnackPosition.BOTTOM,
              );
              continue;
            }

            attachments.add(File(file.path!));
          }
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not pick files: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null) {
        for (PlatformFile file in result.files) {
          if (file.path != null) {
            // Check file size (limit to 10MB per image)
            final fileSize = File(file.path!).lengthSync();
            if (fileSize > 10 * 1024 * 1024) {
              Get.snackbar(
                'Image Too Large',
                'Maximum image size is 10MB',
                backgroundColor: Colors.red,
                colorText: Colors.white,
                snackPosition: SnackPosition.BOTTOM,
              );
              continue;
            }

            attachments.add(File(file.path!));
          }
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not pick images: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null) {
        attachments.add(File(photo.path));
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not take photo: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void deleteAttachment(int index) {
    attachments.removeAt(index);
  }

  // Draft saving
  Future<void> saveAsDraft() async {
    if (isUiBusy) return;

    try {
      isUiBusy = true;
      isSavingDraft.value = true;

      // Show loading indicator
      EasyLoading.show(
        status: 'Saving draft...',
        maskType: EasyLoadingMaskType.black,
        dismissOnTap: false,
      );

      // Get message body
      late String body;
      if (isHtml.value) {
        body = (await htmlController.getText()) + signature;
      } else {
        body = plainTextController.text + signature;
      }

      // Create message
      _buildMessage(body);

      // Save to drafts folder
      final boxController = Get.find<MailBoxController>();
      var box = await client.selectMailboxByFlag(MailboxFlag.drafts);
      MimeMessage draftMessage = messageBuilder.buildMimeMessage();

      // Save draft
      UidResponseCode? code = await client.saveDraftMessage(draftMessage);

      // Handle response
      if (code == null) {
        EasyLoading.showError('Failed to save draft');
      } else {
        EasyLoading.showSuccess('Draft saved');
      }

      // Delete old draft if editing
      if (msg != null && type != null && type == 'draft') {
        await boxController.deleteMails([msg!], box);

        // Create storage if needed
        if (!boxController.mailboxStorage.containsKey(box)) {
          boxController.mailboxStorage[box] = HiveMailboxMimeStorage(
            mailAccount: account,
            mailbox: box,
          );
          await boxController.mailboxStorage[box]!.init();
        }

        await boxController.mailboxStorage[box]!
            .saveMessageEnvelopes([draftMessage]);
      }

      canPop(true);

    } catch (e) {
      _showErrorDialog('Failed to save draft', e.toString());
    } finally {
      EasyLoading.dismiss();
      isUiBusy = false;
      isSavingDraft.value = false;
    }
  }

  // Send email
  Future<void> sendEmail() async {
    if (isUiBusy) return;

    try {
      isUiBusy = true;
      isSending.value = true;

      // Validate inputs
      if (!_validateInputs()) {
        isUiBusy = false;
        isSending.value = false;
        return;
      }

      // Show loading indicator
      EasyLoading.show(
        status: 'Sending email...',
        maskType: EasyLoadingMaskType.black,
        dismissOnTap: false,
      );

      // Get message body
      late String body;
      if (isHtml.value) {
        body = (await htmlController.getText()) + signature;
      } else {
        body = plainTextController.text + signature;
      }

      // Create message
      _buildMessage(body);

      // Add read receipt if enabled
      if (settingController.readReceipts()) {
        messageBuilder.requestReadReceipt();
      }

      // Send email
      await Get.find<MailBoxController>().sendMail(
        messageBuilder.buildMimeMessage(),
        msg,
      );

      // Show success and close compose screen
      EasyLoading.showSuccess('Email sent');
      canPop(true);
      Get.back();

    } catch (e) {
      _showErrorDialog('Failed to send email', e.toString());
    } finally {
      EasyLoading.dismiss();
      isUiBusy = false;
      isSending.value = false;
    }
  }

  // Build message with common settings
  void _buildMessage(String body) async {
    // Reset message builder if needed
    // Check if messageBuilder has content before accessing it
    try {
      if (_hasContent(messageBuilder)) {
        messageBuilder = MessageBuilder();
      }
    } catch (e) {
      // If there's an error, create a new builder
      messageBuilder = MessageBuilder();
    }

    // Add attachments
    for (var file in attachments) {
      await messageBuilder.addFile(
        file,
        MediaType.guessFromFileName(file.path),
      );
    }

    // Set message properties
    messageBuilder
      ..to = toList.toList()
      ..cc = cclist.toList()
      ..bcc = bcclist.toList()
      ..subject = subjectController.text
      ..from = [MailAddress(name, email)]
      ..addMultipartAlternative(
        htmlText: "<p>$body</p>",
        plainText: body,
      );
  }

  // Helper method to check if MessageBuilder has content
  bool _hasContent(MessageBuilder builder) {
    // Safe way to check if the builder has content
    return builder.to != null ||
        builder.cc != null ||
        builder.bcc != null ||
        builder.subject != null;
  }

  // Validate inputs before sending
  bool _validateInputs() {
    if (toList.isEmpty && cclist.isEmpty && bcclist.isEmpty) {
      Get.snackbar(
        'Missing Recipients',
        'Please add at least one recipient',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    return true;
  }

  // Show error dialog
  void _showErrorDialog(String title, String message) {
    AwesomeDialog(
      context: Get.context!,
      dialogType: DialogType.error,
      animType: AnimType.bottomSlide,
      title: title,
      desc: message,
      btnOkOnPress: () {},
      btnOkColor: Colors.red,
    ).show();
  }

  // Toggle CC/BCC visibility
  void showCcBcc() {
    isCcAndBccVisible.value = true;
  }

  // Toggle HTML mode
  void toggleHtmlMode() {
    isHtml.value = !isHtml.value;
    if (isHtml.value) {
      htmlController.setText(plainTextController.text);
    } else {
      plainTextController.text = htmlBody;
    }
  }

  // Check if can discard
  bool canDiscard() {
    return subjectController.text.isNotEmpty ||
        toList.isNotEmpty ||
        cclist.isNotEmpty ||
        bcclist.isNotEmpty ||
        plainTextController.text.isNotEmpty ||
        htmlBody.isNotEmpty ||
        attachments.isNotEmpty;
  }

  // Handle authentication errors
  void handleAuthError() {
    try {
      MailService.instance.disconnect();
      Get.offAll(() => LoginScreen());
    } catch (e) {
      debugPrint('Error handling auth error: $e');
    }
  }

  @override
  void onClose() {
    subjectController.dispose();
    fromController.dispose();
    plainTextController.dispose();
    super.onClose();
  }
}
