import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';
import '../models/draft_model.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:wahda_bank/app/controllers/email_operation_controller.dart';
import 'package:wahda_bank/app/controllers/mailbox_list_controller.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:get_storage/get_storage.dart';


extension EmailValidator on String {
  bool isValidEmail() {
    return RegExp(
        r"[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?")
        .hasMatch(this);
  }
}

class ComposeController extends GetxController {
  // Email client and account
  final MailAccount account = MailService.instance.account;
  final MailClient client = MailService.instance.client;

  // Recipients
  final RxList<MailAddress> toList = <MailAddress>[].obs;
  final RxList<MailAddress> cclist = <MailAddress>[].obs;
  final RxList<MailAddress> bcclist = <MailAddress>[].obs;

  // Form controllers
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController fromController = TextEditingController();
  final TextEditingController plainTextController = TextEditingController();
  final HtmlEditorController htmlController = HtmlEditorController();

  // Message builder and content
  late MessageBuilder messageBuilder;
  final RxList<File> attachments = <File>[].obs;
  String bodyPart = '';
  String signature = '';

  // UI state
  final RxBool canPop = false.obs;
  final RxBool isCcAndBccVisible = false.obs;
  final RxBool isHtml = true.obs;
  final RxBool isBusy = false.obs;

  // Draft state
  final RxBool _hasUnsavedChanges = false.obs;
  bool get hasUnsavedChanges => _hasUnsavedChanges.value;

  final RxString _draftStatus = ''.obs;
  String get draftStatus => _draftStatus.value;

  final RxBool _isAutosaving = false.obs;
  bool get isAutosaving => _isAutosaving.value;

  final RxString _lastSavedTime = ''.obs;
  String get lastSavedTime => _lastSavedTime.value;

  final RxBool _showDraftOptions = false.obs;
  bool get showDraftOptions => _showDraftOptions.value;

  Timer? _autosaveTimer;
  Timer? _statusClearTimer;
  DraftModel? _currentDraft;
  DateTime? _lastChangeTime;
  int _changeCounter = 0;

  // Original message data
  MimeMessage? msg;
  String? type;

  // Contact suggestions
  List<MailAddress> get mailAddresses =>
      (GetStorage().read('mails') ?? []).map<MailAddress>((e) {
        return MailAddress.parse(e.toString());
      }).toList();

  @override
  void onInit() {
    super.onInit();
    _initializeController();
    _setupAutosave();
    _setupChangeListeners();
    _checkForRecovery();
  }

