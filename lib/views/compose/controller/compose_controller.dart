import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';
import 'package:wahda_bank/views/compose/models/draft_model.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
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
      _currentDraft = savedDraft;
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
      final dirtyDrafts = await storage.getDirtyDrafts();

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

      final draft = await storage.getDraftByMessageId(messageId ?? '');

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
    if (toList.any((e) => e.email == mailAddress.email)) {
      return;
    } else if (_isValidEmail(mailAddress.email)) {
      toList.add(mailAddress);
    }

    if (bcclist.contains(mailAddress)) {
      bcclist.remove(mailAddress);
    }

    if (cclist.contains(mailAddress)) {
      cclist.remove(mailAddress);
    }

    _markAsChanged();
  }

  // Remove recipient from To field
  void removeFromToList(int index) {
    toList.removeAt(index);
    _markAsChanged();
  }

  // Add recipient to CC field
  void addToCC(MailAddress mailAddress) {
    if (cclist.any((e) => e.email == mailAddress.email)) {
      return;
    } else if (_isValidEmail(mailAddress.email)) {
      cclist.add(mailAddress);
    }

    if (toList.contains(mailAddress)) {
      toList.remove(mailAddress);
    }

    if (bcclist.contains(mailAddress)) {
      bcclist.remove(mailAddress);
    }

    _markAsChanged();
  }

  // Remove recipient from CC field
  void removeFromCcList(int index) {
    cclist.removeAt(index);
    _markAsChanged();
  }

  // Add recipient to BCC field
  void addToBcc(MailAddress mailAddress) {
    if (bcclist.any((e) => e.email == mailAddress.email)) {
      return;
    } else if (_isValidEmail(mailAddress.email)) {
      bcclist.add(mailAddress);
    }

    if (toList.contains(mailAddress)) {
      toList.remove(mailAddress);
    }

    if (cclist.contains(mailAddress)) {
      cclist.remove(mailAddress);
    }

    _markAsChanged();
  }

  // Remove recipient from BCC field
  void removeFromBccList(int index) {
    bcclist.removeAt(index);
    _markAsChanged();
  }

  // Validate email
  bool _isValidEmail(String email) {
    return RegExp(
      r"[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?",
    ).hasMatch(email);
  }

  // Pick files from device
  Future<void> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null) {
        for (final file in result.files) {
          if (file.path != null) {
            attachments.add(File(file.path!));
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
    }
  }

  // Pick images from gallery
  Future<void> pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null) {
        for (final file in result.files) {
          if (file.path != null) {
            attachments.add(File(file.path!));
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  // Take photo with camera
  Future<void> takePhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        attachments.add(File(pickedFile.path));
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
    }
  }

  // Save draft with improved feedback
  Future<void> saveAsDraft() async {
    if (isBusy.value) return;

    try {
      isBusy.value = true;
      _draftStatus.value = 'saving_draft'.tr;
      update();

      // Show loading indicator
      EasyLoading.show(status: 'saving_draft'.tr);

      // Get current content
      late String body;
      if (isHtml.value) {
        body = await htmlController.getText();
      } else {
        body = plainTextController.text;
      }

      // Check if there's enough content to save
      if (!_hasSaveableContent(body)) {
        EasyLoading.dismiss();
        EasyLoading.showInfo('nothing_to_save'.tr);
        _draftStatus.value = '';
        isBusy.value = false;
        return;
      }

      // Add signature if needed
      body += signature;

      // Create draft model
      final draft = _createDraftModel(body);

      // Save to local storage
      final storage = Get.find<SqliteMimeStorage>();
      _currentDraft = await storage.saveDraft(draft);

      // Create message builder for server save
      messageBuilder = MessageBuilder();

      // Add attachments
      for (final file in attachments) {
        await messageBuilder.addFile(
          file,
          MediaType.guessFromFileName(file.path),
        );
      }

      // Set message content
      messageBuilder.addMultipartAlternative(
        htmlText: isHtml.value ? body : null,
        plainText: isHtml.value ? _removeHtmlTags(body) : body,
      );

      // Set message metadata
      messageBuilder.to = toList.toList();
      messageBuilder.cc = cclist.toList();
      messageBuilder.bcc = bcclist.toList();
      messageBuilder.subject = subjectController.text;
      messageBuilder.from = [MailAddress(name, email)];
      messageBuilder.date = DateTime.now();

      // Add custom headers for enhanced draft features
      messageBuilder.addHeader('X-Category', draft.category);
      messageBuilder.addHeader('X-Priority', draft.priority.toString());
      if (draft.tags.isNotEmpty) {
        messageBuilder.addHeader('X-Tags', draft.tags.join(','));
      }
      messageBuilder.addHeader('X-Draft-Version', draft.version.toString());

      // Build message
      final draftMessage = messageBuilder.buildMimeMessage();

      // Save to server
      final box = await client.selectMailboxByFlag(MailboxFlag.drafts);
      final code = await client.saveDraftMessage(draftMessage);

      // Update draft with server info if successful
      if (code != null && _currentDraft != null) {
        await storage.markDraftSynced(_currentDraft!.id!, code.uidValidity ?? 0);
      }

      // Delete old draft if editing
      if (msg != null && type == 'draft') {
        await client.deleteMessage(msg!);
      }

      // Update state
      _hasUnsavedChanges.value = false;
      _draftStatus.value = 'draft_saved'.tr;
      _lastSavedTime.value = _formatSaveTime(DateTime.now());
      _showDraftOptions.value = true;
      canPop.value = true;

      // Show success message
      EasyLoading.dismiss();
      EasyLoading.showSuccess('draft_saved'.tr);

    } catch (e) {
      // Show error message
      EasyLoading.dismiss();

      AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.error,
        title: 'error'.tr,
        desc: e.toString(),
        btnOk: ElevatedButton(
          onPressed: () {
            Get.back();
          },
          child: Text('ok'.tr),
        ),
      ).show();

      _draftStatus.value = 'save_error'.tr;

      // Try to save locally even if server save failed
      if (_currentDraft != null) {
        final storage = Get.find<SqliteMimeStorage>();
        await storage.markDraftSyncError(_currentDraft!.id!, e.toString());
      }
    } finally {
      isBusy.value = false;
      update();
    }
  }

  // Schedule draft to be sent later
  Future<void> scheduleDraft(DateTime scheduledTime) async {
    if (isBusy.value) return;

    try {
      isBusy.value = true;
      _draftStatus.value = 'scheduling_draft'.tr;
      update();

      // Show loading indicator
      EasyLoading.show(status: 'scheduling_draft'.tr);

      // Get current content
      late String body;
      if (isHtml.value) {
        body = await htmlController.getText();
      } else {
        body = plainTextController.text;
      }

      // Check if there's enough content to save
      if (!_hasSaveableContent(body)) {
        EasyLoading.dismiss();
        EasyLoading.showInfo('nothing_to_schedule'.tr);
        _draftStatus.value = '';
        isBusy.value = false;
        return;
      }

      // Add signature if needed
      body += signature;

      // Create draft model with scheduling
      final draft = _createDraftModel(body).copyWith(
        isScheduled: true,
        scheduledFor: scheduledTime,
      );

      // Save to local storage
      final storage = Get.find<SqliteMimeStorage>();
      _currentDraft = await storage.saveDraft(draft);

      // Update state
      _hasUnsavedChanges.value = false;
      _draftStatus.value = 'draft_scheduled'.tr;
      _lastSavedTime.value = _formatSaveTime(DateTime.now());
      _showDraftOptions.value = true;
      canPop.value = true;

      // Show success message
      EasyLoading.dismiss();
      EasyLoading.showSuccess('draft_scheduled'.tr);

    } catch (e) {
      // Show error message
      EasyLoading.dismiss();

      AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.error,
        title: 'error'.tr,
        desc: e.toString(),
        btnOk: ElevatedButton(
          onPressed: () {
            Get.back();
          },
          child: Text('ok'.tr),
        ),
      ).show();

      _draftStatus.value = 'schedule_error'.tr;
    } finally {
      isBusy.value = false;
      update();
    }
  }

  // Categorize draft
  Future<void> categorizeDraft(String category) async {
    if (_currentDraft == null || isBusy.value) return;

    try {
      isBusy.value = true;

      // Update category in storage
      final storage = Get.find<SqliteMimeStorage>();
      await storage.updateDraftCategory(_currentDraft!.id!, category);

      // Update current draft reference
      _currentDraft = _currentDraft!.copyWith(category: category);

      // Show success message
      EasyLoading.showSuccess('category_updated'.tr);
    } catch (e) {
      debugPrint('Error categorizing draft: $e');
      EasyLoading.showError('category_update_error'.tr);
    } finally {
      isBusy.value = false;
    }
  }

  // Send email
  Future<void> sendEmail() async {
    if (isBusy.value) return;

    try {
      isBusy.value = true;
      update();

      // Validate recipients
      if (toList.isEmpty) {
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.error,
          title: 'error'.tr,
          desc: 'add_a_recipient'.tr,
        ).show();
        return;
      }

      // Validate subject
      if (subjectController.text.isEmpty) {
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.error,
          title: 'error'.tr,
          desc: 'valid_subject'.tr,
        ).show();
        return;
      }

      // Show loading indicator
      EasyLoading.show(status: 'sending_email'.tr);

      // Get current content
      late String body;
      if (isHtml.value) {
        body = await htmlController.getText();
      } else {
        body = plainTextController.text;
      }

      // Add signature if needed
      body += signature;

      // Create message builder
      messageBuilder = MessageBuilder();

      // Add attachments
      for (final file in attachments) {
        await messageBuilder.addFile(
          file,
          MediaType.guessFromFileName(file.path),
        );
      }

      // Set message content
      messageBuilder.addMultipartAlternative(
        htmlText: isHtml.value ? body : null,
        plainText: isHtml.value ? _removeHtmlTags(body) : body,
      );

      // Set message metadata
      messageBuilder.to = toList.toList();
      messageBuilder.cc = cclist.toList();
      messageBuilder.bcc = bcclist.toList();
      messageBuilder.subject = subjectController.text;
      messageBuilder.from = [MailAddress(name, email)];
      messageBuilder.date = DateTime.now();

      // Add read receipt if enabled
      if (Get.find<SettingController>().readReceipts()) {
        messageBuilder.requestReadReceipt();
      }

      // Build message
      final message = messageBuilder.buildMimeMessage();

      // Send message
      final boxController = Get.find<MailBoxController>();
      await boxController.sendMail(message, msg);

      // Delete draft if editing
      if (msg != null && type == 'draft' && _currentDraft != null) {
        await client.deleteMessage(msg!);
        final storage = Get.find<SqliteMimeStorage>();
        await storage.deleteDraft(_currentDraft!.id!);
      }

      // Update state
      _hasUnsavedChanges.value = false;
      canPop.value = true;

      // Show success message
      EasyLoading.dismiss();
      EasyLoading.showSuccess('message_sent'.tr);

      // Close compose screen
      Get.back();

    } catch (e) {
      // Show error message
      EasyLoading.dismiss();

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
      isBusy.value = false;
      update();
    }
  }

  // Toggle HTML/plain text mode
  Future<void> togglePlainHtml() async {
    if (isBusy.value) return;

    try {
      isBusy.value = true;
      update();

      if (isHtml.value) {
        // Switch from HTML to plain text
        final htmlText = await htmlController.getText();
        plainTextController.text = _removeHtmlTags(htmlText);
      } else {
        // Switch from plain text to HTML
        final plainText = plainTextController.text;
        // Use Future.delayed to ensure the HTML editor is initialized
        htmlController.setText(plainText);
      }

      isHtml.toggle();
      _markAsChanged();
    } catch (e) {
      debugPrint('Error toggling HTML mode: $e');
    } finally {
      isBusy.value = false;
      update();
    }
  }

  // Insert link in HTML editor
  Future<void> insertLink() async {
    if (!isHtml.value) return;

    try {
      // Fixed variable scope issue by initializing the map
      Map<String, String> linkData = {'text': '', 'url': ''};

      final result = await Get.dialog<Map<String, String>>(
        AlertDialog(
          title: Text('insert_link'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'text'.tr,
                  hintText: 'link_text'.tr,
                ),
                controller: TextEditingController(),
                onChanged: (value) => linkData['text'] = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'url'.tr,
                  hintText: 'https://example.com',
                ),
                controller: TextEditingController(),
                onChanged: (value) => linkData['url'] = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('cancel'.tr),
            ),
            TextButton(
              onPressed: () => Get.back(result: linkData),
              child: Text('insert'.tr),
            ),
          ],
        ),
      );

      if (result != null && result['text'] != null && result['url'] != null) {
        htmlController.insertLink(result['text']!, result['url']!, true);
        _markAsChanged();
      }
    } catch (e) {
      debugPrint('Error inserting link: $e');
    }
  }

  // Remove HTML tags from text
  String _removeHtmlTags(String htmlText) {
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  @override
  void dispose() {
    // Save any unsaved changes before disposing
    if (_hasUnsavedChanges.value && _currentDraft != null) {
      _autosaveDraft();
    }

    _autosaveTimer?.cancel();
    _statusClearTimer?.cancel();
    subjectController.dispose();
    fromController.dispose();
    plainTextController.dispose();
    super.dispose();
  }
}
