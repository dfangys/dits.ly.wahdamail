import 'dart:io';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/services/mail_service.dart';

import '../../../app/controllers/settings_controller.dart';

extension EmailValidator on String {
  bool isValidEmail() {
    return RegExp(
            r"[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?")
        .hasMatch(this);
  }
}

class ComposeController extends GetxController {
  MailAccount account = MailService.instance.account;
  MailClient client = MailService.instance.client;

  RxList<MailAddress> toList = <MailAddress>[].obs;
  RxList<MailAddress> cclist = <MailAddress>[].obs;
  RxList<MailAddress> bcclist = <MailAddress>[].obs;
  TextEditingController subjectController = TextEditingController();
  TextEditingController fromController = TextEditingController();
  final HtmlEditorController htmlController = HtmlEditorController();
  late MessageBuilder messageBuilder;
  RxList<File> attachments = <File>[].obs;
  String bodyPart = '';
  String signature = '';

  RxBool canPop = false.obs;

  RxBool isCcAndBccVisible = false.obs;
  List<MailAddress> get mailAddresses =>
      (GetStorage().read('mails') ?? []).map<MailAddress>((e) {
        return MailAddress.parse(e.toString());
      }).toList();

  void addTo(MailAddress mailAddress) {
    if (toList.any((e) => e.email == mailAddress.email)) {
      return;
    } else if (mailAddress.email.isValidEmail()) {
      toList.add(mailAddress);
    }
    if (bcclist.contains(mailAddress)) {
      bcclist.remove(mailAddress);
    }
    if (cclist.contains(mailAddress)) {
      cclist.remove(mailAddress);
    }
  }

  void removeFromToList(int index) => toList.removeAt(index);

  void addToCC(MailAddress mailAddress) {
    if (cclist.any((e) => e.email == mailAddress.email)) {
      return;
    } else if (mailAddress.email.isValidEmail()) {
      cclist.add(mailAddress);
    }
    if (toList.contains(mailAddress)) {
      toList.remove(mailAddress);
    }
    if (bcclist.contains(mailAddress)) {
      bcclist.remove(mailAddress);
    }
  }

  void removeFromCcList(int index) => cclist.removeAt(index);

  void addToBcc(MailAddress mailAddress) {
    if (bcclist.any((e) => e.email == mailAddress.email)) {
      return;
    } else if (mailAddress.email.isValidEmail()) {
      bcclist.add(mailAddress);
    }
    if (toList.contains(mailAddress)) {
      toList.remove(mailAddress);
    }
    if (cclist.contains(mailAddress)) {
      cclist.remove(mailAddress);
    }
  }

  void removeFromBccList(int index) => bcclist.removeAt(index);

  final storage = GetStorage();

  // Constant for the email address
  String get email => account.email;
  String get name => storage.read('accountName') ?? account.name;

  final settingController = Get.find<SettingController>();

  MimeMessage? msg;

  @override
  void onInit() {
    if (Get.arguments != null) {
      String? type = Get.arguments['type'];
      msg = Get.arguments['message'];
      String? toMails = Get.arguments['to'];
      String? support = Get.arguments['support'];
      if (toMails != null) {
        toMails.split(' ').forEach((e) {
          toList.add(MailAddress("", e));
        });
      }
      if (support != null) {
        toList.add(MailAddress("", support));
        messageBuilder = MessageBuilder();
      }
      if (msg != null) {
        if (type == 'reply') {
          toList.addAll(msg!.from ?? []);
          subjectController.text = 'Re: ${msg!.decodeSubject()}';
          signature = settingController.signatureReply()
              ? settingController.signature()
              : '';
          messageBuilder = MessageBuilder.prepareReplyToMessage(
            msg!,
            MailAddress(name, email),
          );
        } else if (type == 'reply_all') {
          toList.addAll(msg!.to ?? []);
          cclist.addAll(msg!.cc ?? []);
          bcclist.addAll(msg!.bcc ?? []);
          subjectController.text = 'Re: ${msg!.decodeSubject()}';
          signature = settingController.signatureReply()
              ? settingController.signature()
              : '';

          messageBuilder = MessageBuilder.prepareReplyToMessage(
            msg!,
            MailAddress(name, email),
            replyAll: true,
          );
        } else if (type == 'forward') {
          subjectController.text = 'Fwd: ${msg!.decodeSubject()}';
          signature = settingController.signatureForward()
              ? settingController.signature()
              : '';
          messageBuilder = MessageBuilder.prepareForwardMessage(msg!);
        } else if (type == 'draft') {
          toList.addAll(msg!.to ?? []);
          cclist.addAll(msg!.cc ?? []);
          bcclist.addAll(msg!.bcc ?? []);
          subjectController.text = '${msg!.decodeSubject()}';
          signature = settingController.signatureNewMessage()
              ? settingController.signature()
              : '';
          messageBuilder = MessageBuilder.prepareFromDraft(msg!);
        }
        bodyPart =
            (msg!.decodeTextHtmlPart() ?? msg!.decodeTextPlainPart() ?? '');
        printInfo(info: "Init body part $bodyPart");
      }
    } else {
      signature = settingController.signatureNewMessage()
          ? settingController.signature()
          : '';
      messageBuilder = MessageBuilder();
    }
    if (name.isNotEmpty) {
      fromController.text = "$name <$email>";
    } else {
      fromController.text = email;
    }
    super.onInit();
  }