  void _initializeController() {
    final args = Get.arguments;

    if (args != null) {
      type = args['type'];
      msg = args['message'];
      String? toMails = args['to'];
      String? support = args['support'];

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
        final settingController = Get.find<SettingController>();

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
          subjectController.text = msg!.decodeSubject() ?? '';
          signature = settingController.signatureNewMessage()
              ? settingController.signature()
              : '';
          messageBuilder = MessageBuilder.prepareFromDraft(msg!);

          // Load draft from storage
          _loadDraftFromMessage(msg!);
        }

        bodyPart = msg!.decodeTextHtmlPart() ?? msg!.decodeTextPlainPart() ?? '';
      } else {
        final settingController = Get.find<SettingController>();
        signature = settingController.signatureNewMessage()
            ? settingController.signature()
            : '';
        messageBuilder = MessageBuilder();
      }
    } else {
      final settingController = Get.find<SettingController>();
      signature = settingController.signatureNewMessage()
          ? settingController.signature()
          : '';
      messageBuilder = MessageBuilder();
    }

    // Set from field
    if (name.isNotEmpty) {
      fromController.text = "$name <$email>";
    } else {
      fromController.text = email;
    }

    // Initialize HTML editor with content
    if (bodyPart.isNotEmpty) {
      // Use Future.delayed to ensure the HTML editor is initialized
      Future.delayed(Duration.zero, () {
        htmlController.setText(bodyPart);
        plainTextController.text = _removeHtmlTags(bodyPart);
      });
    }
  }

  // Getters for user info
  String get email => account.email;
  String get name => account.name;

  // Setup autosave timer
  void _setupAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_hasUnsavedChanges.value && _shouldAutosave()) {
        _autosaveDraft();
      }
    });
  }

  // Determine if autosave should run based on time since last change
  bool _shouldAutosave() {
    if (_lastChangeTime == null) return false;

    // If it's been at least 3 seconds since the last change
    return DateTime.now().difference(_lastChangeTime!).inSeconds >= 3;
  }

  // Setup change listeners for all form fields
  void _setupChangeListeners() {
    // Listen for changes to mark as unsaved
    subjectController.addListener(_markAsChanged);
    plainTextController.addListener(_markAsChanged);

    // Listen for changes in observable lists
    toList.listen((_) => _markAsChanged());
    cclist.listen((_) => _markAsChanged());
    bcclist.listen((_) => _markAsChanged());
    attachments.listen((_) => _markAsChanged());

    // Show draft options when there's content
    ever(_hasUnsavedChanges, (value) {
      _showDraftOptions.value = value || _currentDraft != null;
    });
  }

  // Mark content as changed and needing save
  void _markAsChanged() {
    _hasUnsavedChanges.value = true;
    _lastChangeTime = DateTime.now();
    _changeCounter++;

    // Update status
    _draftStatus.value = 'unsaved_changes'.tr;

    // Clear any previous status clear timer
    _statusClearTimer?.cancel();

    // If we've accumulated several changes, trigger an autosave
    if (_changeCounter >= 10) {
      _changeCounter = 0;
      if (!_isAutosaving.value) {
        _autosaveDraft();
      }
    }

    update();
  }

  // Called when HTML content changes
  void onContentChanged() {
    _markAsChanged();
  }

  // Autosave draft with status updates
  Future<void> _autosaveDraft() async {
    if (!_hasUnsavedChanges.value || isBusy.value || _isAutosaving.value) return;

    try {
      _isAutosaving.value = true;
      _draftStatus.value = 'saving_draft'.tr;
      update();

      // Get current content
      late String body;
      if (isHtml.value) {
        body = await htmlController.getText();
      } else {
        body = plainTextController.text;
      }

      // Check if there's enough content to save
      if (!_hasSaveableContent(body)) {
        _draftStatus.value = '';
        _isAutosaving.value = false;
        return;
      }

      // Create draft model
      final draft = _createDraftModel(body);

      // Save to storage
      final storage = Get.find<SqliteMimeStorage>();
      final savedDraft = await storage.saveDraft(draft);

      // Update current draft reference
      _currentDraft = saveDraft as DraftModel?;
      _hasUnsavedChanges.value = false;
      _changeCounter = 0;
      _draftStatus.value = 'draft_saved'.tr;
      _lastSavedTime.value = _formatSaveTime(DateTime.now());
      _showDraftOptions.value = true;

      // Reset status message after a delay
      _statusClearTimer?.cancel();
      _statusClearTimer = Timer(const Duration(seconds: 3), () {
        if (_draftStatus.value == 'draft_saved'.tr) {
          _draftStatus.value = '';
        }
      });

    } catch (e) {
      debugPrint('Autosave error: $e');
      _draftStatus.value = 'save_error'.tr;
    } finally {
      _isAutosaving.value = false;
      update();
    }
  }

  // Create a draft model from current state
  DraftModel _createDraftModel(String body) {
    return DraftModel(
      id: _currentDraft?.id,
      messageId: _currentDraft?.messageId,
      subject: subjectController.text,
      body: body,
      isHtml: isHtml.value,
      to: toList.map((e) => '${e.personalName ?? ""} <${e.email}>').toList(),
      cc: cclist.map((e) => '${e.personalName ?? ""} <${e.email}>').toList(),
      bcc: bcclist.map((e) => '${e.personalName ?? ""} <${e.email}>').toList(),
      attachmentPaths: attachments.map((e) => e.path).toList(),
      createdAt: _currentDraft?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      version: (_currentDraft?.version ?? 0) + 1,
      category: _currentDraft?.category ?? 'default',
      priority: _currentDraft?.priority ?? 0,
      isSynced: false,
      isDirty: true,
      tags: _currentDraft?.tags ?? [],
    );
  }

  // Format save time for display
  String _formatSaveTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'just_now'.tr;
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${'minutes_ago'.tr}';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${'hours_ago'.tr}';
    } else {
      return '${difference.inDays} ${'days_ago'.tr}';
    }
  }

  // Check if there's content to save as draft
  bool _hasSaveableContent(String body) {
    return subjectController.text.isNotEmpty ||
        body.isNotEmpty ||
        toList.isNotEmpty ||
        cclist.isNotEmpty ||
        bcclist.isNotEmpty ||
        attachments.isNotEmpty;
  }

  // Check for any recoverable drafts
  Future<void> _checkForRecovery() async {
    try {
      final storage = Get.find<SqliteMimeStorage>();
// manually fetch all and filter
      final all = await storage.getDrafts();
      final dirtyDrafts = all.where((d) => d.isDirty).toList();

      if (dirtyDrafts.isNotEmpty && type != 'draft') {
        // Found unsaved drafts, offer recovery
        final mostRecent = dirtyDrafts.first;

        // Show recovery dialog
        Get.dialog(
          AlertDialog(
            title: Text('recover_draft'.tr),
            content: Text('unsaved_draft_found'.tr),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back();
                },
                child: Text('discard'.tr),
              ),
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  _recoverDraft(mostRecent);
                },
                child: Text('recover'.tr),
              ),
            ],
          ),
          barrierDismissible: false,
        );
      }
    } catch (e) {
      debugPrint('Error checking for draft recovery: $e');
    }
  }

  // Recover a draft
  void _recoverDraft(DraftModel draft) {
    // Update current draft reference
    _currentDraft = draft;

    // Populate form fields
    subjectController.text = draft.subject;

    // Populate recipients
    toList.clear();
    cclist.clear();
    bcclist.clear();

    for (final recipient in draft.to) {
      final address = _parseMailAddress(recipient);
      if (address != null) {
        toList.add(address);
      }
    }

    for (final recipient in draft.cc) {
      final address = _parseMailAddress(recipient);
      if (address != null) {
        cclist.add(address);
      }
    }

    for (final recipient in draft.bcc) {
      final address = _parseMailAddress(recipient);
      if (address != null) {
        bcclist.add(address);
      }
    }

    // Set content
    if (draft.isHtml) {
      isHtml.value = true;
      htmlController.setText(draft.body);
    } else {
      isHtml.value = false;
      plainTextController.text = draft.body;
    }

    // Load attachments
    attachments.clear();
    for (final path in draft.attachmentPaths) {
      final file = File(path);
      if (file.existsSync()) {
        attachments.add(file);
      }
    }

    // Update UI state
    _hasUnsavedChanges.value = false;
    _draftStatus.value = 'draft_recovered'.tr;
    _lastSavedTime.value = _formatSaveTime(draft.updatedAt);
    _showDraftOptions.value = true;

    // Show toast
    EasyLoading.showSuccess('draft_recovered'.tr);

    update();
  }

  // Parse mail address from string
  MailAddress? _parseMailAddress(String address) {
    try {
      final match = RegExp(r'(.*) <(.*)>').firstMatch(address);
      if (match != null && match.group(2) != null) {
        final name = match.group(1) ?? '';
        final email = match.group(2)!;
        return MailAddress(name, email);
      } else {
        return MailAddress('', address);
      }
    } catch (e) {
      debugPrint('Error parsing mail address: $e');
      return null;
    }
  }

  // Load draft from message
  Future<void> _loadDraftFromMessage(MimeMessage message) async {
    try {
      final storage = Get.find<SqliteMimeStorage>();

      // Get message ID from headers for enough_mail 2.1.6
      String? messageId;
      try {
        messageId = message.getHeaderValue('message-id')?.replaceAll('<', '').replaceAll('>', '');
      } catch (e) {
        messageId = '';
      }

      final all = await storage.getDrafts();
      final draft = all.firstWhereOrNull((d) => d.messageId == messageId);


      if (draft != null) {
        _currentDraft = draft;
        _lastSavedTime.value = _formatSaveTime(draft.updatedAt);
        _showDraftOptions.value = true;

        // Load attachments
        for (final path in draft.attachmentPaths) {
          final file = File(path);
          if (await file.exists()) {
            attachments.add(file);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading draft: $e');
    }
  }

  // Add recipient to To field
  void addTo(MailAddress mailAddress) {
    if (!toList.any((e) => e.email == mailAddress.email)) {
      toList.add(mailAddress);
    }
  }

  // Add recipient to CC field
  void addCc(MailAddress mailAddress) {
    if (!cclist.any((e) => e.email == mailAddress.email)) {
      cclist.add(mailAddress);
    }
  }

  // Add recipient to BCC field
  void addBcc(MailAddress mailAddress) {
    if (!bcclist.any((e) => e.email == mailAddress.email)) {
      bcclist.add(mailAddress);
    }
  }

  // Remove recipient from To field
  void removeTo(MailAddress mailAddress) {
    toList.removeWhere((e) => e.email == mailAddress.email);
  }

  // Remove recipient from CC field
  void removeCc(MailAddress mailAddress) {
    cclist.removeWhere((e) => e.email == mailAddress.email);
  }

  /// In ComposeController

  /// Schedule this draft to send at [when].
  Future<void> scheduleDraft(DateTime when) async {
    if (_currentDraft == null) return;

    // 1) update the in-memory draft model
    _currentDraft = _currentDraft!.copyWith(
      isScheduled: true,
      scheduledFor: when,
      updatedAt: DateTime.now(),
    );
    _markAsChanged(); // mark dirty and trigger UI update

    // 2) persist to your SqliteMimeStorage
    final storage = Get.find<SqliteMimeStorage>();
    await storage.saveDraft(_currentDraft!);

    // 3) update status indicator
    _draftStatus.value = 'scheduled_for'.trArgs([DateFormat.yMd().add_jm().format(when)]);
    update();
  }

  /// Change the category of this draft to [category].
  Future<void> categorizeDraft(String category) async {
    if (_currentDraft == null) return;

    // 1) update the in-memory draft model
    _currentDraft = _currentDraft!.copyWith(
      category: category,
      updatedAt: DateTime.now(),
    );
    _markAsChanged();

    // 2) persist to your SqliteMimeStorage
    final storage = Get.find<SqliteMimeStorage>();
    await storage.saveDraft(_currentDraft!);

    // 3) update status indicator briefly
    _draftStatus.value = 'category_set_to'.trArgs([category]);
    update();

    // clear the status after 2s
    Future.delayed(const Duration(seconds:2), () {
      if (_draftStatus.value.startsWith('category_set_to')) {
        _draftStatus.value = '';
        update();
      }
    });
  }

  // Remove recipient from BCC field
  void removeBcc(MailAddress mailAddress) {
    bcclist.removeWhere((e) => e.email == mailAddress.email);
  }

  // Toggle CC and BCC visibility
  void toggleCcBcc() {
    isCcAndBccVisible.value = !isCcAndBccVisible.value;
  }

  // Toggle HTML mode
  void toggleHtmlMode() async {
    if (isHtml.value) {
      // Switching from HTML to plain text
      final htmlText = await htmlController.getText();
      plainTextController.text = _removeHtmlTags(htmlText);
    } else {
      // Switching from plain text to HTML
      final plainText = plainTextController.text;
      htmlController.setText(_convertToHtml(plainText));
    }

    isHtml.value = !isHtml.value;
    _markAsChanged();
  }

  // Convert plain text to HTML
  String _convertToHtml(String text) {
    // Replace newlines with <br> tags
    return text.replaceAll('\n', '<br>');
  }

  // Remove HTML tags from text
  String _removeHtmlTags(String html) {
    // Simple HTML tag removal
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  // Add attachment from file picker
  Future<void> addAttachment() async {
    try {
      isBusy.value = true;
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        for (final file in result.files) {
          if (file.path != null) {
            attachments.add(File(file.path!));
          }
        }
      }
    } catch (e) {
      debugPrint('Error adding attachment: $e');
      EasyLoading.showError('error_adding_attachment'.tr);
    } finally {
      isBusy.value = false;
    }
  }

  // Add image from camera
  Future<void> addImageFromCamera() async {
    try {
      isBusy.value = true;
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        attachments.add(File(pickedFile.path));
      }
    } catch (e) {
      debugPrint('Error adding image from camera: $e');
      EasyLoading.showError('error_adding_image'.tr);
    } finally {
      isBusy.value = false;
    }
  }

  // Add image from gallery
  Future<void> addImageFromGallery() async {
    try {
      isBusy.value = true;
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        attachments.add(File(pickedFile.path));
      }
    } catch (e) {
      debugPrint('Error adding image from gallery: $e');
      EasyLoading.showError('error_adding_image'.tr);
    } finally {
      isBusy.value = false;
    }
  }

  // Remove attachment
  void removeAttachment(File file) {
    attachments.remove(file);
  }

  // Save draft
  Future<bool> saveDraft() async {
    try {
      isBusy.value = true;
      _draftStatus.value = 'saving_draft'.tr;
      update();

      // Get current content
      late String body;
      if (isHtml.value) {
        body = await htmlController.getText();
      } else {
        body = plainTextController.text;
      }

      // Check if there's enough content to save
      if (!_hasSaveableContent(body)) {
        _draftStatus.value = 'draft_empty'.tr;
        return false;
      }

      // Create draft model
      final draft = _createDraftModel(body);

      // Save to storage
      final storage = Get.find<SqliteMimeStorage>();
      final savedDraft = await storage.saveDraft(draft);

      // Update current draft reference
      _currentDraft = savedDraft as DraftModel?;
      _hasUnsavedChanges.value = false;
      _changeCounter = 0;
      _draftStatus.value = 'draft_saved'.tr;
      _lastSavedTime.value = _formatSaveTime(DateTime.now());
      _showDraftOptions.value = true;

      // Show success message
      EasyLoading.showSuccess('draft_saved'.tr);

      return true;
    } catch (e) {
      debugPrint('Error saving draft: $e');
      _draftStatus.value = 'save_error'.tr;
      EasyLoading.showError('error_saving_draft'.tr);
      return false;
    } finally {
      isBusy.value = false;
      update();
    }
  }

  // Send email
  Future<bool> sendEmail() async {
    try {
      isBusy.value = true;
      EasyLoading.show(status: 'sending_email'.tr);

      // Validate recipients
      if (toList.isEmpty && cclist.isEmpty && bcclist.isEmpty) {
        EasyLoading.showError('no_recipients'.tr);
        return false;
      }

      // Get current content
      late String body;
      if (isHtml.value) {
        body = await htmlController.getText();
      } else {
        body = plainTextController.text;
      }

      // Create message builder
      messageBuilder = MessageBuilder();
      messageBuilder.from = [MailAddress(name, email)];
      messageBuilder.to = toList;
      messageBuilder.cc = cclist;
      messageBuilder.bcc = bcclist;
      messageBuilder.subject = subjectController.text;

      // Add content
      if (isHtml.value) {
        messageBuilder.addMultipartAlternative(
          htmlText: body,
          plainText: _removeHtmlTags(body),
        );
      } else {
        messageBuilder.addTextPlain(body);
      }

      // Add attachments
      for (final file in attachments) {
        final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
        await messageBuilder.addFile(file, mimeType as MediaType);
      }

      // Build message
      final mimeMessage = messageBuilder.buildMimeMessage();

      // Send message
      final operationController = Get.find<EmailOperationController>();
      final sentBox = Get.find<MailboxListController>().getMailboxByType(isSent: true);
      final success = await operationController.sendMessage(mimeMessage, sentMailbox: sentBox);

      if (success) {
        // Delete draft if it exists
        if (_currentDraft != null) {
          final storage = Get.find<SqliteMimeStorage>();
          await storage.deleteDraft(_currentDraft!.id!);
        }

        // Show success message
        EasyLoading.showSuccess('email_sent'.tr);

        // Clear form
        _clearForm();

        return true;
      } else {
        EasyLoading.showError('error_sending_email'.tr);
        return false;
      }
    } catch (e) {
      debugPrint('Error sending email: $e');
      EasyLoading.showError('error_sending_email'.tr);
      return false;
    } finally {
      isBusy.value = false;
    }
  }

  // Clear form
  void _clearForm() {
    subjectController.clear();
    plainTextController.clear();
    htmlController.setText('');
    toList.clear();
    cclist.clear();
    bcclist.clear();
    attachments.clear();
    _currentDraft = null;
    _hasUnsavedChanges.value = false;
    _draftStatus.value = '';
    _lastSavedTime.value = '';
    _showDraftOptions.value = false;
    update();
  }

  // Discard draft
  Future<bool> discardDraft() async {
    try {
      // Show confirmation dialog
      final result = await Get.dialog<bool>(
        AlertDialog(
          title: Text('discard_draft'.tr),
          content: Text('discard_draft_confirm'.tr),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('cancel'.tr),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: Text('discard'.tr),
            ),
          ],
        ),
        barrierDismissible: false,
      );

      if (result != true) return false;

      // Delete draft if it exists
      if (_currentDraft != null && _currentDraft!.id != null) {
        final storage = Get.find<SqliteMimeStorage>();
        await storage.deleteDraft(_currentDraft!.id!);
      }

      // Clear form
      _clearForm();

      return true;
    } catch (e) {
      debugPrint('Error discarding draft: $e');
      return false;
    }
  }

  // Check if can pop
  Future<bool> checkCanPop() async {
    if (!_hasUnsavedChanges.value) {
      return true;
    }

    // Show confirmation dialog
    final result = await Get.dialog<String>(
      AlertDialog(
        title: Text('unsaved_changes'.tr),
        content: Text('unsaved_changes_confirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: 'discard'),
            child: Text('discard'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: 'cancel'),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: 'save'),
            child: Text('save'.tr),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    if (result == 'save') {
      return await saveDraft();
    } else if (result == 'discard') {
      return true;
    } else {
      return false;
    }
  }

  @override
  void onClose() {
    _autosaveTimer?.cancel();
    _statusClearTimer?.cancel();
    subjectController.dispose();
    fromController.dispose();
    plainTextController.dispose();
    super.onClose();
  }
}
