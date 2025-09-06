import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:convert' as convert;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/features/messaging/presentation/models/draft_model.dart';
import 'package:wahda_bank/features/messaging/application/message_content_usecase.dart';
import 'package:wahda_bank/shared/di/injection.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:wahda_bank/app/api/mailbox_controller_api.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/models/sqlite_draft_repository.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';
import 'package:wahda_bank/services/imap_fetch_pool.dart';
import 'package:wahda_bank/services/attachment_fetcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:open_app_file/open_app_file.dart';
import 'package:wahda_bank/services/draft_sync_service.dart';
import 'package:wahda_bank/services/message_content_store.dart';
import 'package:wahda_bank/services/html_enhancer.dart';
import 'package:wahda_bank/services/realtime_update_service.dart';
import 'package:wahda_bank/services/imap_command_queue.dart';
import 'package:wahda_bank/services/feature_flags.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';
import 'package:wahda_bank/shared/utils/hashing.dart';
import 'package:wahda_bank/features/messaging/presentation/compose_view_model.dart';

extension EmailValidator on String {
  bool isValidEmail() {
    return RegExp(
      r"[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?",
    ).hasMatch(this);
  }
}

enum DraftSyncState { idle, syncing, synced, failed }

@Deprecated('Replaced by ViewModels. Will be removed in P12.4')
class ComposeController extends GetxController {
  // Compose session identifier to correlate all server-side draft versions for this editor lifecycle
  // Used to reliably purge superseded drafts and avoid duplicates
  String? _composeSessionId;
  String get composeSessionId =>
      _composeSessionId ??= _generateComposeSessionId();
  String _generateComposeSessionId() {
    final rnd = math.Random();
    return 'cmp-${DateTime.now().microsecondsSinceEpoch}-${rnd.nextInt(0x7fffffff)}';
  }

  // Normalize top-level transfer-encoding for multipart messages
  void _normalizeTopLevelTransferEncoding(MimeMessage msg) {
    try {
      final ct =
          (msg.getHeaderValue('Content-Type') ??
                  msg.getHeaderValue('content-type') ??
                  '')
              .toLowerCase();
      if (ct.contains('multipart/')) {
        // For multipart containers, top-level CTE should not be base64.
        // Force 7bit to avoid downstream parsers trying to base64-decode boundaries.
        msg.setHeader('Content-Transfer-Encoding', '7bit');
      }
    } catch (_) {}
  }

  // Heuristic: detect raw MIME boundary/header text mistakenly treated as body
  bool _looksLikeMimeContainerText(String s) {
    try {
      if (s.isEmpty) return false;
      final lower = s.toLowerCase();
      // Obvious MIME headers and boundary markers
      if (lower.contains('content-type: multipart/')) return true;
      if (lower.contains('mime-version: 1.0') &&
          lower.contains('content-transfer-encoding:'))
        return true;
      // Multiple boundary lines like "--abc" on separate lines
      final boundaryLine = RegExp(
        r'^--[-A-Za-z0-9()+,./:=?_ ]{6,}\r?$|^--[-A-Za-z0-9()+,./:=?_ ]{6,}--\r?$',
        multiLine: true,
      );
      final matches = boundaryLine.allMatches(s);
      if (matches.length >= 2) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  // Email client and account via application adapter
  MessageContentUseCase? _content;
  MessageContentUseCase get _mc =>
      _content ??= (getIt.isRegistered<MessageContentUseCase>()
          ? getIt<MessageContentUseCase>()
          : getIt<MessageContentUseCase>());
  dynamic get client => _mc.client;
  String get accountEmail => _mc.accountEmail;
  final Rx<SQLiteMailboxMimeStorage?> storage = Rx<SQLiteMailboxMimeStorage?>(
    null,
  );

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

  // Pending draft attachments from server (metadata only until user confirms)
  final RxList<DraftAttachmentMeta> pendingDraftAttachments =
      <DraftAttachmentMeta>[].obs;

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

  // Draft sync state for UX
  final Rx<DraftSyncState> syncState = DraftSyncState.idle.obs;
  final RxString syncHint = ''.obs;

  // Attachment hydration policy
  static const int _attachmentAutoHydrationLimitBytes =
      10 * 1024 * 1024; // 10MB

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

  // Change tracking controls
  bool _suspendChangeTracking = false;
  bool _isHydrating = false;
  String? _lastSavedFingerprint; // baseline snapshot of last synced content

  // Realtime projection debounce
  Timer? _rtProjectionDebounce;

  // Original message data
  MimeMessage? msg;
  String? type;
  Mailbox? sourceMailbox; // mailbox where the draft message resides

  // When editing an existing server draft via different entry points (args or redesigned compose)
  int? editingServerDraftUid; // UID of the original server draft
  Mailbox?
  editingServerDraftMailbox; // Drafts mailbox context for the original draft

  void setEditingDraftContext({int? uid, Mailbox? mailbox}) {
    editingServerDraftUid = uid;
    editingServerDraftMailbox = mailbox;
  }

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
    // Setup periodic autosave with configurable interval (default 30s; min 10s)
    final secs = math.max(10, FeatureFlags.instance.draftAutosaveIntervalSecs);
    _autosaveTimer = Timer.periodic(Duration(seconds: secs), (timer) {
      if (_hasUnsavedChanges.value && !_isAutosaving.value) {
        _autosaveDraft();
      }
    });
  }

  // Setup change listeners for form fields
  void _setupChangeListeners() {
    subjectController.addListener(_onAnyFieldChanged);
    plainTextController.addListener(_onAnyFieldChanged);

    // Listen to recipient list changes
    toList.listen((_) => _onAnyFieldChanged());
    cclist.listen((_) => _onAnyFieldChanged());
    bcclist.listen((_) => _onAnyFieldChanged());
    attachments.listen((_) => _onAnyFieldChanged());
  }

  void _onAnyFieldChanged() {
    if (_suspendChangeTracking || _isHydrating) return;
    _markAsChanged();
  }

  // Compute a stable fingerprint of the compose content to avoid unnecessary APPENDs
  String _computeFingerprintFrom({required String body, required bool isHtml}) {
    try {
      // Normalize recipients including display names to detect any user-visible change
      String addrFmt(MailAddress a) {
        final nm = (a.personalName ?? '').trim().toLowerCase();
        final em = (a.email).trim().toLowerCase();
        return nm.isEmpty ? em : '$nm<$em>';
      }

      final to = toList.map(addrFmt).toList()..sort();
      final cc = cclist.map(addrFmt).toList()..sort();
      final bcc = bcclist.map(addrFmt).toList()..sort();

      // Combine local attachments and server-pending attachments by filename for a stable view of attachment set
      final localAtts = attachments.map((f) => p.basename(f.path)).toList();
      final pendingAtts =
          pendingDraftAttachments.map((m) => m.fileName).toList();
      final attSet = <String>{...localAtts, ...pendingAtts}
        ..removeWhere((e) => e.trim().isEmpty);
      final atts = attSet.toList()..sort();

      final map = {
        'subject': subjectController.text.trim(),
        'isHtml': isHtml,
        'body': body.trim(),
        'to': to,
        'cc': cc,
        'bcc': bcc,
        'attachments': atts,
      };
      return convert.jsonEncode(map);
    } catch (_) {
      // Fallback: minimal string (still count recipients and attachments)
      return '${subjectController.text}|${isHtml ? 'H' : 'P'}|${body.length}|${toList.length + cclist.length + bcclist.length}|${attachments.length + pendingDraftAttachments.length}';
    }
  }

  void _setBaselineFingerprint({required String body, required bool isHtml}) {
    _lastSavedFingerprint = _computeFingerprintFrom(body: body, isHtml: isHtml);
    _hasUnsavedChanges.value = false;
  }

  void _initializeController() async {
    final args = Get.arguments;

    // Clear any previous draft state first
    await _clearDraftState();

    if (args != null) {
      type = args['type'];
      msg = args['message'];
      sourceMailbox = args['mailbox'];
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
          signature =
              settingController.signatureReply.value
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
          signature =
              settingController.signatureReply.value
                  ? settingController.signature.value
                  : '';
          messageBuilder = MessageBuilder.prepareReplyToMessage(
            msg!,
            MailAddress(name, email),
            replyAll: true,
          );
        } else if (type == 'forward') {
          subjectController.text = 'Fwd: ${msg!.decodeSubject()}';
          signature =
              settingController.signatureForward.value
                  ? settingController.signature.value
                  : '';
          messageBuilder = MessageBuilder.prepareForwardMessage(msg!);
        } else if (type == 'draft') {
          // Quick envelope population
          _loadDraftEnvelopeQuick(msg!);
          // Carry over compose session id from server draft if present to keep continuity
          try {
            final sid =
                msg!.getHeaderValue('x-compose-session') ??
                msg!.getHeaderValue('X-Compose-Session');
            if (sid != null && sid.trim().isNotEmpty) {
              _composeSessionId = sid.trim();
              debugPrint(
                '[DraftFlow] Compose session restored from header: $_composeSessionId',
              );
            }
          } catch (_) {}
          // Record server draft context for downstream save/replace logic
          try {
            setEditingDraftContext(uid: msg!.uid, mailbox: sourceMailbox);
          } catch (_) {}
          signature =
              settingController.signatureNewMessage.value
                  ? settingController.signature.value
                  : '';
          messageBuilder = MessageBuilder.prepareFromDraft(msg!);

          // Proactively prime missing compose-session header from server headers if not yet known
          if (_composeSessionId == null && msg!.uid != null) {
            unawaited(
              _primeComposeSessionFromServer(
                message: msg!,
                mailboxHint: sourceMailbox,
              ),
            );
          }

          // Schedule background hydration (body + attachment metadata)
          unawaited(_hydrateDraftInBackground(msg!));
        }
      } else {
        final settingController = Get.find<SettingController>();
        signature =
            settingController.signatureNewMessage.value
                ? settingController.signature.value
                : '';
        messageBuilder = MessageBuilder();
      }
    } else {
      final settingController = Get.find<SettingController>();
      signature =
          settingController.signatureNewMessage.value
              ? settingController.signature.value
              : '';
      messageBuilder = MessageBuilder();
    }

    // Set from field (UI display only, not the actual header encoding)
    if (name.isNotEmpty) {
      final safeName = name.replaceAll('"', '\\"');
      fromController.text = '"$safeName" <$email>';
    } else {
      fromController.text = email;
    }