  // pick files from the device
  Future<void> pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (result != null) {
      for (PlatformFile file in result.files) {
        attachments.add(File(file.path!));
      }
    }
  }

  // Image picker from the device
  Future<void> pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null) {
      for (PlatformFile file in result.files) {
        attachments.add(File(file.path!));
      }
    }
  }

  Future<void> saveAsDraft() async {
    try {
      EasyLoading.showInfo('Saving as draft...');
      // attach the signature to the email
      late String body;
      if (isHtml.value) {
        body = (await htmlController.getText()) + signature;
      } else {
        body = plainTextController.text + signature;
      }
      // attach the files to the email
      for (var file in attachments) {
        messageBuilder.addFile(file, MediaType.guessFromFileName(file.path));
      }
      // set the email body
      messageBuilder.addMultipartAlternative(
        htmlText: "<p>$body</p>",
        plainText: body,
      );
      messageBuilder.to = toList.toList();
      messageBuilder.cc = cclist.toList();
      messageBuilder.bcc = bcclist.toList();
      messageBuilder.subject = subjectController.text;
      messageBuilder.from = [MailAddress(name, email)];
      final boxController = Get.find<MailBoxController>();
      final box = boxController.mailboxes.firstWhere(
        (e) => e.name.toLowerCase() == 'drafts',
      );
      if (msg != null) {
        await boxController.deleteMails([msg!], box);
      }
      MimeMessage draftMessage = messageBuilder.buildMimeMessage();
      await client.saveDraftMessage(draftMessage);
      canPop(true);
    } catch (e) {
      AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.error,
        title: 'error'.tr,
        desc: e.toString(),
      ).show();
    } finally {
      EasyLoading.dismiss();
    }
  }

  // Send the email with attachments
  Future<void> sendEmail() async {
    try {
      EasyLoading.showInfo('Sending email...');
      if (toList.isEmpty) {
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.error,
          title: 'error'.tr,
          desc: 'add_a_recipient'.tr,
        ).show();
        return;
      } else if (subjectController.text.isEmpty) {
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.error,
          title: 'error'.tr,
          desc: 'valid_subject'.tr,
        ).show();
        return;
      }
      // attach the signature to the email
      late String body;
      if (isHtml.value) {
        body = (await htmlController.getText()) + signature;
      } else {
        body = plainTextController.text + signature;
      }
      // attach the files to the email
      for (var file in attachments) {
        messageBuilder.addFile(file, MediaType.guessFromFileName(file.path));
      }
      // set the email body
      messageBuilder.addMultipartAlternative(
        htmlText: "<p>$body</p>",
        plainText: body,
      );
      messageBuilder.to = toList.toList();
      messageBuilder.cc = cclist.toList();
      messageBuilder.bcc = bcclist.toList();
      messageBuilder.subject = subjectController.text;
      messageBuilder.from = [MailAddress(name, email)];
      if (settingController.readReceipts()) {
        messageBuilder.requestReadReceipt();
      }
      if (msg != null) {
        await client.deleteMessage(msg!);
      }
      // send the email
      await client.sendMessage(
        messageBuilder.buildMimeMessage(),
        recipients: toList.toList(),
      );
      Get.back();
      AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.success,
        title: 'Success',
        desc: 'msg_email_sent'.tr,
      ).show();
      canPop(true);
      Get.back();
    } catch (e) {
      AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.error,
        title: 'error'.tr,
        desc: e.toString(),
        btnOk: ElevatedButton(
          onPressed: () {
            Get.back();
            sendEmail();
          },
          child: Text('try_again'.tr),
        ),
      ).show();
    } finally {
      EasyLoading.dismiss();
    }
  }

  void deleteAttachment(int index) {
    attachments.removeAt(index);
  }

  // Html and plain text conversion
  TextEditingController plainTextController = TextEditingController();
  RxBool isHtml = true.obs;
  String htmlBody = '';
  Future togglePlainHtml() async {
    if (isHtml.value) {
      htmlBody = await htmlController.getText();
      String plainText = removeAllHtmlTags(htmlBody);
      plainTextController.text = plainText;
    } else {
      String text = plainTextController.text;
      htmlController.setText(text);
    }
    isHtml.toggle();
  }

  String removeAllHtmlTags(String htmlText) {
    return Bidi.stripHtmlIfNeeded(htmlText);
  }
}
