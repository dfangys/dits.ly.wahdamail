import 'dart:async';

import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';
import 'package:wahda_bank/views/compose/compose_view.dart';
import 'package:wahda_bank/utills/extensions/overlay_extensions.dart';

import '../../widgets/empty_box.dart';

class DraftView extends StatefulWidget {
  const DraftView({super.key});

  @override
  State<DraftView> createState() => _DraftViewState();
}

class _DraftViewState extends State<DraftView> with SingleTickerProviderStateMixin {
  final StreamController<List<MimeMessage>> _streamController =
  StreamController<List<MimeMessage>>.broadcast();
  final MailService service = MailService.instance;
  late Mailbox mailbox;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller for smooth transitions
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Load drafts mailbox and fetch emails
    _initDrafts();
  }

  Future<void> _initDrafts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      service.client.selectMailboxByFlag(MailboxFlag.drafts).then((box) {
        mailbox = box;
        fetchMail();
      });
    } catch (e) {
      _streamController.addError(e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<MimeMessage> emails = [];
  int page = 1;
  bool _hasMoreEmails = true;

  Future<void> fetchMail() async {
    try {
      emails.clear();
      page = 1;
      _hasMoreEmails = true;

      mailbox = await service.client.selectMailboxByFlag(MailboxFlag.drafts);
      int maxExist = mailbox.messagesExists;

      if (maxExist == 0) {
        // No drafts exist
        emails = [];
        _streamController.add(emails);
        setState(() {
          _isLoading = false;
        });
        _animationController.forward();
        return;
      }

      await _loadNextPage(maxExist);

      setState(() {
        _isLoading = false;
      });
      _animationController.forward();

    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not load drafts: ${e.toString()}',
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 3),
      );

      if (emails.isEmpty) {
        _streamController.addError(e);
      }

      setState(() {
        _isLoading = false;
      });
      _animationController.forward();
    }
  }

  Future<void> _loadNextPage(int maxExist) async {
    if (!_hasMoreEmails) return;

    try {
      // Calculate page size based on screen height for better performance
      final pageSize = (MediaQuery.of(Get.context!).size.height / 80).floor();

      MessageSequence sequence = MessageSequence.fromPage(page, pageSize, maxExist);
      List<MimeMessage> fetched = await queue(sequence);

      if (fetched.isEmpty) {
        _hasMoreEmails = false;
        return;
      }

      emails.addAll(fetched);
      emails = emails.sorted((a, b) => b.decodeDate()!.compareTo(a.decodeDate()!));
      _streamController.add(emails);

      page++;

      // Check if we've loaded all emails
      if (emails.length >= maxExist) {
        _hasMoreEmails = false;
      }
    } catch (e) {
      _hasMoreEmails = false;
      rethrow;
    }
  }

  Future<List<MimeMessage>> queue(MessageSequence sequence) async {
    // Use a try-catch block to handle potential errors
    try {
      return await service.client.fetchMessageSequence(
        sequence,
        // Removed fetchPreference parameter for compatibility
      );
    } catch (e) {
      // Log the error for debugging
      debugPrint('Error fetching message sequence: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'drafts'.tr,
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit_note_rounded,
              color: AppTheme.primaryColor,
            ),
            onPressed: () {
              // Create a new draft
              Get.to(() => const ComposeView());
            },
            tooltip: 'New Draft',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryColor,
          backgroundColor: AppTheme.surfaceColor,
          strokeWidth: 2,
          onRefresh: () async {
            _animationController.reverse();
            await Future.delayed(const Duration(milliseconds: 300));
            emails.clear();
            await fetchMail();
          },
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: child,
              );
            },
            child: StreamBuilder<List<MimeMessage>>(
              stream: _streamController.stream,
              builder: (context, snapshot) {
                if (_isLoading) {
                  return const TAnimationLoaderWidget(
                    text: 'Loading your drafts...',
                    animation: 'assets/lottie/search.json',
                    showAction: false,
                  );
                } else if (snapshot.hasData) {
                  if (snapshot.data!.isEmpty) {
                    return TAnimationLoaderWidget(
                      text: 'No drafts found',
                      animation: 'assets/lottie/empty.json',
                      showAction: true,
                      actionText: 'create_new'.tr,
                      onActionPressed: () {
                        Get.to(() => const ComposeView());
                      },
                    );
                  }

                  return _buildDraftsList(snapshot.data!);

                } else if (snapshot.hasError) {
                  return TAnimationLoaderWidget(
                    text: 'Could not load drafts',
                    animation: 'assets/lottie/error.json',
                    showAction: true,
                    actionText: 'try_again'.tr,
                    onActionPressed: () {
                      _animationController.reverse();
                      Future.delayed(const Duration(milliseconds: 300), () {
                        fetchMail();
                      });
                    },
                  );
                }

                return const TAnimationLoaderWidget(
                  text: 'Loading...',
                  animation: 'assets/lottie/search.json',
                  showAction: false,
                );
              },
            ),
          ),
        ),
      ),
      // Floating action button for creating new draft
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(() => const ComposeView());
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.edit_outlined),
        elevation: 2,
      ),
    );
  }

  Widget _buildDraftsList(List<MimeMessage> drafts) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: drafts.length + (_hasMoreEmails ? 1 : 0),
      separatorBuilder: (context, index) {
        if (index >= drafts.length) return const SizedBox.shrink();
        return Divider(
          color: Colors.grey.shade200,
          height: 1,
          indent: 64,
          endIndent: 16,
        );
      },
      itemBuilder: (context, index) {
        // Show loading indicator at the end if more emails are available
        if (index == drafts.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryColor,
              ),
            ),
          );
        }

        return _buildDraftTile(drafts[index]);
      },
    );
  }

  Widget _buildDraftTile(MimeMessage draft) {
    // Extract subject or use placeholder
    final subject = draft.decodeSubject() ?? '(No subject)';

    // Extract recipients
    final recipients = draft.to?.map((e) => e.email).join(', ') ?? '';

    // Extract date
    final date = draft.decodeDate() ?? DateTime.now();

    return Card(
      elevation: 0,
      color: AppTheme.surfaceColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Open draft for editing
          Get.to(() => ComposeView(draftMessage: draft));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Draft icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Draft content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject
                    Text(
                      subject,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Recipients
                    if (recipients.isNotEmpty)
                      Text(
                        'To: $recipients',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),

                    // Last edited time
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(date),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                      size: 20,
                    ),
                    onPressed: () {
                      _confirmDeleteDraft(draft);
                    },
                    tooltip: 'Delete Draft',
                    splashRadius: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      // Format as time if today
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      // Format as date
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _confirmDeleteDraft(MimeMessage draft) {
    Get.dialog(
      AlertDialog(
        title: Text(
          'Delete Draft',
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this draft?',
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _deleteDraft(draft);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppTheme.surfaceColor,
      ),
    );
  }

  Future<void> _deleteDraft(MimeMessage draft) async {
    try {
      // Show loading indicator
      final loadingOverlay = _showLoadingOverlay('Deleting draft...');

      // Delete the draft
      await service.client.deleteMessage(draft);

      // Remove from local list and update stream
      emails.remove(draft);
      _streamController.add(emails);

      // Hide loading indicator
      loadingOverlay.dismiss();

      // Show success message
      Get.snackbar(
        'Success',
        'Draft deleted successfully',
        backgroundColor: Colors.green.withOpacity(0.9),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not delete draft: ${e.toString()}',
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 3),
      );
    }
  }

  // Helper method to show loading overlay
  OverlayEntry _showLoadingOverlay(String message) {
    final overlay = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    return overlay;
  }

  @override
  void dispose() {
    _streamController.close();
    _animationController.dispose();
    super.dispose();
  }
}
