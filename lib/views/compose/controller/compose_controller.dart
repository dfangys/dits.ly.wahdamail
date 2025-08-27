import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/views/compose/models/draft_model.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/models/sqlite_draft_repository.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';


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
  final Rx<SQLiteMailboxMimeStorage?> storage = Rx<SQLiteMailboxMimeStorage?>(null);

  // Recipients
  final RxList<MailAddress> toList = <MailAddress>[].obs;
  final RxList<MailAddress> cclist = <MailAddress>[].obs;
  final RxList<MailAddress> bcclist = <MailAddress>[].obs;

  // Form controllers
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController fromController = TextEditingController();
  final TextEditingController plainTextController = TextEditingController();
  final HtmlEditorController htmlController = HtmlEditorController();
  
  // HTML editor state
  final RxBool _isHtmlEditorReady = false.obs;
  bool get isHtmlEditorReady => _isHtmlEditorReady.value;
  
  // Helper method to safely interact with HTML editor
  Future<String> _safeGetHtmlText() async {
    try {
      if (!isHtmlEditorReady) {
        debugPrint('HTML editor not ready, returning empty string');
        return '';
      }
      return await htmlController.getText();
    } catch (e) {
      debugPrint('Error getting HTML text: $e');
      return '';
    }
  }
  
  Future<void> _safeSetHtmlText(String text) async {
    try {
      if (!isHtmlEditorReady) {
        debugPrint('HTML editor not ready, skipping setText');
        return;
      }
      htmlController.setText(text);
    } catch (e) {
      debugPrint('Error setting HTML text: $e');
    }
  }
  
  void markHtmlEditorReady() {
    _isHtmlEditorReady.value = true;
    debugPrint('HTML editor marked as ready');
  }

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
  final RxBool isSending = false.obs;
  final RxInt priority = 0.obs;
  int? currentDraftId;

  // Draft state
  final RxBool _hasUnsavedChanges = false.obs;
  bool get hasUnsavedChanges => _hasUnsavedChanges.value;
  set hasUnsavedChanges(bool value) => _hasUnsavedChanges.value = value;

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

  // Setup autosave functionality
  void _setupAutosave() {
    // Setup periodic autosave every 30 seconds
    _autosaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_hasUnsavedChanges.value && !_isAutosaving.value) {
        _autosaveDraft();
      }
    });
  }

  // Setup change listeners for form fields
  void _setupChangeListeners() {
    subjectController.addListener(_markAsChanged);
    plainTextController.addListener(_markAsChanged);
    
    // Listen to recipient list changes
    toList.listen((_) => _markAsChanged());
    cclist.listen((_) => _markAsChanged());
    bcclist.listen((_) => _markAsChanged());
    attachments.listen((_) => _markAsChanged());
  }

  void _initializeController() async {
    final args = Get.arguments;

    // Clear any previous draft state first
    await _clearDraftState();

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
          signature = settingController.signatureReply.value
              ? settingController.signature.value
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
          signature = settingController.signatureReply.value
              ? settingController.signature.value
              : '';
          messageBuilder = MessageBuilder.prepareReplyToMessage(
            msg!,
            MailAddress(name, email),
            replyAll: true,
          );
        } else if (type == 'forward') {
          subjectController.text = 'Fwd: ${msg!.decodeSubject()}';
          signature = settingController.signatureForward.value
              ? settingController.signature.value
              : '';
          messageBuilder = MessageBuilder.prepareForwardMessage(msg!);
        } else if (type == 'draft') {
          toList.addAll(msg!.to ?? []);
          cclist.addAll(msg!.cc ?? []);
          bcclist.addAll(msg!.bcc ?? []);
          subjectController.text = msg!.decodeSubject() ?? '';
          signature = settingController.signatureNewMessage.value
              ? settingController.signature.value
              : '';
          messageBuilder = MessageBuilder.prepareFromDraft(msg!);

          // Load draft from storage
          await _loadDraftFromMessage(msg!);
        }
      } else {
        final settingController = Get.find<SettingController>();
        signature = settingController.signatureNewMessage.value
            ? settingController.signature.value
            : '';
        messageBuilder = MessageBuilder();
      }
    } else {
      final settingController = Get.find<SettingController>();
      signature = settingController.signatureNewMessage.value
          ? settingController.signature.value
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
      Future.delayed(Duration.zero, () async {
        debugPrint('Setting HTML editor content: ${bodyPart.length} characters');
        await _safeSetHtmlText(bodyPart);
        plainTextController.text = _removeHtmlTags(bodyPart);
      });
    }
  }

  // Getters for user info
  String get email => account.email;
  String get name => account.name;

  // RECIPIENT MANAGEMENT METHODS (CONSOLIDATED - REMOVED DUPLICATES)
  
  /// Add email address to TO list - supports both String and MailAddress
  void addTo(dynamic emailOrAddress) {
    try {
      MailAddress address;
      if (emailOrAddress is String) {
        address = MailAddress.parse(emailOrAddress);
      } else if (emailOrAddress is MailAddress) {
        address = emailOrAddress;
      } else {
        debugPrint('Invalid parameter type for addTo');
        return;
      }

      if (!toList.any((addr) => addr.email == address.email)) {
        toList.add(address);
        
        // Remove from other lists if present
        cclist.removeWhere((addr) => addr.email == address.email);
        bcclist.removeWhere((addr) => addr.email == address.email);
        
        _markAsChanged();
      }
    } catch (e) {
      debugPrint('Error adding TO address: $e');
    }
  }

  /// Remove email address from TO list - supports both index and MailAddress
  void removeFromToList(dynamic indexOrAddress) {
    try {
      if (indexOrAddress is int) {
        if (indexOrAddress >= 0 && indexOrAddress < toList.length) {
          toList.removeAt(indexOrAddress);
        }
      } else if (indexOrAddress is MailAddress) {
        toList.remove(indexOrAddress);
      }
      _markAsChanged();
    } catch (e) {
      debugPrint('Error removing from TO list: $e');
    }
  }

  /// Add email address to CC list - supports both String and MailAddress
  void addToCC(dynamic emailOrAddress) {
    try {
      MailAddress address;
      if (emailOrAddress is String) {
        address = MailAddress.parse(emailOrAddress);
      } else if (emailOrAddress is MailAddress) {
        address = emailOrAddress;
      } else {
        debugPrint('Invalid parameter type for addToCC');
        return;
      }

      if (!cclist.any((addr) => addr.email == address.email)) {
        cclist.add(address);
        
        // Remove from other lists if present
        toList.removeWhere((addr) => addr.email == address.email);
        bcclist.removeWhere((addr) => addr.email == address.email);
        
        _markAsChanged();
      }
    } catch (e) {
      debugPrint('Error adding CC address: $e');
    }
  }

  /// Remove email address from CC list - supports both index and MailAddress
  void removeFromCcList(dynamic indexOrAddress) {
    try {
      if (indexOrAddress is int) {
        if (indexOrAddress >= 0 && indexOrAddress < cclist.length) {
          cclist.removeAt(indexOrAddress);
        }
      } else if (indexOrAddress is MailAddress) {
        cclist.remove(indexOrAddress);
      }
      _markAsChanged();
    } catch (e) {
      debugPrint('Error removing from CC list: $e');
    }
  }

  /// Add email address to BCC list - supports both String and MailAddress
  void addToBcc(dynamic emailOrAddress) {
    try {
      MailAddress address;
      if (emailOrAddress is String) {
        address = MailAddress.parse(emailOrAddress);
      } else if (emailOrAddress is MailAddress) {
        address = emailOrAddress;
      } else {
        debugPrint('Invalid parameter type for addToBcc');
        return;
      }

      if (!bcclist.any((addr) => addr.email == address.email)) {
        bcclist.add(address);
        
        // Remove from other lists if present
        toList.removeWhere((addr) => addr.email == address.email);
        cclist.removeWhere((addr) => addr.email == address.email);
        
        _markAsChanged();
      }
    } catch (e) {
      debugPrint('Error adding BCC address: $e');
    }
  }

  /// Remove email address from BCC list - supports both index and MailAddress
  void removeFromBccList(dynamic indexOrAddress) {
    try {
      if (indexOrAddress is int) {
        if (indexOrAddress >= 0 && indexOrAddress < bcclist.length) {
          bcclist.removeAt(indexOrAddress);
        }
      } else if (indexOrAddress is MailAddress) {
        bcclist.remove(indexOrAddress);
      }
      _markAsChanged();
    } catch (e) {
      debugPrint('Error removing from BCC list: $e');
    }
  }

  // CONTENT MANAGEMENT METHODS (CONSOLIDATED)

  /// Toggle between HTML and plain text editing
  Future<void> togglePlainHtml() async {
    if (isBusy.value) return;

    try {
      isBusy.value = true;
      
      if (isHtml.value) {
        // Switching from HTML to plain text
        final htmlContent = await _safeGetHtmlText();
        plainTextController.text = _removeHtmlTags(htmlContent);
        isHtml.value = false;
      } else {
        // Switching from plain text to HTML
        final plainContent = plainTextController.text;
        final htmlContent = _convertPlainToHtml(plainContent);
        await _safeSetHtmlText(htmlContent);
        isHtml.value = true;
      }
      _markAsChanged();
    } catch (e) {
      debugPrint('Error toggling HTML/Plain text: $e');
    } finally {
      isBusy.value = false;
    }
  }

  // ATTACHMENT METHODS (CONSOLIDATED - REMOVED DUPLICATES)

  /// Pick files for attachment (enhanced version)
  Future<void> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            attachments.add(File(file.path!));
          }
        }
        _markAsChanged();
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
      _showErrorDialog('Error selecting files: $e');
    }
  }

  /// Pick image for attachment (enhanced version using FilePicker)
  Future<void> pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            attachments.add(File(file.path!));
          }
        }
        _markAsChanged();
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      _showErrorDialog('Error selecting images: $e');
    }
  }

  /// Take photo with camera
  Future<void> takePhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        attachments.add(File(pickedFile.path));
        _markAsChanged();
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      _showErrorDialog('Error taking photo: $e');
    }
  }

  // DRAFT MANAGEMENT METHODS (CONSOLIDATED - REMOVED DUPLICATES)

  /// Save current email as draft (enhanced version)
  Future<void> saveAsDraft() async {
    if (isBusy.value) return;

    try {
      isBusy.value = true;
      _draftStatus.value = 'saving_draft'.tr;
      update();

      EasyLoading.show(status: 'saving_draft'.tr);

      // Get current content
      late String body;
      if (isHtml.value) {
        body = await _safeGetHtmlText();
      } else {
        body = plainTextController.text;
      }

      // Check if there's enough content to save
      if (!_hasSaveableContent(body)) {
        EasyLoading.dismiss();
        EasyLoading.showInfo('nothing_to_save'.tr);
        _draftStatus.value = '';
        return;
      }

      // Add signature if needed
      body += signature;

      // Create draft model
      final draft = _createDraftModel(body);

      // Save to local storage
      final storage = Get.find<SQLiteDraftRepository>();
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
      await client.selectMailboxByFlag(MailboxFlag.drafts);
      final code = await client.saveDraftMessage(draftMessage);

      // Update draft with server info if successful
      if (code != null && _currentDraft != null) {
        await storage.markDraftSynced(_currentDraft!.id!, code.uidValidity);
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

      EasyLoading.dismiss();
      EasyLoading.showSuccess('draft_saved'.tr);

    } catch (e) {
      EasyLoading.dismiss();
      _showErrorDialog(e.toString());
      _draftStatus.value = 'save_error'.tr;

      // Try to save locally even if server save failed
      if (_currentDraft != null) {
        final storage = Get.find<SQLiteDraftRepository>();
        await storage.markDraftSyncError(_currentDraft!.id!, e.toString());
      }
    } finally {
      isBusy.value = false;
      update();
    }
  }

  /// Schedule draft for later sending
  Future<void> scheduleDraft(DateTime scheduledTime) async {
    if (isBusy.value) return;

    try {
      isBusy.value = true;
      _draftStatus.value = 'scheduling_draft'.tr;
      update();

      EasyLoading.show(status: 'scheduling_draft'.tr);

      // Get current content
      late String body;
      if (isHtml.value) {
        body = await _safeGetHtmlText();
      } else {
        body = plainTextController.text;
      }

      // Check if there's enough content to save
      if (!_hasSaveableContent(body)) {
        EasyLoading.dismiss();
        EasyLoading.showInfo('nothing_to_schedule'.tr);
        _draftStatus.value = '';
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
      final storage = Get.find<SQLiteDraftRepository>();
      _currentDraft = await storage.saveDraft(draft);

      // Update state
      _hasUnsavedChanges.value = false;
      _draftStatus.value = 'draft_scheduled'.tr;
      _lastSavedTime.value = _formatSaveTime(DateTime.now());
      _showDraftOptions.value = true;
      canPop.value = true;

      EasyLoading.dismiss();
      EasyLoading.showSuccess('draft_scheduled'.tr);

    } catch (e) {
      EasyLoading.dismiss();
      _showErrorDialog(e.toString());
      _draftStatus.value = 'schedule_error'.tr;
    } finally {
      isBusy.value = false;
      update();
    }
  }

  /// Categorize draft with labels/folders
  Future<void> categorizeDraft(String category) async {
    if (_currentDraft == null || isBusy.value) return;

    try {
      isBusy.value = true;

      // Update category in storage
      final storage = Get.find<SQLiteDraftRepository>();
      await storage.updateDraftCategory(_currentDraft!.id!, category);

      // Update current draft reference
      _currentDraft = _currentDraft!.copyWith(category: category);

      EasyLoading.showSuccess('category_updated'.tr);
    } catch (e) {
      debugPrint('Error categorizing draft: $e');
      EasyLoading.showError('category_update_error'.tr);
    } finally {
      isBusy.value = false;
    }
  }

  // EMAIL SENDING METHOD (CONSOLIDATED)

  /// Send the composed email
  Future<void> sendEmail() async {
    if (isBusy.value) return;

    try {
      // Validate recipients
      if (toList.isEmpty) {
        _showErrorDialog('please_add_recipient'.tr);
        return;
      }

      // Validate subject
      if (subjectController.text.isEmpty) {
        _showErrorDialog('valid_subject'.tr);
        return;
      }

      isBusy.value = true;
      update();

      EasyLoading.show(status: 'sending_email'.tr);

      // Get current content
      late String body;
      if (isHtml.value) {
        body = await _safeGetHtmlText();
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
        final storage = Get.find<SQLiteDraftRepository>();
        await storage.deleteDraft(_currentDraft!.id!);
      }

      // Update state
      _hasUnsavedChanges.value = false;
      canPop.value = true;

      EasyLoading.dismiss();
      EasyLoading.showSuccess('message_sent'.tr);

      // Close compose screen
      Get.back();

    } catch (e) {
      EasyLoading.dismiss();
      _showErrorDialog(e.toString());
    } finally {
      isBusy.value = false;
      update();
    }
  }

  // HELPER METHODS (CONSOLIDATED - REMOVED DUPLICATES)

  // Mark content as changed and needing save
  void _markAsChanged() {
    _hasUnsavedChanges.value = true;
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
        body = await _safeGetHtmlText();
      } else {
        body = plainTextController.text;
      }

      // Check if there's enough content to save
      if (!_hasSaveableContent(body)) {
        _draftStatus.value = '';
        return;
      }

      // Create draft model
      final draft = _createDraftModel(body);

      // Save to storage
      final storage = Get.find<SQLiteDraftRepository>();
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

  // Format save time for display (consolidated version)
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

  // Check if there's content to save as draft (consolidated version)
  bool _hasSaveableContent(String body) {
    return subjectController.text.trim().isNotEmpty ||
        body.trim().isNotEmpty ||
        toList.isNotEmpty ||
        cclist.isNotEmpty ||
        bcclist.isNotEmpty ||
        attachments.isNotEmpty;
  }

  // Check for any recoverable drafts
  Future<void> _checkForRecovery() async {
    try {
      final storage = Get.find<SQLiteDraftRepository>();
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
                onPressed: () async {
                  Get.back();
                  await _recoverDraft(mostRecent);
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
  Future<void> _recoverDraft(DraftModel draft) async {
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
      await _safeSetHtmlText(draft.body);
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

    EasyLoading.showSuccess('draft_recovered'.tr);
    update();
  }

  // Clear all draft-related state
  Future<void> _clearDraftState() async {
    debugPrint('Clearing previous draft state');
    
    // Clear recipient lists
    toList.clear();
    cclist.clear();
    bcclist.clear();
    
    // Clear form fields
    subjectController.clear();
    plainTextController.clear();
    
    // Clear attachments
    attachments.clear();
    
    // Reset draft-specific state
    _showDraftOptions.value = false;
    _hasUnsavedChanges.value = false;
    _draftStatus.value = '';
    _lastSavedTime.value = '';
    bodyPart = '';
    
    // Reset HTML editor if needed
    try {
      await _safeSetHtmlText('');
    } catch (e) {
      debugPrint('Error clearing HTML editor: $e');
    }
    
    debugPrint('Draft state cleared successfully');
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

  // Load draft from MimeMessage directly (server-based drafts)
  Future<void> _loadDraftFromMessage(MimeMessage message) async {
    try {
      debugPrint('Loading draft: ${message.decodeSubject()}');
      
      // Load all draft data from MimeMessage
      
      // 1. Load recipients
      toList.clear();
      cclist.clear();
      bcclist.clear();
      
      // Load To recipients
      if (message.to != null) {
        for (final address in message.to!) {
          toList.add(address);
        }
      }
      
      // Load CC recipients
      if (message.cc != null) {
        for (final address in message.cc!) {
          cclist.add(address);
        }
      }
      
      // Load BCC recipients
      if (message.bcc != null) {
        for (final address in message.bcc!) {
          bcclist.add(address);
        }
      }
      
      // 2. Load subject
      final subject = message.decodeSubject() ?? '';
      subjectController.text = subject;
      
      // 3. Load body content
      String bodyContent = '';
      bool isHtmlContent = false;
      
      // Try to get HTML content first
      final htmlContent = message.decodeTextHtmlPart();
      
      if (htmlContent != null && htmlContent.trim().isNotEmpty) {
        bodyContent = htmlContent;
        isHtmlContent = true;
      } else {
        final plainContent = message.decodeTextPlainPart();
        
        if (plainContent != null && plainContent.trim().isNotEmpty) {
          bodyContent = plainContent;
          isHtmlContent = false;
        } else {
          // Fallback: Try to extract from message body directly
          try {
            final bodyText = message.decodeContentText();
            if (bodyText != null && bodyText.trim().isNotEmpty) {
              bodyContent = bodyText;
              isHtmlContent = false;
            }
          } catch (e) {
            debugPrint('Fallback body extraction failed: $e');
          }
        }
      }
      
      // Set the content in the appropriate editor
      if (isHtmlContent && bodyContent.isNotEmpty) {
        isHtml.value = true;
        bodyPart = bodyContent;
        
        try {
          await _safeSetHtmlText(bodyContent);
        } catch (e) {
          debugPrint('Failed to set HTML content: $e');
          // Fallback to plain text if HTML setting fails
          isHtml.value = false;
          plainTextController.text = bodyContent;
        }
      } else if (bodyContent.isNotEmpty) {
        isHtml.value = false;
        plainTextController.text = bodyContent;
      } else {
        // Set empty content
        isHtml.value = false;
        plainTextController.text = '';
      }
      
      // 4. Load attachments from the MimeMessage
      attachments.clear();
      if (message.hasAttachments()) {
        final attachmentInfos = message.findContentInfo(disposition: ContentDisposition.attachment);
        
        for (final info in attachmentInfos) {
          try {
            // Extract attachment info from the content info
            final filename = info.fileName ?? 'attachment';
            final contentType = info.contentType?.toString() ?? 'application/octet-stream';
            
            debugPrint('Draft has attachment: $filename ($contentType)');
            
            // TODO: Download attachment data and create local file if needed for editing
            // This would require implementing attachment download from the MimeMessage
            
          } catch (e) {
            debugPrint('Error processing attachment: $e');
          }
        }
      }
      
      // 5. Set draft metadata
      _showDraftOptions.value = true;
      _lastSavedTime.value = _formatSaveTime(DateTime.now());
      _hasUnsavedChanges.value = false;
      _draftStatus.value = 'draft_loaded'.tr;
      
      // Force UI update
      update();
      
      debugPrint('Successfully loaded draft from server: ${message.decodeSubject()}');
      
    } catch (e) {
      debugPrint('Error loading draft from message: $e');
    }
  }


  // Insert link in HTML editor
  Future<void> insertLink() async {
    if (!isHtml.value) return;

    try {
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

  // Convert plain text to HTML
  String _convertPlainToHtml(String plainText) {
    return plainText
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;')
        .replaceAll('\n', '<br>');
  }

  // Show error dialog
  void _showErrorDialog(String message) {
    AwesomeDialog(
      context: Get.context!,
      dialogType: DialogType.error,
      animType: AnimType.bottomSlide,
      title: 'error'.tr,
      desc: message,
      btnOkOnPress: () {},
    ).show();
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

