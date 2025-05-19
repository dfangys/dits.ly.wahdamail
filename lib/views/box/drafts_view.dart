import 'dart:async';

import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';

import '../../widgets/empty_box.dart';

class DraftView extends StatefulWidget {
  const DraftView({super.key});

  @override
  State<DraftView> createState() => _DraftViewState();
}

class _DraftViewState extends State<DraftView> {
  final StreamController<List<MimeMessage>> _streamController =
  StreamController<List<MimeMessage>>.broadcast();
  final MailService service = MailService.instance;
  late Mailbox mailbox;

  @override
  void initState() {
    service.client.selectMailboxByFlag(MailboxFlag.drafts).then((box) {
      mailbox = box;
      fetchMail();
    });
    super.initState();
  }

  List<MimeMessage> emails = [];
  int page = 1;
  bool _isLoading = true;

  Future fetchMail() async {
    try {
      setState(() {
        _isLoading = true;
      });

      emails.clear();
      page = 1;
      mailbox = await service.client.selectMailboxByFlag(MailboxFlag.drafts);
      int maxExist = mailbox.messagesExists;

      while (emails.length < maxExist) {
        MessageSequence sequence = MessageSequence.fromPage(page, 10, maxExist);
        List<MimeMessage> fetched = await queue(sequence);
        emails.addAll(fetched);
        emails = emails.sorted((a, b) => b.decodeDate()!.compareTo(a.decodeDate()!));
        _streamController.add(emails);
        page++;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        margin: const EdgeInsets.all(8),
        borderRadius: 8,
        snackPosition: SnackPosition.BOTTOM,
      );
      if (emails.isEmpty) _streamController.addError(e);
    }
  }

  Future<List<MimeMessage>> queue(MessageSequence sequence) async {
    return await service.client.fetchMessageSequence(
      sequence,
      fetchPreference: FetchPreference.envelope,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 2,
        title: Text(
          'drafts'.tr,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // Search functionality
            },
            tooltip: 'search_drafts'.tr,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {
              _showDraftOptions(context);
            },
            tooltip: 'more_options'.tr,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          emails.clear();
          await fetchMail();
        },
        color: AppTheme.primaryColor,
        backgroundColor: AppTheme.surfaceColor,
        child: StreamBuilder<List<MimeMessage>>(
          stream: _streamController.stream,
          builder: (context, snapshot) {
            if (_isLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading drafts...',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasData) {
              if (snapshot.data!.isEmpty) {
                return TAnimationLoaderWidget(
                  text: 'No drafts found',
                  animation: 'assets/lottie/empty.json',
                  showAction: true,
                  actionText: 'try_again'.tr,
                  onActionPressed: () {
                    fetchMail();
                  },
                );
              }

              // Group drafts by date
              Map<DateTime, List<MimeMessage>> groupedDrafts = groupBy(
                snapshot.data!,
                    (MimeMessage m) => DateTime(
                  m.decodeDate()!.year,
                  m.decodeDate()!.month,
                  m.decodeDate()!.day,
                ),
              );

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                itemCount: groupedDrafts.length,
                itemBuilder: (context, index) {
                  final dateGroup = groupedDrafts.entries.elementAt(index);
                  final date = dateGroup.key;
                  final drafts = dateGroup.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            top: 16,
                            bottom: 8
                        ),
                        child: Text(
                          _formatDate(date),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).primaryColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: drafts.length,
                        itemBuilder: (context, i) {
                          return DraftTile(
                            message: drafts[i],
                            mailBox: mailbox,
                            onTap: () {
                              // Navigate to compose screen with draft
                              Get.toNamed('/compose', arguments: drafts[i]);
                            },
                          );
                        },
                        separatorBuilder: (context, i) => const Divider(
                          color: AppTheme.dividerColor,
                          height: 1,
                          indent: 72,
                        ),
                      ),
                      if (index < groupedDrafts.length - 1)
                        const Divider(
                          color: AppTheme.dividerColor,
                          height: 1,
                        ),
                    ],
                  );
                },
              );
            } else if (snapshot.hasError) {
              return TAnimationLoaderWidget(
                text: 'Error loading drafts: ${snapshot.error}',
                animation: 'assets/lottie/error.json',
                showAction: true,
                actionText: 'try_again'.tr,
                onActionPressed: () {
                  fetchMail();
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
        onPressed: () {
          // Navigate to compose screen
          Get.toNamed('/compose');
        },
        child: const Icon(
          Icons.edit_outlined,
          color: Colors.white,
        ),
        tooltip: 'new_draft'.tr,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return weekdays[date.weekday - 1];
    } else {
      final months = ['January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
      return '${date.day} ${months[date.month - 1]}';
    }
  }

  void _showDraftOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Colors.grey.shade300,
              ),
            ),
            Text(
              'draft_options'.tr,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              ),
              title: Text('delete_all_drafts'.tr),
              subtitle: Text('permanently_delete'.tr),
              onTap: () {
                Get.back();
                _confirmDeleteAllDrafts(context);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sort_rounded, color: Colors.purple),
              ),
              title: Text('sort_by'.tr),
              subtitle: Text('date_subject_size'.tr),
              onTap: () {
                Get.back();
                // Show sort options
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.filter_list_rounded, color: Colors.amber),
              ),
              title: Text('filter_drafts'.tr),
              subtitle: Text('by_category_date'.tr),
              onTap: () {
                Get.back();
                // Show filter options
              },
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('cancel'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAllDrafts(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_all_drafts'.tr),
        content: Text('confirm_delete_all_drafts'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Delete all drafts functionality
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }
}

class DraftTile extends StatelessWidget {
  final MimeMessage message;
  final Mailbox mailBox;
  final VoidCallback onTap;

  const DraftTile({
    Key? key,
    required this.message,
    required this.mailBox,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final subject = message.decodeSubject() ?? 'No Subject';
    final preview = message.decodeTextPlainPart()?.substring(0,
        message.decodeTextPlainPart()!.length > 100
            ? 100
            : message.decodeTextPlainPart()!.length
    ) ?? '';
    final date = message.decodeDate() ?? DateTime.now();
    // final hasAttachments = message.attachments.isNotEmpty;
    final hasAttachments = message.hasAttachments(); // ✅

    // Get recipients
    final recipients = message.to?.map((e) => e.personalName ?? e.email).join(', ') ?? '';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Draft icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.edit_note_rounded,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Draft content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Subject
                      Expanded(
                        child: Text(
                          subject,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Date
                      Text(
                        _formatTime(date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Recipients
                  Text(
                    recipients.isNotEmpty ? 'To: $recipients' : 'No recipients',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Preview
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview.isNotEmpty ? preview : 'No content',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      if (hasAttachments)
                        const Icon(
                          Icons.attachment_rounded,
                          size: 16,
                          color: AppTheme.attachmentIconColor,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
