import 'dart:io';
import 'dart:convert' as convert;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:injectable/injectable.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:wahda_bank/features/messaging/presentation/api/compose_controller_api.dart';
import 'package:wahda_bank/shared/di/injection.dart';
import 'package:wahda_bank/features/messaging/application/usecases/send_email.dart' as app;
import 'package:wahda_bank/features/messaging/domain/entities/outbox_item.dart' as dom;

/// ComposeViewModel (P12.4) — temporary adapter exposing the surface the UI needs,
/// forwarding to the legacy ComposeController under the hood. This keeps the app
/// buildable while we complete the migration and then delete the controller.
@lazySingleton
class ComposeViewModel extends GetxController {
  ComposeController get _c =>
      Get.isRegistered<ComposeController>() ? Get.find<ComposeController>() : Get.put(ComposeController());

  // Controllers
  TextEditingController get subjectController => _c.subjectController;
  TextEditingController get plainTextController => _c.plainTextController;
  // Body convenience alias used by some UIs
  TextEditingController get bodyController => _c.plainTextController;

  // HTML editor
  HtmlEditorController get htmlController => _c.htmlController;
  String get bodyPart => _c.bodyPart;
  set bodyPart(String v) => _c.bodyPart = v;

  // Recipients
  RxList<MailAddress> get toList => _c.toList;
  RxList<MailAddress> get cclist => _c.cclist;
  RxList<MailAddress> get bcclist => _c.bcclist;
  List<MailAddress> get mailAddresses => _c.mailAddresses;

  // User info
  String get name => _c.name;
  String get email => _c.email;

  // Flags/state
  RxBool get isHtml => _c.isHtml;
  RxBool get isBusy => _c.isBusy;
  RxBool get isSending => _c.isSending;
  bool get hasUnsavedChanges => _c.hasUnsavedChanges;
  set hasUnsavedChanges(bool v) => _c.hasUnsavedChanges = v;
  String get lastSavedTime => _c.lastSavedTime;

  // Draft state and status
  int? get currentDraftId => _c.currentDraftId;
  set currentDraftId(int? v) => _c.currentDraftId = v;
  String get draftStatus => _c.draftStatus;
  String get signature => _c.signature;

  // Attachments
  RxList<File> get attachments => _c.attachments;
  RxList<DraftAttachmentMeta> get pendingDraftAttachments => _c.pendingDraftAttachments;

  // Misc UI flags
  RxBool get isCcAndBccVisible => _c.isCcAndBccVisible;
  // Helper to read as bool without ".value"
  bool isCcAndBccVisibleValue() => _c.isCcAndBccVisible.value;
  RxInt get priority => _c.priority;

  // Actions (forwarders)
  Future<void> togglePlainHtml() async => _c.togglePlainHtml();
  void addTo(MailAddress a) => _c.addTo(a);
  void addToCC(dynamic a) => _c.addToCC(a);
  void addToBcc(dynamic a) => _c.addToBcc(a);
  void removeFromToList(dynamic x) => _c.removeFromToList(x);
  void removeFromCcList(dynamic x) => _c.removeFromCcList(x);
  void removeFromBccList(dynamic x) => _c.removeFromBccList(x);

  Future<void> saveAsDraft() => _c.saveAsDraft();
  Future<void> discardCurrentDraft() => _c.discardCurrentDraft();
  Future<void> sendEmail() => _c.sendEmail();
  Future<void> scheduleDraft(DateTime when) async => _c.scheduleDraft(when);
  Future<void> categorizeDraft(String category) async => _c.categorizeDraft(category);

  // Pending draft attachments actions
  void reattachAllPendingAttachments() => _c.reattachAllPendingAttachments();
  void reattachPendingAttachment(DraftAttachmentMeta m) => _c.reattachPendingAttachment(m);
  void viewPendingAttachment(DraftAttachmentMeta m) => _c.viewPendingAttachment(m);

  // HTML editor helpers
  void markHtmlEditorReady() => _c.markHtmlEditorReady();
  void onContentChanged() => _c.onContentChanged();

  // Compose context helpers
  void setEditingDraftContext({int? uid, Mailbox? mailbox}) => _c.setEditingDraftContext(uid: uid, mailbox: mailbox);

  // File pickers
  Future<void> pickFiles() => _c.pickFiles();
  Future<void> pickImage() => _c.pickImage();

  // Navigation helpers
  bool canPop() => _c.canPop();

  // DDD send orchestration invoked by legacy controller
  Future<bool> send({
    required ComposeController controller,
    required MimeMessage builtMessage,
    required String requestId,
  }) async {
    try {
      final accountId = controller.accountEmail;
      final folderId = controller.sourceMailbox?.encodedPath ??
          controller.sourceMailbox?.name ??
          'INBOX';
      final messageId = builtMessage.getHeaderValue('Message-Id') ??
          'mid-${DateTime.now().microsecondsSinceEpoch}';
      // Try to render bytes; fall back to empty if not available in current stack
      List<int> rawBytes = <int>[];
      try {
        final dynamic rendered = (builtMessage as dynamic).renderMessage();
        if (rendered is String) {
          rawBytes = convert.utf8.encode(rendered);
        } else if (rendered is List<int>) {
          rawBytes = rendered;
        }
      } catch (_) {}

      final uc = app.SendEmail(
        drafts: getIt(),
        outbox: getIt(),
        smtp: getIt(),
      );
      final res = await uc(
        accountId: accountId,
        folderId: folderId,
        draftId: controller.composeSessionId,
        messageId: messageId,
        rawBytes: rawBytes,
      );
      return res.status != dom.OutboxStatus.failed;
    } catch (_) {
      return false;
    }
  }
}
