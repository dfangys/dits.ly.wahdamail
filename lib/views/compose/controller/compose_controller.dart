import 'dart:io';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:html_editor_enhanced/html_editor.dart';
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
  String body = '';
  String signature = '';

  RxBool isCcAndBccVisible = false.obs;

  void addTo(MailAddress mailAddress) {
    if (toList.isNotEmpty && toList[0] == mailAddress) return;

    // regex to check if the email is valid
    if (mailAddress.email.isValidEmail()) {
      toList.add(mailAddress);
    }
  }

  void removeFromToList(int index) => toList.removeAt(index);

  void addToCC(MailAddress mailAddress) {
    if (cclist.isNotEmpty && cclist[0] == mailAddress) return;
    if (mailAddress.email.isValidEmail()) cclist.add(mailAddress);
  }

  void removeFromCcList(int index) => cclist.removeAt(index);

  void addToBcc(MailAddress mailAddress) {
    if (bcclist.isNotEmpty && bcclist[0] == mailAddress) return;
    if (mailAddress.email.isValidEmail()) bcclist.add(mailAddress);
  }

  void removeFromBccList(int index) => bcclist.removeAt(index);

  final storage = GetStorage();

  // Constant for the email address
  String get email => account.email;
  String get name => storage.read('accountName') ?? account.name;

  final settingController = Get.find<SettingController>();

  @override
  void onInit() {
    if (Get.arguments != null) {
      String? type = Get.arguments['type'];
      MimeMessage? msg = Get.arguments['message'];
      if (msg != null) {
        if (type == 'reply') {
          toList.addAll(msg.from ?? []);
          subjectController.text = 'Re: ${msg.decodeSubject()}';
          signature = settingController.signatureReply()
              ? settingController.signature()
              : '';
          messageBuilder = MessageBuilder.prepareReplyToMessage(
            msg,
            MailAddress(name, email),
          );
        } else if (type == 'reply_all') {
          toList.addAll(msg.to ?? []);
          cclist.addAll(msg.cc ?? []);
          bcclist.addAll(msg.bcc ?? []);
          subjectController.text = 'Re: ${msg.decodeSubject()}';
          signature = settingController.signatureReply()
              ? settingController.signature()
              : '';

          messageBuilder = MessageBuilder.prepareReplyToMessage(
            msg,
            MailAddress(name, email),
            replyAll: true,
          );
        } else if (type == 'forward') {
          subjectController.text = 'Fwd: ${msg.decodeSubject()}';
          signature = settingController.signatureForward()
              ? settingController.signature()
              : '';
          messageBuilder = MessageBuilder.prepareForwardMessage(msg);
        } else if (type == 'draft') {
          toList.addAll(msg.to ?? []);
          cclist.addAll(msg.cc ?? []);
          bcclist.addAll(msg.bcc ?? []);
          subjectController.text = '${msg.decodeSubject()}';
          signature = settingController.signatureNewMessage()
              ? settingController.signature()
              : '';
          messageBuilder = MessageBuilder.prepareFromDraft(msg);
        }
        body = (msg.decodeTextHtmlPart() ?? '');
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
    // attach the signature to the email
    String html = (await htmlController.getText());
    // attach the files to the email
    for (var file in attachments) {
      messageBuilder.addFile(file, MediaType.guessFromFileName(file.path));
    }
    // set the email body
    messageBuilder.addMultipartAlternative(htmlText: html);
    messageBuilder.to = toList.toList();
    messageBuilder.cc = cclist.toList();
    messageBuilder.bcc = bcclist.toList();
    messageBuilder.subject = subjectController.text;
    messageBuilder.from = [MailAddress(name, email)];
    await client.saveDraftMessage(messageBuilder.buildMimeMessage());
    AwesomeDialog(
      context: Get.context!,
      dialogType: DialogType.success,
      title: 'Success',
      desc: 'Email saved as draft successfully',
    ).show();
  }

  // Send the email with attachments
  Future<void> sendEmail() async {
    try {
      if (toList.isEmpty) {
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.error,
          title: 'Error',
          desc: 'add_a_recipient'.tr,
        ).show();
        return;
      } else if (subjectController.text.isEmpty) {
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.error,
          title: 'Error',
          desc: 'valid_subject'.tr,
        ).show();
        return;
      }
      // attach the signature to the email
      String html = (await htmlController.getText()) + signature;
      // attach the files to the email
      for (var file in attachments) {
        messageBuilder.addFile(file, MediaType.guessFromFileName(file.path));
      }
      // set the email body
      messageBuilder.addMultipartAlternative(htmlText: html);
      messageBuilder.to = toList.toList();
      messageBuilder.cc = cclist.toList();
      messageBuilder.bcc = bcclist.toList();
      messageBuilder.subject = subjectController.text;
      messageBuilder.from = [MailAddress(name, email)];
      if (settingController.readReceipts()) {
        messageBuilder.requestReadReceipt();
      }
      // send the email
      await client.startPolling();
      await client.sendMessage(
        messageBuilder.buildMimeMessage(),
        recipients: toList.toList(),
      );
      await client.stopPolling();
      AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.success,
        title: 'Success',
        desc: 'Email sent successfully',
      ).show();
    } catch (e) {
      AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.error,
        title: 'Error',
        desc: e.toString(),
      ).show();
    }
  }
}