    // Bind storage for Drafts mailbox for realtime projection
    try {
      final mbc = Get.find<MailBoxController>();
      final draftsMb =
          sourceMailbox ??
          editingServerDraftMailbox ??
          mbc.draftsMailbox ??
          client.selectedMailbox ??
          mbc.currentMailbox;
      if (draftsMb != null) {
        storage.value = mbc.mailboxStorage[draftsMb];
      }
    } catch (_) {}

    // Initialize HTML editor with content
    if (bodyPart.isNotEmpty) {
      Future.delayed(Duration.zero, () async {
        debugPrint(
          'Setting HTML editor content: ${bodyPart.length} characters',
        );
        await _safeSetHtmlText(bodyPart);
        plainTextController.text = _removeHtmlTags(bodyPart);
      });
    }
  }

  // Getters for user info
  String get email => accountEmail;
  String get name {
    try {
      if (Get.isRegistered<SettingController>()) {
        final sc = Get.find<SettingController>();
        final n = sc.userName.value.trim();
        if (n.isNotEmpty) return n;
      }
    } catch (_) {}
    // Fallback: no display name
    return '';
  }

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

      // If unchanged vs baseline, do nothing (avoid duplicate APPEND)
      try {
        final fp = _computeFingerprintFrom(body: body, isHtml: isHtml.value);
        if (_lastSavedFingerprint != null && _lastSavedFingerprint == fp) {
          EasyLoading.dismiss();
          _draftStatus.value = '';
          update();
          return;
        }
      } catch (_) {}

      // Update in-memory bodyPart for fast projection and preview
      try {
        bodyPart = isHtml.value ? body : _convertPlainToHtml(body);
      } catch (_) {}

      // Check if there's enough content to save
      if (!_hasSaveableContent(body)) {
        EasyLoading.dismiss();
        EasyLoading.showInfo('nothing_to_save'.tr);
        _draftStatus.value = '';
        return;
      }

      // Add signature only for brand-new compose or reply/forward, not when editing an existing server draft
      if (type != 'draft') {
        body += signature;
      }

      // Create draft model
      final draft = _createDraftModel(body);

      // If we are editing an existing server draft but the compose-session is not yet known, try to prime it quickly
      if (type == 'draft' &&
          _composeSessionId == null &&
          msg != null &&
          msg!.uid != null) {
        try {
          await _primeComposeSessionFromServer(
            message: msg!,
            mailboxHint: sourceMailbox,
            timeout: const Duration(seconds: 4),
          );
        } catch (_) {}
      }

      // Optimistically project updated preview and mark draft as read
      try {
        await _projectToDraftsListRealtime();
      } catch (_) {}

      // Persist offline content for immediate reopen
      unawaited(
        _persistOfflineContentForCurrentDraft(body: body, html: isHtml.value),
      );

      // Save to local storage
      final storage = Get.find<SQLiteDraftRepository>();
      _currentDraft = await storage.saveDraft(draft);

      // Create message builder for server save
      messageBuilder = MessageBuilder();

      // Include any server-side pending attachments into the outgoing draft first (non-destructive to UI state)
      await _attachPendingServerAttachmentsToBuilder(messageBuilder);

      // Add locally selected attachments
      for (final file in attachments) {
        await messageBuilder.addFile(
          file,
          MediaType.guessFromFileName(file.path),
        );
      }

      // Set message content (avoid empty multipart/alternative)
      final String htmlCandidate = isHtml.value ? body.trim() : '';
      final String plainCandidate =
          isHtml.value ? _removeHtmlTags(body).trim() : body.trim();
      if (htmlCandidate.isEmpty && plainCandidate.isEmpty) {
        // Minimal placeholder to avoid empty multipart container
        messageBuilder.addMultipartAlternative(htmlText: null, plainText: ' ');
      } else {
        messageBuilder.addMultipartAlternative(
          htmlText: htmlCandidate.isNotEmpty ? htmlCandidate : null,
          plainText: plainCandidate.isNotEmpty ? plainCandidate : null,
        );
      }

      // Set message metadata
      messageBuilder.to = toList.toList();
      messageBuilder.cc = cclist.toList();
      messageBuilder.bcc = bcclist.toList();
      messageBuilder.subject = subjectController.text;
      // RFC-compliant From header via enough_mail's MailAddress. If name is empty, only the email will be used.
      messageBuilder.from = [MailAddress(name, email)];
      messageBuilder.date = DateTime.now();

      // Build message
      final draftMessage = messageBuilder.buildMimeMessage();
      // Tag with compose session id for robust duplicate cleanup across saves
      try {
        draftMessage.setHeader('X-Compose-Session', composeSessionId);
      } catch (_) {}

      // Queue background server sync with backoff; do not block UI
      syncState.value = DraftSyncState.syncing;
      syncHint.value = 'syncing_with_server'.tr;
      // Notify DraftSyncService for UI badges (existing draft key while syncing)
      Mailbox? editingMb;
      MimeMessage? oldMsg;
      String? oldKey;
      try {
        final mbc = Get.find<MailBoxController>();
        editingMb =
            sourceMailbox ??
            editingServerDraftMailbox ??
            mbc.draftsMailbox ??
            client.selectedMailbox ??
            mbc.currentMailbox;
        if (editingMb != null) {
          if (type == 'draft' && msg != null) {
            oldMsg = msg;
            final nonNullOldMsg = msg!;
            DraftSyncService.instance.setStateFor(
              editingMb,
              nonNullOldMsg,
              DraftSyncBadgeState.syncing,
            );
            oldKey = DraftSyncService.instance.keyFor(editingMb, nonNullOldMsg);
          } else if (editingServerDraftUid != null) {
            // Best-effort: locate the original message in UI cache for accurate state handling
            final listRef = mbc.emails[editingMb];
            final found = listRef?.firstWhereOrNull(
              (m) => m.uid == editingServerDraftUid,
            );
            if (found != null) {
              debugPrint(
                '[DraftFlow] Found original draft in UI cache by UID=${editingServerDraftUid}',
              );
              oldMsg = found;
              DraftSyncService.instance.setStateFor(
                editingMb,
                found,
                DraftSyncBadgeState.syncing,
              );
              oldKey = DraftSyncService.instance.keyFor(editingMb, found);
            } else {
              // Fall back to key-by-uid when message instance not found
              oldKey = '${editingMb.encodedPath}:${editingServerDraftUid}';
              DraftSyncService.instance.setStateForKey(
                oldKey,
                DraftSyncBadgeState.syncing,
              );
            }
          }
        }
      } catch (_) {}

      debugPrint(
        '[DraftFlow] saveAsDraft begin: session=${composeSessionId}, editingUid=${editingServerDraftUid}, mailbox=${editingMb?.encodedPath ?? editingMb?.path}',
      );

      // Per IMAP best practices: delete old draft first via UID STORE + EXPUNGE, then append updated
      try {
        await _deleteCurrentEditingDraftOnServer();
      } catch (_) {}

      final serverOk = await _saveDraftToServerWithBackoff(
        draftMessage,
        afterSuccess: (appendedSeq) async {
          debugPrint(
            '[DraftFlow] saveAsDraft afterSuccess: appendedId=$appendedSeq (uid or seq depending on server)',
          );
          try {
            // Mark local SQLite draft as synced if present
            if (_currentDraft != null && appendedSeq != null) {
              await storage.markDraftSynced(_currentDraft!.id!, appendedSeq);
            }

            // Resolve Drafts mailbox (best-effort)
            Mailbox? drafts;
            try {
              final mbc = Get.find<MailBoxController>();
              drafts =
                  editingServerDraftMailbox ??
                  mbc.draftsMailbox ??
                  client.selectedMailbox ??
                  mbc.currentMailbox;
              drafts = _canonicalMailbox(drafts);
            } catch (_) {}

            MimeMessage? appended;
            // Hydrate the appended draft into local storage and emit realtime updates for immediate UI refresh
            if (drafts != null) {
              try {
                debugPrint(
                  '[DraftFlow] Hydration: attempting for appendedId=$appendedSeq in mailbox=${drafts.encodedPath}',
                );
                appended = await _postAppendDraftHydration(
                  draftsMailbox: drafts,
                  appendedSequenceId: appendedSeq,
                  composedBody: body,
                  composedIsHtml: isHtml.value,
                );

                // Update DraftSyncService: mark badge as synced, then auto-clear
                if (appended != null) {
                  final key = DraftSyncService.instance.keyFor(
                    drafts,
                    appended,
                  );
                  DraftSyncService.instance.setStateForKey(
                    key,
                    DraftSyncBadgeState.synced,
                  );
                  Future.delayed(
                    const Duration(seconds: 5),
                    () => DraftSyncService.instance.clearKey(key),
                  );
                } else if (appendedSeq != null) {
                  final key = '${drafts.encodedPath}:$appendedSeq';
                  DraftSyncService.instance.setStateForKey(
                    key,
                    DraftSyncBadgeState.synced,
                  );
                  Future.delayed(
                    const Duration(seconds: 5),
                    () => DraftSyncService.instance.clearKey(key),
                  );
                }

                // After successful append, ensure we do not leave duplicates: delete the original server draft by UID (best-effort)
                if (type == 'draft' || editingServerDraftUid != null) {
                  try {
                    final mbc = Get.find<MailBoxController>();
                    // Determine original mailbox of the draft we are replacing
                    final originalMailbox =
                        _canonicalMailbox(editingServerDraftMailbox) ?? drafts;
                    // Ensure correct ORIGINAL mailbox selected for deletion
                    try {
                      if (client.selectedMailbox?.encodedPath !=
                          originalMailbox.encodedPath) {
                        await client.selectMailbox(originalMailbox);
                        debugPrint(
                          '[DraftFlow] Selected original mailbox for purge: ${originalMailbox.encodedPath}',
                        );
                      } else {
                        debugPrint(
                          '[DraftFlow] Original mailbox already selected: ${originalMailbox.encodedPath}',
                        );
                      }
                    } catch (e) {
                      debugPrint(
                        '[DraftFlow][WARN] Selecting original mailbox failed: $e',
                      );
                    }

                    MimeMessage? original = oldMsg;
                    if (original == null && editingServerDraftUid != null) {
                      final listRef = mbc.emails[originalMailbox];
                      original = listRef?.firstWhereOrNull(
                        (m) => m.uid == editingServerDraftUid,
                      );
                      debugPrint(
                        '[DraftFlow] UI cache original lookup by UID=${editingServerDraftUid}: ${original != null}',
                      );
                    }

                    // Update UI list to replace in place when possible (use original mailbox list)
                    if (appended != null) {
                      try {
                        final listRef =
                            mbc.emails[originalMailbox] ?? <MimeMessage>[];
                        int idx = -1;
                        if (original != null) {
                          final o = original;
                          idx = listRef.indexWhere(
                            (m) =>
                                (o.uid != null && m.uid == o.uid) ||
                                (o.sequenceId != null &&
                                    m.sequenceId == o.sequenceId),
                          );
                        }
                        if (idx >= 0) {
                          final app = appended;
                          debugPrint(
                            '[DraftFlow] UI replace in-place at index=$idx for original draft with new appended uid=${app.uid}',
                          );
                          listRef[idx] = app;
                        } else {
                          // fallback to inserting at the top
                          final app = appended;
                          debugPrint(
                            '[DraftFlow] UI insert at top for appended uid=${app.uid} (original index not found)',
                          );
                          listRef.insert(0, app);
                        }
                        mbc.emails[originalMailbox] = listRef;
                        mbc.emails.refresh();
                        mbc.update();
                      } catch (_) {}
                    }

                    // Resolve the original UID if missing via Message-ID search (best-effort)
                    int? originalUid = editingServerDraftUid;
                    if ((originalUid == null || originalUid <= 0) &&
                        msg != null) {
                      debugPrint(
                        '[DraftFlow] Resolving original UID via Message-Id header search',
                      );
                      try {
                        final mid =
                            (msg!.getHeaderValue('message-id') ??
                                    msg!.getHeaderValue('Message-Id'))
                                ?.trim();
                        if (mid != null && mid.isNotEmpty) {
                          final res = await client.searchMessages(
                            MailSearch(
                              mid,
                              SearchQueryType.allTextHeaders,
                              messageType: SearchMessageType.all,
                            ),
                          );
                          final candidates = res.messages;
                          for (final m in candidates) {
                            final mid2 =
                                (m.getHeaderValue('message-id') ??
                                        m.getHeaderValue('Message-Id'))
                                    ?.trim();
                            if (mid2 != null &&
                                mid2 == mid &&
                                (m.uid != null)) {
                              originalUid = m.uid;
                              break;
                            }
                          }
                        }
                      } catch (_) {}
                    }

                    // Purge any draft versions associated with this compose session except the freshly appended one
                    try {
                      final keepUid =
                          appended?.uid; // may be null if hydration by seq only
                      debugPrint(
                        '[DraftFlow] Purging session drafts: keepUid=$keepUid, alsoDeleteOriginalUid=$originalUid, mailbox=${originalMailbox.encodedPath}',
                      );
                      await _purgeSessionDraftsUnsafe(
                        draftsMailbox: originalMailbox,
                        keepUid: keepUid,
                        alsoDeleteOriginalUid: originalUid,
                      );
                    } catch (_) {}

                    // Clear any lingering sync badge for old key
                    if (oldKey != null) {
                      try {
                        DraftSyncService.instance.clearKey(oldKey);
                      } catch (_) {}
                    }
                  } catch (_) {}
                }
              } catch (_) {}
            }

            // Update UI sync state
            syncState.value = DraftSyncState.synced;
            syncHint.value = 'draft_synced'.tr;
            // Clear any lingering old-key syncing badges
            try {
              if (oldKey != null) DraftSyncService.instance.clearKey(oldKey);
            } catch (_) {}
          } catch (_) {
            // keep UI state consistent even if post-append hydration fails
            syncState.value = DraftSyncState.synced;
          }
        },
      );

      debugPrint('[DraftFlow] saveAsDraft finished: serverOk=$serverOk');
      if (!serverOk) {
        // Server save failed after retries; keep local draft but inform user
        EasyLoading.dismiss();
        EasyLoading.showError('save_error'.tr);
        _draftStatus.value = 'save_error'.tr;
        update();
        return;
      }

      // Update state after confirmed server save
      _hasUnsavedChanges.value = false;
      _draftStatus.value = 'draft_saved'.tr;
      _lastSavedTime.value = _formatSaveTime(DateTime.now());
      _showDraftOptions.value = true;
      canPop.value = true;

      // Update baseline fingerprint so subsequent autosaves do nothing until user edits again
      try {
        final currentBody =
            isHtml.value ? await _safeGetHtmlText() : plainTextController.text;
        _setBaselineFingerprint(body: currentBody, isHtml: isHtml.value);
      } catch (_) {}

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
      final draft = _createDraftModel(
        body,
      ).copyWith(isScheduled: true, scheduledFor: scheduledTime);

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
    if (isBusy.value || isSending.value) return;

    final _req =
        'req-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(0x7fffffff)}';
    try {
      // Telemetry: send attempt
      try {
        _content ??= getIt.isRegistered<MessageContentUseCase>()
            ? getIt<MessageContentUseCase>()
            : null;
        final acct = (_content ?? getIt<MessageContentUseCase>()).accountEmail;
        final folderId =
            sourceMailbox?.encodedPath ?? sourceMailbox?.name ?? 'INBOX';
        Telemetry.event(
          'send_attempt',
          props: {
            'request_id': _req,
            'op': 'send_email',
            'folder_id': folderId,
            'lat_ms': 0,
            'account_id_hash': Hashing.djb2(acct).toString(),
          },
        );
      } catch (_) {}
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
      isSending.value = true;
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

      // Set message content (avoid empty multipart/alternative)
      final String htmlCandidate = isHtml.value ? body.trim() : '';
      final String plainCandidate =
          isHtml.value ? _removeHtmlTags(body).trim() : body.trim();
      if (htmlCandidate.isEmpty && plainCandidate.isEmpty) {
        messageBuilder.addMultipartAlternative(htmlText: null, plainText: ' ');
      } else {
        messageBuilder.addMultipartAlternative(
          htmlText: htmlCandidate.isNotEmpty ? htmlCandidate : null,
          plainText: plainCandidate.isNotEmpty ? plainCandidate : null,
        );
      }

      // Set message metadata
      messageBuilder.to = toList.toList();
      messageBuilder.cc = cclist.toList();
      messageBuilder.bcc = bcclist.toList();
      messageBuilder.subject = subjectController.text;
      // RFC-compliant From header via enough_mail's MailAddress. If name is empty, only the email will be used.
      messageBuilder.from = [MailAddress(name, email)];
      messageBuilder.date = DateTime.now();

      // Add read receipt if enabled
      if (Get.find<SettingController>().readReceipts()) {
        messageBuilder.requestReadReceipt();
      }

      // Build message
      final message = messageBuilder.buildMimeMessage();
      // Ensure top-level transfer-encoding is safe for multipart containers
      _normalizeTopLevelTransferEncoding(message);

      // P12.1: delegate orchestration to presentation ViewModel
      final vm = getIt<ComposeViewModel>();
      final sendOk = await vm.send(
        controller: this,
        builtMessage: message,
        requestId: _req,
      );

      if (!sendOk) {
        throw Exception('error_sending_email'.tr);
      }

      // Delete local draft record only after successful send+append
      if (_currentDraft?.id != null) {
        try {
          await Get.find<SQLiteDraftRepository>().deleteDraft(
            _currentDraft!.id!,
          );
        } catch (_) {}
      }

      // Update state
      _hasUnsavedChanges.value = false;
      canPop.value = true;

      EasyLoading.dismiss();
      EasyLoading.showSuccess('message_sent'.tr);

      // After sending, purge all remaining drafts belonging to this compose session from Drafts mailbox (best-effort)
      try {
        final mbc = Get.find<MailBoxController>();
        final drafts =
            _canonicalMailbox(editingServerDraftMailbox ?? sourceMailbox) ??
            mbc.draftsMailbox ??
            client.selectedMailbox ??
            mbc.currentMailbox;
        if (drafts != null) {
          await _purgeSessionDrafts(
            draftsMailbox: drafts,
            keepUid: null,
            alsoDeleteOriginalUid: editingServerDraftUid,
            keepMostRecentCount: 0,
          );
        }
      } catch (_) {}

      // Close compose screen
      Get.back();
    } catch (e) {
      EasyLoading.dismiss();
      _showErrorDialog(e.toString());
    } finally {
      isSending.value = false;
      isBusy.value = false;
      update();
    }
  }

  // HELPER METHODS (CONSOLIDATED - REMOVED DUPLICATES)

  // Ensure server-pending attachments are included in the next APPEND by hydrating and adding them to the MessageBuilder.
  // This does NOT modify the UI attachments list to avoid side-effects during save/autosave; it only augments the outgoing message.
  Future<void> _attachPendingServerAttachmentsToBuilder(
    MessageBuilder builder, {
    int maxBytes = _attachmentAutoHydrationLimitBytes,
  }) async {
    try {
      if (pendingDraftAttachments.isEmpty || msg == null) return;

      // Build a set of current local attachment file names to avoid duplicates
      final localNames =
          attachments.map((f) => p.basename(f.path).toLowerCase()).toSet();
      final mbc = Get.find<MailBoxController>();
      final Mailbox? mailboxHint =
          _canonicalMailbox(editingServerDraftMailbox ?? sourceMailbox) ??
          mbc.draftsMailbox ??
          client.selectedMailbox ??
          mbc.currentMailbox;
      if (mailboxHint == null) return;

      for (final meta in pendingDraftAttachments) {
        final fname = (meta.fileName).trim();
        if (fname.isEmpty) continue;
        if (localNames.contains(fname.toLowerCase()))
          continue; // already attached locally
        final size = meta.size ?? 0;
        if (size > 0 && size > maxBytes) {
          // Skip very large attachments during autosave/manual save add-on to avoid heavy fetches
          // User can explicitly reattach via UI when desired
          continue;
        }
        final info = _resolveContentInfo(meta.fetchId);
        if (info == null) continue;
        try {
          final bytes = await AttachmentFetcher.fetchBytes(
            message: msg!,
            content: info,
            mailbox: mailboxHint,
          );
          if (bytes == null || bytes.isEmpty) continue;
          // Write to a temporary file so we can reuse addFile API
          final tmpDir = await getTemporaryDirectory();
          final safeName = fname.replaceAll(RegExp(r'[\\/\\]'), '_');
          final filePath = p.join(
            tmpDir.path,
            'attach_${DateTime.now().microsecondsSinceEpoch}_$safeName',
          );
          final f = File(filePath);
          await f.writeAsBytes(bytes, flush: true);
          await builder.addFile(f, MediaType.guessFromFileName(filePath));
        } catch (_) {
          // Ignore per-attachment failures; continue with others
        }
      }
    } catch (_) {}
  }

  // Persist the latest edited content to offline store for the current draft message (if identifiable)
  Future<void> _persistOfflineContentForCurrentDraft({
    required String body,
    required bool html,
  }) async {
    try {
      // Resolve mailbox and uid for the current draft message
      final mbc = Get.find<MailBoxController>();
      final mailboxHint =
          sourceMailbox ??
          editingServerDraftMailbox ??
          mbc.draftsMailbox ??
          client.selectedMailbox ??
          mbc.currentMailbox;
      final int? uid = msg?.uid ?? editingServerDraftUid;
      if (mailboxHint == null || uid == null || uid <= 0) return;

      String? plain;
      String? safeHtml;
      if (html) {
        // Optionally sanitize or simply store as-is for quick reopen
        safeHtml = body;
        plain = _removeHtmlTags(body);
      } else {
        plain = body;
        safeHtml = null;
      }

      await MessageContentStore.instance.upsertContent(
          accountEmail: accountEmail,
          mailboxPath:
            mailboxHint.encodedPath.isNotEmpty
                ? mailboxHint.encodedPath
                : (mailboxHint.path),
        uidValidity: mailboxHint.uidValidity ?? 0,
        uid: uid,
        plainText: plain,
        htmlSanitizedBlocked: safeHtml,
        sanitizedVersion: 2,
        forceMaterialize: false,
      );
    } catch (_) {}
  }

  // Mark content as changed and needing save
  void _markAsChanged() {
    // Schedule realtime projection into Drafts list so tiles update instantly
    _scheduleRealtimeProjection();
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
    if (!_hasUnsavedChanges.value || isBusy.value || _isAutosaving.value)
      return;

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

      // Bail out if unchanged vs baseline
      try {
        final fp = _computeFingerprintFrom(body: body, isHtml: isHtml.value);
        if (_lastSavedFingerprint != null && _lastSavedFingerprint == fp) {
          _draftStatus.value = '';
          _isAutosaving.value = false;
          update();
          return;
        }
      } catch (_) {}

      // Keep bodyPart in sync for fast previews
      try {
        bodyPart = isHtml.value ? body : _convertPlainToHtml(body);
      } catch (_) {}

      // Check if there's enough content to save
      if (!_hasSaveableContent(body)) {
        _draftStatus.value = '';
        return;
      }

      // Create draft model
      final draft = _createDraftModel(body);

      // Persist offline content to reflect the latest edit on quick reopen
      unawaited(
        _persistOfflineContentForCurrentDraft(body: body, html: isHtml.value),
      );

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

      // Update baseline fingerprint to reflect the freshly autosaved content
      try {
        _setBaselineFingerprint(body: body, isHtml: isHtml.value);
      } catch (_) {}

      // Reset status message after a delay
      _statusClearTimer?.cancel();
      _statusClearTimer = Timer(const Duration(seconds: 3), () {
        if (_draftStatus.value == 'draft_saved'.tr) {
          _draftStatus.value = '';
        }
      });

      // Background server autosave using enough_mail helpers (append new, then purge older session copies)
      unawaited(() async {
        try {
          // Build draft MIME from current state
          final builder = MessageBuilder();

          // Include any server-side pending attachments to preserve original draft files
          await _attachPendingServerAttachmentsToBuilder(builder);

          // Add locally selected attachments
          for (final file in attachments) {
            await builder.addFile(file, MediaType.guessFromFileName(file.path));
          }
          final String htmlCandidate = isHtml.value ? body.trim() : '';
          final String plainCandidate =
              isHtml.value ? _removeHtmlTags(body).trim() : body.trim();
          if (htmlCandidate.isEmpty && plainCandidate.isEmpty) {
            builder.addMultipartAlternative(htmlText: null, plainText: ' ');
          } else {
            builder.addMultipartAlternative(
              htmlText: htmlCandidate.isNotEmpty ? htmlCandidate : null,
              plainText: plainCandidate.isNotEmpty ? plainCandidate : null,
            );
          }
          builder.to = toList.toList();
          builder.cc = cclist.toList();
          builder.bcc = bcclist.toList();
          builder.subject = subjectController.text;
          builder.from = [MailAddress(name, email)];
          builder.date = DateTime.now();

          final draftMsg = builder.buildMimeMessage();
          // Tag with compose-session for replace strategy and normalize transfer encoding
          try {
            draftMsg.setHeader('X-Compose-Session', composeSessionId);
          } catch (_) {}
          _normalizeTopLevelTransferEncoding(draftMsg);

          // Per IMAP best practices: delete old draft first via UID STORE + EXPUNGE, then append updated
          try {
            await _deleteCurrentEditingDraftOnServer();
          } catch (_) {}

          await _saveDraftToServerWithBackoff(
            draftMsg,
            afterSuccess: (appendedSeq) async {
              // Resolve Drafts mailbox
              Mailbox? drafts;
              try {
                final mbc = Get.find<MailBoxController>();
                drafts =
                    editingServerDraftMailbox ??
                    mbc.draftsMailbox ??
                    client.selectedMailbox ??
                    mbc.currentMailbox;
                drafts = _canonicalMailbox(drafts);
              } catch (_) {}

              // Hydrate appended message and update editing context
              if (drafts != null) {
                final appended = await _postAppendDraftHydration(
                  draftsMailbox: drafts,
                  appendedSequenceId: appendedSeq,
                  composedBody: body,
                  composedIsHtml: isHtml.value,
                );
                if (appended != null) {
                  // Update references so subsequent autosaves replace the latest version
                  msg = appended;
                  editingServerDraftUid = appended.uid;
                  editingServerDraftMailbox = drafts;
                  // Purge all prior session copies, keeping this one
                  try {
                    await _purgeSessionDraftsUnsafe(
                      draftsMailbox: drafts,
                      keepUid: appended.uid,
                      alsoDeleteOriginalUid: editingServerDraftUid,
                    );
                  } catch (_) {}
                }
              }
            },
          );
        } catch (_) {}
      }());
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
    _suspendChangeTracking = true;
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

    // Establish baseline fingerprint from recovered content
    try {
      _setBaselineFingerprint(body: draft.body, isHtml: draft.isHtml);
    } catch (_) {}

    _suspendChangeTracking = false;

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

  // Quick envelope population for instant-open UX
  void _loadDraftEnvelopeQuick(MimeMessage message) {
    try {
      // Set recipients and subject from envelope only
      toList.clear();
      cclist.clear();
      bcclist.clear();
      if (message.to != null) toList.addAll(message.to!);
      if (message.cc != null) cclist.addAll(message.cc!);
      if (message.bcc != null) bcclist.addAll(message.bcc!);
      // Populate subject with robust fallbacks
      final subj =
          message.decodeSubject() ??
          message.envelope?.subject ??
          message.getHeaderValue('subject') ??
          '';
      // Avoid marking as changed when hydrating UI
      final prev = _suspendChangeTracking;
      _suspendChangeTracking = true;
      subjectController.text = subj;
      _suspendChangeTracking = prev;
      // Mark draft as read immediately for UI consistency
      try {
        message.isSeen = true;
      } catch (_) {}
      try {
        final mbc = Get.find<MailBoxController>();
        final draftsRaw =
            editingServerDraftMailbox ??
            sourceMailbox ??
            mbc.draftsMailbox ??
            client.selectedMailbox ??
            mbc.currentMailbox;
        final drafts = _canonicalMailbox(draftsRaw);
        final st = drafts != null ? mbc.mailboxStorage[drafts] : null;
        if (st != null) {
          unawaited(st.updateEnvelopeFromMessage(message));
        }
      } catch (_) {}
      // Show placeholder status
      _draftStatus.value = 'loading_draft_content'.tr;
      update();
    } catch (e) {
      debugPrint('Error in quick envelope load: $e');
    }
  }

  // Decode a text part by fetching it directly, ignoring broken top-level encodings
  Future<String?> _fetchTextBodyViaPart({
    required MimeMessage message,
    required Mailbox mailbox,
    bool preferHtml = true,
  }) async {
    try {
      // Ensure connection and mailbox selection for part fetch
      try {
        if (!client.isConnected) {
          await client.connect();
        }
        if (client.selectedMailbox?.encodedPath != mailbox.encodedPath) {
          await client.selectMailbox(mailbox);
        }
      } catch (_) {}

      // Collect all parts and filter by content-type string to avoid MediaType construction
      final allInfos = message.findContentInfo().toList();
      bool isHtml(ContentInfo ci) =>
          (ci.contentType?.mediaType.toString().toLowerCase() ?? '').startsWith(
            'text/html',
          );
      bool isPlain(ContentInfo ci) =>
          (ci.contentType?.mediaType.toString().toLowerCase() ?? '').startsWith(
            'text/plain',
          );

      final htmlInfos = allInfos.where(isHtml);
      final plainInfos = allInfos.where(isPlain);
      final candidates = <ContentInfo>[];
      if (preferHtml) {
        candidates
          ..addAll(htmlInfos)
          ..addAll(plainInfos);
      } else {
        candidates
          ..addAll(plainInfos)
          ..addAll(htmlInfos);
      }

      for (final info in candidates) {
        try {
          final part = await client.fetchMessagePart(message, info.fetchId);
          final text = part.decodeContentText();
          if (text != null) {
            final trimmed = text.trim();
            if (trimmed.isNotEmpty && !_looksLikeMimeContainerText(trimmed)) {
              return trimmed;
            }
          }
        } catch (_) {
          // Try next candidate
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Background hydration for body and attachments metadata (non-blocking)
  Future<void> _hydrateDraftInBackground(MimeMessage message) async {
    try {
      debugPrint('Loading draft: ${message.decodeSubject()}');
      _isHydrating = true;
      _suspendChangeTracking = true;

      // First try offline cache to populate content immediately if available
      try {
        final mbc = Get.find<MailBoxController>();
        final mailboxHint =
            sourceMailbox ??
            mbc.draftsMailbox ??
            client.selectedMailbox ??
            mbc.currentMailbox;
        if (mailboxHint != null && (message.uid != null)) {
          final cached = await MessageContentStore.instance.getContent(
            accountEmail: accountEmail,
            mailboxPath:
                mailboxHint.encodedPath.isNotEmpty
                    ? mailboxHint.encodedPath
                    : (mailboxHint.path),
            uidValidity: mailboxHint.uidValidity ?? 0,
            uid: message.uid!,
          );
          if (cached != null) {
            final html = cached.htmlSanitizedBlocked;
            final plain = cached.plainText;
            if (html != null && html.trim().isNotEmpty) {
              isHtml.value = true;
              bodyPart = html;
              await _safeSetHtmlText(html);
            } else if (plain != null && plain.trim().isNotEmpty) {
              isHtml.value = false;
              plainTextController.text = plain;
            }
          }
        }
      } catch (_) {}

      // Prefer fetching the full draft from server via the pooled client to avoid IDLE interference
      MimeMessage base = message;
      MimeMessage? full;
      try {
        final mbc = Get.find<MailBoxController>();
        final mailboxHint =
            sourceMailbox ??
            mbc.draftsMailbox ??
            client.selectedMailbox ??
            mbc.currentMailbox ??
            Mailbox(
              encodedName: 'INBOX',
              encodedPath: 'INBOX',
              flags: [],
              pathSeparator: '/',
            );
        final fetched = await ImapFetchPool.instance.fetchForMessage(
          base: message,
          mailboxHint: mailboxHint,
          fetchPreference: FetchPreference.fullWhenWithinSize,
          timeout: const Duration(seconds: 12),
        );
        if (fetched.isNotEmpty) {
          full = fetched.first;
          base = full;
        }
      } catch (e) {
        debugPrint('Draft full fetch skipped/failed: $e');
      }

      // Keep reference to the current full message for later attachment operations
      msg = base;

      // Update subject from the hydrated message as well (best-effort)
      try {
        final subj = base.decodeSubject();
        if (subj != null && subj.trim().isNotEmpty) {
          subjectController.text = subj;
        }
      } catch (_) {}

      // Body content
      String bodyContent = '';
      bool isHtmlContent = false;

      // Determine if top-level is multipart; if so, never use decodeContentText()
      bool isMultipartTop = false;
      try {
        final topCt = (base.getHeaderValue('content-type') ?? '').toLowerCase();
        isMultipartTop = topCt.contains('multipart/');
      } catch (_) {}

      // Always try dedicated text decoders first
      try {
        final htmlContent = base.decodeTextHtmlPart();
        if (htmlContent != null && htmlContent.trim().isNotEmpty) {
          bodyContent = htmlContent;
          isHtmlContent = true;
        }
      } catch (_) {}
      if (bodyContent.trim().isEmpty) {
        try {
          final plainContent = base.decodeTextPlainPart();
          if (plainContent != null && plainContent.trim().isNotEmpty) {
            bodyContent = plainContent;
            isHtmlContent = false;
          }
        } catch (_) {}
      }

      // As a last resort only for non-multipart messages, try decodeContentText()
      if (bodyContent.trim().isEmpty && !isMultipartTop) {
        try {
          final bodyText = base.decodeContentText();
          if (bodyText != null &&
              bodyText.trim().isNotEmpty &&
              !_looksLikeMimeContainerText(bodyText)) {
            bodyContent = bodyText;
            isHtmlContent = false;
          }
        } catch (_) {}
      }

      // Fallback: fetch text/html or text/plain part directly, ignoring broken top-level CTE
      if (bodyContent.trim().isEmpty ||
          _looksLikeMimeContainerText(bodyContent)) {
        try {
          final mbc = Get.find<MailBoxController>();
          final mailboxHint =
              sourceMailbox ??
              mbc.draftsMailbox ??
              client.selectedMailbox ??
              mbc.currentMailbox;
          if (mailboxHint != null) {
            final fetchedText = await _fetchTextBodyViaPart(
              message: base,
              mailbox: mailboxHint,
              preferHtml: true,
            );
            if (fetchedText != null && fetchedText.trim().isNotEmpty) {
              // Heuristically decide if it looks like HTML
              final looksHtml = RegExp(r'<\w+[^>]*>').hasMatch(fetchedText);
              bodyContent = fetchedText;
              isHtmlContent = looksHtml;
            }
          }
        } catch (_) {}
      }

      if (isHtmlContent && bodyContent.isNotEmpty) {
        isHtml.value = true;
        bodyPart = bodyContent;
        try {
          await _safeSetHtmlText(bodyContent);
        } catch (e) {
          debugPrint('Failed to set HTML content: $e');
          isHtml.value = false;
          plainTextController.text = bodyContent;
        }
      } else if (bodyContent.isNotEmpty) {
        isHtml.value = false;
        plainTextController.text = bodyContent;
      } else {
        isHtml.value = false;
        plainTextController.text = '';
      }

      // 4) Populate pending draft attachments (metadata only). Do NOT download yet.
      try {
        pendingDraftAttachments.clear();
        final infos = base.findContentInfo(
          disposition: ContentDisposition.attachment,
        );
        for (final info in infos) {
          try {
            pendingDraftAttachments.add(
              DraftAttachmentMeta(
                fetchId: info.fetchId,
                fileName: info.fileName ?? 'attachment',
                size: info.size,
                mimeType: info.contentType?.mediaType.toString(),
              ),
            );
          } catch (e) {
            debugPrint('Error adding pending draft attachment: $e');
          }
        }
      } catch (e) {
        debugPrint('Attachment metadata collection failed: $e');
      }

      // 4b) Auto-hydrate small attachments into composer for resend UX
      try {
        final smallMetas = pendingDraftAttachments
            .where(
              (m) =>
                  (m.size ?? 0) > 0 &&
                  (m.size ?? 0) <= _attachmentAutoHydrationLimitBytes,
            )
            .toList(growable: false);
        for (final meta in smallMetas) {
          // Fire-and-forget; individual failures are non-fatal
          unawaited(reattachPendingAttachment(meta));
        }
      } catch (e) {
        debugPrint('Auto-hydration of small attachments failed: $e');
      }

      // Persist sanitized content to offline store for fast re-open
      try {
        final mbc = Get.find<MailBoxController>();
        final mailboxHint =
            sourceMailbox ??
            mbc.draftsMailbox ??
            client.selectedMailbox ??
            mbc.currentMailbox;
        if (mailboxHint != null && (base.uid != null)) {
          String? rawHtml = base.decodeTextHtmlPart();
          String? plain = base.decodeTextPlainPart();
          String? sanitizedHtml;
          if (rawHtml != null && rawHtml.trim().isNotEmpty) {
            // Pre-sanitize large HTML off main thread
            String preprocessed = rawHtml;
            if (rawHtml.length > 100 * 1024) {
              try {
                preprocessed = await MessageContentStore.sanitizeHtmlInIsolate(
                  rawHtml,
                );
              } catch (_) {}
            }
            final enhanced = HtmlEnhancer.enhanceEmailHtml(
              message: base,
              rawHtml: preprocessed,
              darkMode: false,
              blockRemoteImages: true,
              deviceWidthPx: 1024.0,
            );
            sanitizedHtml = enhanced.html;
          }
          if ((sanitizedHtml != null && sanitizedHtml.isNotEmpty) ||
              (plain != null && plain.isNotEmpty)) {
            await MessageContentStore.instance.upsertContent(
              accountEmail: accountEmail,
              mailboxPath:
                  mailboxHint.encodedPath.isNotEmpty
                      ? mailboxHint.encodedPath
                      : (mailboxHint.path),
              uidValidity: mailboxHint.uidValidity ?? 0,
              uid: base.uid ?? -1,
              plainText: plain,
              htmlSanitizedBlocked: sanitizedHtml,
              sanitizedVersion: 2,
              forceMaterialize: false,
            );
          }
        }
      } catch (_) {}

      // 5) Set draft metadata/status and update UI
      _showDraftOptions.value = true;
      _lastSavedTime.value = _formatSaveTime(DateTime.now());
      _hasUnsavedChanges.value = false;
      _draftStatus.value = 'draft_loaded'.tr;

      // Establish baseline fingerprint after hydration to prevent autosave on open
      final baselineBody =
          isHtmlContent ? bodyContent : plainTextController.text;
      _setBaselineFingerprint(body: baselineBody, isHtml: isHtmlContent);

      update();
      debugPrint(
        'Successfully hydrated draft from server: ${base.decodeSubject()}',
      );
    } catch (e) {
      debugPrint('Error loading draft from message: $e');
    } finally {
      _isHydrating = false;
      _suspendChangeTracking = false;
    }
  }

  // Find ContentInfo for a pending attachment by fetchId on the current message
  ContentInfo? _resolveContentInfo(String fetchId) {
    try {
      final m = msg;
      if (m == null) return null;
      final infos = m.findContentInfo(
        disposition: ContentDisposition.attachment,
      );
      return infos.firstWhereOrNull((ci) => ci.fetchId == fetchId);
    } catch (_) {
      return null;
    }
  }

  // Re-attach a pending draft attachment: download bytes and convert to File
  Future<void> reattachPendingAttachment(DraftAttachmentMeta meta) async {
    try {
      final info = _resolveContentInfo(meta.fetchId);
      if (info == null) return;
      final mbc = Get.find<MailBoxController>();
      final Mailbox? mailboxHint =
          sourceMailbox ??
          mbc.draftsMailbox ??
          client.selectedMailbox ??
          mbc.currentMailbox;
      if (mailboxHint == null) {
        debugPrint('Reattach failed: no mailbox available');
        return;
      }
      if ((meta.size ?? 0) > _attachmentAutoHydrationLimitBytes) {
        // Require explicit user action; already explicitly re-attaching, continue
      }
      final data = await AttachmentFetcher.fetchBytes(
        message: msg!,
        content: info,
        mailbox: mailboxHint,
      );
      if (data == null) return;
      final tmpDir = await getTemporaryDirectory();
      final safeName = meta.fileName.replaceAll(RegExp(r'[\/\\]'), '_');
      final filePath = p.join(
        tmpDir.path,
        'draft_${DateTime.now().millisecondsSinceEpoch}_$safeName',
      );
      final f = File(filePath);
      await f.writeAsBytes(data, flush: true);
      attachments.add(f);
      pendingDraftAttachments.removeWhere((x) => x.fetchId == meta.fetchId);
      _markAsChanged();
    } catch (e) {
      debugPrint('Reattach failed: $e');
    }
  }

  // View a pending draft attachment without attaching (temporary open)
  Future<void> viewPendingAttachment(DraftAttachmentMeta meta) async {
    try {
      final info = _resolveContentInfo(meta.fetchId);
      if (info == null) return;
      final mbc = Get.find<MailBoxController>();
      final Mailbox? mailboxHint =
          sourceMailbox ??
          mbc.draftsMailbox ??
          client.selectedMailbox ??
          mbc.currentMailbox;
      if (mailboxHint == null) {
        debugPrint('Preview failed: no mailbox available');
        return;
      }
      if ((meta.size ?? 0) > _attachmentAutoHydrationLimitBytes) {
        EasyLoading.showInfo('attachment_large_tap_to_download'.tr);
      }
      final data = await AttachmentFetcher.fetchBytes(
        message: msg!,
        content: info,
        mailbox: mailboxHint,
      );
      if (data == null) return;
      final tmpDir = await getTemporaryDirectory();
      final safeName = meta.fileName.replaceAll(RegExp(r'[\/\\]'), '_');
      final filePath = p.join(
        tmpDir.path,
        'preview_${DateTime.now().millisecondsSinceEpoch}_$safeName',
      );
      final f = File(filePath);
      await f.writeAsBytes(data, flush: true);
      try {
        OpenAppFile.open(f.path);
      } catch (_) {}
    } catch (e) {
      debugPrint('Preview pending attachment failed: $e');
    }
  }

  Future<void> reattachAllPendingAttachments() async {
    final metas = List<DraftAttachmentMeta>.from(pendingDraftAttachments);
    for (final m in metas) {
      await reattachPendingAttachment(m);
    }
  }

  // Delete the current draft from server (delete) and local storage
  Future<void> discardCurrentDraft() async {
    try {
      await ImapCommandQueue.instance.run('discardCurrentDraft', () async {
        if (type == 'draft' && msg != null) {
          try {
            // Ensure we are operating on the correct Drafts mailbox
            final mbc = Get.find<MailBoxController>();
            final drafts =
                _canonicalMailbox(editingServerDraftMailbox ?? sourceMailbox) ??
                mbc.draftsMailbox ??
                client.selectedMailbox ??
                mbc.currentMailbox;
            if (drafts != null) {
              try {
                if (client.selectedMailbox?.encodedPath != drafts.encodedPath) {
                  await client.selectMailbox(drafts);
                }
              } catch (_) {}
              // Prefer UID-based deletion when possible
              final seq =
                  (msg!.uid != null && msg!.uid! > 0)
                      ? MessageSequence.fromRange(
                        msg!.uid!,
                        msg!.uid!,
                        isUidSequence: true,
                      )
                      : MessageSequence.fromMessage(msg!);
              await client.deleteMessages(seq, expunge: true);
            }
          } catch (_) {}
        }
      });
      if (_currentDraft?.id != null) {
        try {
          await Get.find<SQLiteDraftRepository>().deleteDraft(
            _currentDraft!.id!,
          );
        } catch (_) {}
      }
      canPop.value = true;
      Get.back();
    } catch (e) {
      _showErrorDialog('Failed to discard draft: $e');
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
            TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
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

  // Resolve a canonical mailbox instance for stable map lookups
  Mailbox? _canonicalMailbox(Mailbox? maybe) {
    try {
      final mbc = Get.find<MailBoxController>();
      if (maybe == null) return mbc.draftsMailbox ?? mbc.currentMailbox;
      // Match by encodedPath if possible
      final list = mbc.mailboxes;
      final enc =
          (maybe.encodedPath.isNotEmpty ? maybe.encodedPath : maybe.path)
              .toLowerCase();
      final byPath = list.firstWhereOrNull(
        (m) =>
            (m.encodedPath.isNotEmpty ? m.encodedPath : m.path).toLowerCase() ==
            enc,
      );
      if (byPath != null) return byPath;
      // Fallback: by name or drafts flag
      final byName = list.firstWhereOrNull(
        (m) => m.name.toLowerCase() == maybe.name.toLowerCase(),
      );
      if (byName != null) return byName;
      if (maybe.isDrafts) return mbc.draftsMailbox ?? byName;
      return byName ?? maybe;
    } catch (_) {
      return maybe;
    }
  }

  // Realtime projection of compose changes into Drafts tile (subject/preview/attachment flags)
  void _scheduleRealtimeProjection() {
    _rtProjectionDebounce?.cancel();
    _rtProjectionDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_projectToDraftsListRealtime());
    });
  }

  Future<void> _projectToDraftsListRealtime() async {
    try {
      // Resolve drafts mailbox and message id
      final mbc = Get.find<MailBoxController>();
      final draftsRaw =
          editingServerDraftMailbox ??
          sourceMailbox ??
          mbc.draftsMailbox ??
          client.selectedMailbox ??
          mbc.currentMailbox;
      final drafts = _canonicalMailbox(draftsRaw);
      if (drafts == null) return;

      final uid = msg?.uid ?? editingServerDraftUid;
      if (uid == null || uid <= 0) return;

      // Compute preview from current editor content
      String preview;
      if (isHtml.value) {
        // Use bodyPart to avoid awaiting HTML editor for snappy updates
        preview = _removeHtmlTags(bodyPart);
      } else {
        preview = plainTextController.text;
      }
      preview = preview.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (preview.length > 140) preview = preview.substring(0, 140);

      final hasAtt =
          attachments.isNotEmpty || pendingDraftAttachments.isNotEmpty;

      // Update in-memory meta via DB persistence and bump UI, without touching MIME headers
      try {} catch (_) {}

      // Persist to SQLite for Drafts mailbox
      try {
        // Ensure storage is bound
        if (storage.value == null) {
          storage.value = mbc.mailboxStorage[drafts];
        }
        final st = storage.value;
        if (st != null) {
          await st.updatePreviewAndAttachments(
            uid: uid,
            sequenceId: msg?.sequenceId,
            previewText: preview,
            hasAttachments: hasAtt,
          );

          // Persist subject and mark as seen via envelope/meta update
          final shadow = MimeMessage();
          shadow.uid = uid;
          shadow.sequenceId = msg?.sequenceId;
          shadow.isSeen = true; // Drafts should always be read
          // Synthesize minimal envelope to ensure DB update without modifying MIME headers
          try {
            shadow.envelope = Envelope(
              subject: subjectController.text.trim(),
              from: [MailAddress(name, email)],
              to: toList.toList(),
            );
          } catch (_) {}
          await st.updateEnvelopeFromMessage(shadow);
        }
      } catch (_) {}

      // Bump per-tile notifier so subject/preview refresh immediately
      try {
        // Use msg if available; otherwise a stub with same UID
        final keyMsg = msg ?? (MimeMessage()..uid = uid);
        mbc.bumpMessageMeta(drafts, keyMsg);
      } catch (_) {}
    } catch (_) {}
  }

  /// Prime compose-session header from server headers quickly if missing (keeps continuity across lifecycles)
  Future<void> _primeComposeSessionFromServer({
    required MimeMessage message,
    Mailbox? mailboxHint,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final mbc = Get.find<MailBoxController>();
      final mb =
          mailboxHint ??
          sourceMailbox ??
          editingServerDraftMailbox ??
          mbc.draftsMailbox ??
          client.selectedMailbox ??
          mbc.currentMailbox;
      if (mb == null || message.uid == null) return;
      final fetched = await ImapFetchPool.instance.fetchByUid(
        uid: message.uid!,
        mailboxHint: mb,
        fetchPreference: FetchPreference.fullWhenWithinSize,
        timeout: timeout,
      );
      if (fetched.isNotEmpty) {
        final m = fetched.first;
        final sid =
            m.getHeaderValue('x-compose-session') ??
            m.getHeaderValue('X-Compose-Session');
        if (sid != null && sid.trim().isNotEmpty) {
          _composeSessionId = sid.trim();
          debugPrint(
            '[DraftFlow] Compose session primed from server headers: $_composeSessionId',
          );
        }
      }
    } catch (e) {
      debugPrint('[DraftFlow] Compose session prime failed: $e');
    }
  }

  // Delete all server-side drafts that belong to this compose session, except the one specified by keepUid (if provided).
  // Optionally also deletes a specific original UID if provided (for servers lacking the session header on older copies).
  Future<void> _purgeSessionDrafts({
    required Mailbox draftsMailbox,
    int? keepUid,
    int? alsoDeleteOriginalUid,
    int keepMostRecentCount = 1,
  }) async {
    await ImapCommandQueue.instance.run('purgeSessionDrafts', () async {
      await _purgeSessionDraftsUnsafe(
        draftsMailbox: draftsMailbox,
        keepUid: keepUid,
        alsoDeleteOriginalUid: alsoDeleteOriginalUid,
        keepMostRecentCount: keepMostRecentCount,
      );
    });
  }

  // Unsafe variant used within an existing ImapCommandQueue.run action to avoid deadlocks from nested queue usage.
  Future<void> _purgeSessionDraftsUnsafe({
    required Mailbox draftsMailbox,
    int? keepUid,
    int? alsoDeleteOriginalUid,
    int keepMostRecentCount = 1,
  }) async {
    try {
      // Ensure mailbox selection
      try {
        if (client.selectedMailbox?.encodedPath != draftsMailbox.encodedPath) {
          await client.selectMailbox(draftsMailbox);
        }
      } catch (_) {}

      // Search for all messages with our compose session header
      List<MimeMessage> sessionDrafts = const <MimeMessage>[];
      try {
        debugPrint(
          '[DraftFlow] Purge: searching by X-Compose-Session=${composeSessionId} in mailbox ${draftsMailbox.encodedPath}',
        );
        final res = await client
            .searchMessages(
              MailSearch(
                composeSessionId,
                SearchQueryType.allTextHeaders,
                messageType: SearchMessageType.all,
              ),
            )
            .timeout(const Duration(seconds: 10));
        sessionDrafts = res.messages;
        debugPrint(
          '[DraftFlow] Purge: session matches=${sessionDrafts.length} (uids=${sessionDrafts.map((m) => m.uid).toList()})',
        );
      } catch (_) {}

      // Determine which UIDs to keep
      final toKeepUids = <int>{};
      if (keepUid != null && keepUid > 0) {
        toKeepUids.add(keepUid);
      } else {
        final k = keepMostRecentCount < 0 ? 0 : keepMostRecentCount;
        if (k > 0 && sessionDrafts.isNotEmpty) {
          try {
            final withUids = sessionDrafts.where((m) => m.uid != null).toList();
            if (withUids.isNotEmpty) {
              withUids.sort((a, b) => (b.uid!).compareTo(a.uid!));
              for (final m in withUids.take(k)) {
                if (m.uid != null) toKeepUids.add(m.uid!);
              }
            } else {
              sessionDrafts.sort(
                (a, b) => (b.decodeDate() ??
                        DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
                      a.decodeDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
                    ),
              );
              for (final m in sessionDrafts.take(k)) {
                if (m.uid != null) toKeepUids.add(m.uid!);
              }
            }
            debugPrint(
              '[DraftFlow] Purge: keeping UIDs=${toKeepUids.toList()}',
            );
          } catch (_) {}
        }
      }

      // Collect UIDs to delete (exclude the ones to keep)
      final toDeleteUids = <int>{};
      for (final m in sessionDrafts) {
        final uid = m.uid;
        if (uid != null && !toKeepUids.contains(uid)) {
          toDeleteUids.add(uid);
        }
      }
      if (alsoDeleteOriginalUid != null &&
          alsoDeleteOriginalUid > 0 &&
          !toKeepUids.contains(alsoDeleteOriginalUid)) {
        debugPrint(
          '[DraftFlow] Purge: also including originalUid=$alsoDeleteOriginalUid',
        );
        toDeleteUids.add(alsoDeleteOriginalUid);
      }

      if (toDeleteUids.isEmpty) {
        debugPrint('[DraftFlow] Purge: nothing to delete');
        return;
      }

      // Delete on server (UID EXPUNGE)
      for (final uid in toDeleteUids) {
        try {
          await client.deleteMessages(
            MessageSequence.fromRange(uid, uid, isUidSequence: true),
            expunge: true,
          );
          debugPrint(
            '[DraftFlow] Purge: server deleted uid=$uid (expunge=true)',
          );
        } catch (_) {}
      }

      // Purge from local storage/UI
      try {
        final mbc = Get.find<MailBoxController>();
        final st = mbc.mailboxStorage[draftsMailbox];
        debugPrint(
          '[DraftFlow] Purge: removing from local storage and UI uids=$toDeleteUids',
        );
        for (final uid in toDeleteUids) {
          try {
            await st?.deleteMessageEnvelopes(
              MessageSequence.fromRange(uid, uid, isUidSequence: true),
            );
            debugPrint('[DraftFlow] Purge: local DB deleted uid=$uid');
          } catch (_) {}
        }
        // Remove from in-memory list
        final listRef = mbc.emails[draftsMailbox] ?? <MimeMessage>[];
        listRef.removeWhere(
          (m) => m.uid != null && toDeleteUids.contains(m.uid),
        );
        mbc.emails[draftsMailbox] = listRef;
        mbc.emails.refresh();
        mbc.update();
      } catch (_) {}
    } catch (_) {}
  }

  // Server sync with exponential backoff
  Future<bool> _saveDraftToServerWithBackoff(
    MimeMessage draftMessage, {
    Future<void> Function(int? appendedUid)? afterSuccess,
  }) async {
    return ImapCommandQueue.instance.run('saveDraftWithBackoff', () async {
      const attempts = 3;
      int delayMs = 1200;
      for (int i = 0; i < attempts; i++) {
        try {
          // Resolve Drafts mailbox explicitly and use mailbox-aware API to avoid mis-targeted appends
          Mailbox? drafts;
          try {
            final mbc = Get.find<MailBoxController>();
            // For editing an existing draft, always use its original Drafts mailbox
            drafts =
                editingServerDraftMailbox ??
                mbc.draftsMailbox ??
                client.selectedMailbox ??
                mbc.currentMailbox;
            drafts = _canonicalMailbox(drafts);
          } catch (_) {}
          if (drafts == null) {
            await client.selectMailboxByFlag(MailboxFlag.drafts);
            debugPrint('[DraftFlow] saveDraft: selected Drafts by flag');
          } else {
            try {
              if (client.selectedMailbox?.encodedPath != drafts.encodedPath) {
                await client.selectMailbox(drafts);
                debugPrint(
                  '[DraftFlow] saveDraft: selected Drafts mailbox=${drafts.encodedPath}',
                );
              } else {
                debugPrint(
                  '[DraftFlow] saveDraft: Drafts mailbox already selected=${drafts.encodedPath}',
                );
              }
            } catch (e, st) {
              debugPrint(
                '[DraftFlow][ERROR] Selecting Drafts mailbox failed: $e\n$st',
              );
            }
          }
          debugPrint(
            '[DraftFlow] saveDraft attempt ${i + 1}/$attempts: calling saveDraftMessage (mailbox=${drafts?.encodedPath ?? client.selectedMailbox?.encodedPath ?? '(unknown)'})',
          );
          // Use mailbox-aware API when we have a resolved Drafts mailbox for maximum correctness
          final response =
              (drafts != null)
                  ? await client.saveDraftMessage(
                    draftMessage,
                    draftsMailbox: drafts,
                  )
                  : await client.saveDraftMessage(draftMessage);
          debugPrint(
            '[DraftFlow] saveDraft: saveDraftMessage response received: ${response.runtimeType}',
          );
          // Prefer UIDPLUS UID when available; fallback to target sequence id
          int? appended;
          try {
            appended = (response as dynamic).targetUid as int?;
          } catch (_) {}
          if (appended == null) {
            final ids = response?.targetSequence.toList() ?? const <int>[];
            appended = ids.isNotEmpty ? ids.last : null;
          }
          debugPrint(
            '[DraftFlow] saveDraft: interpreted appended id=${appended ?? '(null)'}',
          );
          if (afterSuccess != null) {
            await afterSuccess(appended);
          }
          return true;
        } catch (e, st) {
          debugPrint(
            '[DraftFlow][ERROR] saveDraft attempt ${i + 1} failed: $e\n$st',
          );
          // Fallback: try appendMessageToFlag(..., MailboxFlag.drafts) with \\Draft flag before failing this attempt
          try {
            Mailbox? drafts;
            try {
              final mbc = Get.find<MailBoxController>();
              drafts =
                  editingServerDraftMailbox ??
                  mbc.draftsMailbox ??
                  client.selectedMailbox ??
                  mbc.currentMailbox;
              drafts = _canonicalMailbox(drafts);
            } catch (_) {}
            if (drafts == null) {
              await client.selectMailboxByFlag(MailboxFlag.drafts);
            } else {
              try {
                if (client.selectedMailbox?.encodedPath != drafts.encodedPath) {
                  await client.selectMailbox(drafts);
                }
              } catch (_) {}
            }
            // Append directly to Drafts with standard \Draft flag
            await client.appendMessageToFlag(
              draftMessage,
              MailboxFlag.drafts,
              flags: [MessageFlags.draft],
            );
            debugPrint(
              '[DraftFlow] Fallback append to Drafts via flag succeeded',
            );
            if (afterSuccess != null) {
              await afterSuccess(null);
            }
            return true;
          } catch (e2, st2) {
            debugPrint(
              '[DraftFlow][ERROR] Fallback append failed on attempt ${i + 1}: $e2\n$st2',
            );
            // If even fallback failed, apply backoff or final failure
          }

          if (i == attempts - 1) {
            syncState.value = DraftSyncState.failed;
            syncHint.value = 'sync_failed_retry_later'.tr;
            // Update DraftSyncService for existing draft key, then auto-clear to avoid stuck UI
            try {
              final mbc = Get.find<MailBoxController>();
              final mailboxHint =
                  sourceMailbox ??
                  editingServerDraftMailbox ??
                  mbc.draftsMailbox ??
                  client.selectedMailbox ??
                  mbc.currentMailbox;
              if (mailboxHint != null) {
                if (type == 'draft' && msg != null) {
                  DraftSyncService.instance.setStateFor(
                    mailboxHint,
                    msg!,
                    DraftSyncBadgeState.failed,
                  );
                  Future.delayed(
                    const Duration(seconds: 8),
                    () => DraftSyncService.instance.clearFor(mailboxHint, msg!),
                  );
                } else if (editingServerDraftUid != null) {
                  final key =
                      '${mailboxHint.encodedPath}:${editingServerDraftUid}';
                  DraftSyncService.instance.setStateForKey(
                    key,
                    DraftSyncBadgeState.failed,
                  );
                  Future.delayed(
                    const Duration(seconds: 8),
                    () => DraftSyncService.instance.clearKey(key),
                  );
                }
              }
            } catch (e3, st3) {
              debugPrint(
                '[DraftFlow][WARN] Updating DraftSyncService after failure failed: $e3\n$st3',
              );
            }
            debugPrint(
              '[DraftFlow][ERROR] Draft server sync failed after $attempts attempts: $e',
            );
            return false;
          }
          await Future.delayed(Duration(milliseconds: delayMs));
          delayMs *= 2;
        }
      }
      // Should not reach here, but return false defensively
      return false;
    });
  }

  // After a successful APPEND to the Drafts mailbox, fetch the new message envelope
  // and persist it to SQLite + emit realtime updates, so the Drafts list updates instantly.
  Future<MimeMessage?> _postAppendDraftHydration({
    required Mailbox draftsMailbox,
    int? appendedSequenceId,
    String? composedBody,
    bool composedIsHtml = true,
  }) async {
    MimeMessage? appended;
    try {
      List<MimeMessage> fetched = const <MimeMessage>[];

      // Prefer UID-based hydration when we have an appended id
      if (appendedSequenceId != null) {
        // First, try treating the id as UID (UIDPLUS)
        debugPrint('[DraftFlow] Hydration attempt as UID: $appendedSequenceId');
        fetched = await ImapFetchPool.instance.fetchByUid(
          uid: appendedSequenceId,
          mailboxHint: draftsMailbox,
          fetchPreference: FetchPreference.envelope,
          timeout: const Duration(seconds: 8),
        );
        if (fetched.isNotEmpty) {
          appended = fetched.first;
          debugPrint(
            '[DraftFlow] Hydration by UID succeeded: uid=${appended.uid}, seq=${appended.sequenceId}',
          );
        } else {
          // Fallback: try as server sequence id
          debugPrint(
            '[DraftFlow] Hydration fallback as SEQ: $appendedSequenceId',
          );
          fetched = await ImapFetchPool.instance.fetchBySequence(
            sequence: MessageSequence.fromId(appendedSequenceId),
            mailboxHint: draftsMailbox,
            fetchPreference: FetchPreference.envelope,
            timeout: const Duration(seconds: 8),
          );
          if (fetched.isNotEmpty) {
            appended = fetched.first;
            debugPrint(
              '[DraftFlow] Hydration by SEQ succeeded: uid=${appended.uid}, seq=${appended.sequenceId}',
            );
          }
        }
      }

      // Fallback: prefer searching by compose session header to precisely identify the latest version
      if (appended == null) {
        debugPrint(
          '[DraftFlow] Hydration fallback: searching by X-Compose-Session=${composeSessionId}',
        );
        try {
          final res = await client
              .searchMessages(
                MailSearch(
                  composeSessionId,
                  SearchQueryType.allTextHeaders,
                  messageType: SearchMessageType.all,
                ),
              )
              .timeout(const Duration(seconds: 8));
          final found = res.messages;
          if (found.isNotEmpty) {
            debugPrint(
              '[DraftFlow] Session search matched ${found.length} drafts; taking newest',
            );
            // Choose the newest by decodeDate where available
            found.sort(
              (a, b) => (b.decodeDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                    a.decodeDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
                  ),
            );
            appended = found.first;
          }
        } catch (_) {}
      }

      // Fallback: scan most recent messages and match by subject + recency
      if (appended == null) {
        debugPrint(
          '[DraftFlow] Hydration final fallback: scanning recents for subject match',
        );
        try {
          final recent = await ImapFetchPool.instance.fetchRecent(
            mailboxHint: draftsMailbox,
            count: 25,
            timeout: const Duration(seconds: 10),
          );
          if (recent.isNotEmpty) {
            final subj = subjectController.text.trim();
            for (final m in recent) {
              String? ms =
                  m.decodeSubject() ??
                  m.envelope?.subject ??
                  m.getHeaderValue('subject');
              if ((ms ?? '').trim() == subj) {
                final d = m.decodeDate();
                if (d != null && DateTime.now().difference(d).inMinutes <= 5) {
                  appended = m;
                  break;
                }
              }
            }
          }
        } catch (_) {}
      }

      if (appended == null) return null;
      // Capture non-null for closure usage
      final app = appended;

      // Ensure the composed session header is present on the in-memory message for downstream logic
      try {
        appended.setHeader('X-Compose-Session', composeSessionId);
      } catch (_) {}

      // Persist to SQLite storage for Drafts mailbox if available
      try {
        final mbc = Get.find<MailBoxController>();
        final storage = mbc.mailboxStorage[draftsMailbox];
        if (storage != null) {
          await storage.saveMessageEnvelopes([appended]);
          // Immediately mark as seen in local DB as drafts should be read
          try {
            appended.isSeen = true;
            await storage.updateEnvelopeFromMessage(appended);
          } catch (_) {}
        }
      } catch (_) {}

      // Persist composed body to offline content store under the new appended UID for immediate reopen
      try {
        if (appended.uid != null &&
            appended.uid! > 0 &&
            composedBody != null &&
            composedBody.trim().isNotEmpty) {
          String? htmlSan;
          String? plain;
          if (composedIsHtml) {
            // Sanitize HTML for safe offline rendering
            String pre = composedBody;
            if (pre.length > 100 * 1024) {
              try {
                pre = await MessageContentStore.sanitizeHtmlInIsolate(pre);
              } catch (_) {}
            }
            final enhanced = HtmlEnhancer.enhanceEmailHtml(
              message: appended,
              rawHtml: pre,
              darkMode: false,
              blockRemoteImages: true,
              deviceWidthPx: 1024.0,
            );
            htmlSan = enhanced.html;
            plain = _removeHtmlTags(composedBody);
          } else {
            plain = composedBody;
            htmlSan = null;
          }
          await MessageContentStore.instance.upsertContent(
            accountEmail: accountEmail,
            mailboxPath:
                draftsMailbox.encodedPath.isNotEmpty
                    ? draftsMailbox.encodedPath
                    : (draftsMailbox.path),
            uidValidity: draftsMailbox.uidValidity ?? 0,
            uid: appended.uid!,
            plainText: plain,
            htmlSanitizedBlocked: htmlSan,
            sanitizedVersion: 2,
            forceMaterialize: false,
          );
        }
      } catch (_) {}

      // Emit realtime updates to update any observers
      try {
        await RealtimeUpdateService.instance.notifyNewMessages([
          appended,
        ], mailbox: draftsMailbox);
      } catch (_) {}

      // Best-effort: mark the appended draft as seen on server
      try {
        // Avoid nested queue.run deadlock by executing directly within current queue action
        if (client.selectedMailbox?.encodedPath != draftsMailbox.encodedPath) {
          await client.selectMailbox(draftsMailbox);
          debugPrint(
            '[DraftFlow] Marking appended draft as seen on server in mailbox ${draftsMailbox.encodedPath}',
          );
        }
        await client.markSeen(MessageSequence.fromMessage(app));
      } catch (_) {}

      // Update the in-memory list for the Drafts mailbox to keep a single item updated in place
      try {
        final mbc = Get.find<MailBoxController>();
        final listRef = mbc.emails[draftsMailbox] ?? <MimeMessage>[];
        // Try to find an existing draft by the original editing UID if available
        int idx = -1;
        if (editingServerDraftUid != null) {
          idx = listRef.indexWhere((m) => m.uid == editingServerDraftUid);
        }
        if (idx < 0) {
          idx = listRef.indexWhere(
            (m) =>
                (m.uid != null && m.uid == app.uid) ||
                (m.sequenceId != null && m.sequenceId == app.sequenceId),
          );
        }
        if (idx >= 0) {
          debugPrint(
            '[DraftFlow] Drafts list updated in place for appended uid=${app.uid}',
          );
          listRef[idx] = app;
        } else {
          debugPrint(
            '[DraftFlow] Drafts list inserted new appended uid=${app.uid} at top',
          );
          listRef.insert(0, app);
        }
        mbc.emails[draftsMailbox] = listRef;
        mbc.emails.refresh();
        mbc.update();
      } catch (_) {}
    } catch (_) {
      // Non-fatal; UI has already been marked as synced
      return null;
    }
    return appended;
  }

  // Delete the currently-editing server draft by UID using UID STORE + EXPUNGE semantics
  Future<void> _deleteCurrentEditingDraftOnServer() async {
    return ImapCommandQueue.instance.run('deleteCurrentEditingDraft', () async {
      try {
        final mbc = Get.find<MailBoxController>();
        final drafts =
            _canonicalMailbox(editingServerDraftMailbox ?? sourceMailbox) ??
            mbc.draftsMailbox ??
            client.selectedMailbox ??
            mbc.currentMailbox;
        final uid = editingServerDraftUid ?? msg?.uid;

        if (drafts == null || uid == null || uid <= 0) {
          debugPrint(
            '[DraftFlow][Delete] Skip: drafts=${drafts?.encodedPath ?? '(null)'} uid=${uid ?? -1}',
          );
          return;
        }

        // Ensure the correct mailbox is selected for deletion
        if (client.selectedMailbox?.encodedPath != drafts.encodedPath) {
          try {
            await client.selectMailbox(drafts);
            debugPrint(
              '[DraftFlow][Delete] Selected mailbox: ${drafts.encodedPath}',
            );
          } catch (e, st) {
            debugPrint(
              '[DraftFlow][Delete][ERROR] Selecting mailbox failed: $e\n$st',
            );
          }
        } else {
          debugPrint(
            '[DraftFlow][Delete] Mailbox already selected: ${drafts.encodedPath}',
          );
        }

        // UID STORE + EXPUNGE via deleteMessages(expunge: true)
        final seq = MessageSequence.fromRange(uid, uid, isUidSequence: true);
        try {
          await client.deleteMessages(seq, expunge: true);
          debugPrint(
            '[DraftFlow][Delete] Server delete+expunge OK for uid=$uid in ${drafts.encodedPath}',
          );
        } catch (e, st) {
          debugPrint(
            '[DraftFlow][Delete][ERROR] Server UID delete failed for uid=$uid: $e\n$st',
          );
          // Fallback: map UID -> sequence number and delete by sequence if the server doesn't accept UID STORE
          try {
            // Ensure correct mailbox still selected before fallback fetch
            try {
              if (client.selectedMailbox?.encodedPath != drafts.encodedPath) {
                await client.selectMailbox(drafts);
              }
            } catch (_) {}
            final fetched = await client.fetchMessageSequence(
              MessageSequence.fromRange(uid, uid, isUidSequence: true),
              fetchPreference: FetchPreference.envelope,
            );
            if (fetched.isNotEmpty) {
              final seqId = fetched.first.sequenceId;
              if (seqId != null && seqId > 0) {
                try {
                  await client.deleteMessages(
                    MessageSequence.fromRange(seqId, seqId),
                    expunge: true,
                  );
                  debugPrint(
                    '[DraftFlow][Delete] Fallback delete+expunge by sequence OK for uid=$uid (seq=$seqId)',
                  );
                } catch (e2, st2) {
                  debugPrint(
                    '[DraftFlow][Delete][ERROR] Fallback delete by sequence failed (uid=$uid, seq=$seqId): $e2\n$st2',
                  );
                }
              } else {
                debugPrint(
                  '[DraftFlow][Delete][WARN] Could not resolve sequenceId for uid=$uid in ${drafts.encodedPath}',
                );
              }
            } else {
              debugPrint(
                '[DraftFlow][Delete][WARN] Fetch by UID returned no message for uid=$uid in ${drafts.encodedPath}',
              );
            }
          } catch (e3, st3) {
            debugPrint(
              '[DraftFlow][Delete][ERROR] UID->SEQ resolution failed for uid=$uid: $e3\n$st3',
            );
          }
        }

        // Local UI and storage cleanup (best-effort)
        try {
          final stg = mbc.mailboxStorage[drafts];
          await stg?.deleteMessageEnvelopes(
            MessageSequence.fromRange(uid, uid, isUidSequence: true),
          );
          final listRef = mbc.emails[drafts] ?? <MimeMessage>[];
          final before = listRef.length;
          listRef.removeWhere((m) => m.uid == uid);
          final after = listRef.length;
          mbc.emails[drafts] = listRef;
          mbc.emails.refresh();
          mbc.update();
          debugPrint(
            '[DraftFlow][Delete] Local purge removed ${(before - after).clamp(0, before)} item(s) for uid=$uid',
          );
        } catch (e, st) {
          debugPrint(
            '[DraftFlow][Delete][WARN] Local purge failed for uid=$uid: $e\n$st',
          );
        }
      } catch (e, st) {
        debugPrint('[DraftFlow][Delete][ERROR] Unexpected error: $e\n$st');
      }
    });
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

// Lightweight metadata model for pending draft attachments (server-side until reattached)
class DraftAttachmentMeta {
  final String fetchId;
  final String fileName;
  final int? size;
  final String? mimeType;
  DraftAttachmentMeta({
    required this.fetchId,
    required this.fileName,
    this.size,
    this.mimeType,
  });
}
