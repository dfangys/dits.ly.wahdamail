import 'dart:async';
import 'package:collection/collection.dart';  // for firstWhereOrNull
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/email_fetch_controller.dart';
import 'package:wahda_bank/app/controllers/email_operation_controller.dart';
import 'package:wahda_bank/app/controllers/email_storage_controller.dart';
import 'package:wahda_bank/app/controllers/email_ui_state_controller.dart';
import 'package:wahda_bank/models/sqlite_mailbox_storage.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/compose/models/draft_model.dart';
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

  // Get controllers
  final EmailStorageController storageController = Get.find<EmailStorageController>();
  final EmailUiStateController uiStateController = Get.find<EmailUiStateController>();
  final EmailFetchController fetchController = Get.find<EmailFetchController>();
  final EmailOperationController operationController = Get.find<EmailOperationController>();

  @override
  void initState() {
    super.initState();

    // Set UI state
    uiStateController.setCurrentView(ViewType.drafts);


    // Initialize drafts mailbox
    _initializeDraftsMailbox();
  }

  // Initialize drafts mailbox
  Future<void> _initializeDraftsMailbox() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Check if connected
      if (!service.isConnected) {
        await service.connect();
      }

      // Select drafts mailbox
      mailbox = await service.client.selectMailboxByFlag(MailboxFlag.drafts);

      // Initialize storage for this mailbox if not already done
      if (storageController.mailboxStorage[mailbox] == null) {
        storageController.initializeMailboxStorage(mailbox);
      }

      // Fetch drafts
      await fetchMail();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // Show error
      Get.snackbar(
        'Error',
        'Failed to initialize drafts: ${e.toString()}',
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        margin: const EdgeInsets.all(8),
        borderRadius: 8,
        snackPosition: SnackPosition.BOTTOM,
      );

      // Add error to stream
      _streamController.addError(e);
    }
  }

  List<MimeMessage> emails = [];
  List<DraftModel> localDrafts = [];
  int page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  Future<void> fetchMail() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Clear existing emails
      emails.clear();

      // Reset page counter
      page = 1;

      // Fetch server drafts
      await _fetchServerDrafts();

      // Fetch local drafts
      await _fetchLocalDrafts();

      // Combine and sort all drafts
      _combineAndSortDrafts();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });

      // Show error
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        margin: const EdgeInsets.all(8),
        borderRadius: 8,
        snackPosition: SnackPosition.BOTTOM,
      );

      // Add error to stream if no emails
      if (emails.isEmpty && localDrafts.isEmpty) {
        _streamController.addError(e);
      }
    }
  }

  // Fetch drafts from server
  Future<void> _fetchServerDrafts() async {
    try {
      // Select drafts mailbox
      mailbox = await service.client.selectMailboxByFlag(MailboxFlag.drafts);

      // Get total message count
      int maxExist = mailbox.messagesExists;

      // If no messages, return
      if (maxExist == 0) return;

      // Fetch messages in batches
      const batchSize = 20;
      final batches = (maxExist / batchSize).ceil();
      const maxBatches = 5; // Limit to 5 batches (100 messages) to avoid performance issues

      for (int i = 0; i < batches && i < maxBatches; i++) {
        // Create sequence for this batch
        final start = maxExist - (i * batchSize);
        final end = start - batchSize + 1;
        final fetchStart = start < 1 ? 1 : start;
        final fetchEnd = end < 1 ? 1 : end;

        if (fetchStart < fetchEnd) break;

        final sequence = MessageSequence.fromRange(fetchEnd, fetchStart);

        // Fetch messages
        final fetched = await _fetchMessageBatch(sequence);

        // Add to emails list
        emails.addAll(fetched);

        // Update stream
        _combineAndSortDrafts();
      }
    } catch (e) {
      debugPrint('Error fetching server drafts: $e');
      rethrow;
    }
  }

  // Fetch local drafts
  Future<void> _fetchLocalDrafts() async {
    try {
      // Get drafts from SQLite storage
      final sqliteStorage = SqliteMimeStorage.instance;
      localDrafts = await sqliteStorage.getDrafts();
    } catch (e) {
      debugPrint('Error fetching local drafts: $e');
      // Don't rethrow, just log the error
    }
  }




  // Combine and sort all drafts
  /// Combine local & server drafts into a sorted stream of MimeMessages
  void _combineAndSortDrafts() {
    final localDraftMessages = localDrafts.map((d) {
      // build a multipart/alternative message in one call:
      final b = MessageBuilder.prepareMultipartAlternativeMessage(
        plainText: d.body,
        htmlText:  d.isHtml ? d.body : null,
      );

      // carry your DraftModel PK in an X-header
      b.addHeader('X-Local-Draft-Id', d.id.toString());

      // set recipients
      b.to  = d.to  .map((e) => MailAddress(null, e)).toList();
      b.cc  = d.cc  .map((e) => MailAddress(null, e)).toList();
      b.bcc = d.bcc .map((e) => MailAddress(null, e)).toList();

      // store the \Draft flag for display
      b.addHeader('Flags', r'\Draft');

      return b.buildMimeMessage();
    }).toList();

    final all = [...emails, ...localDraftMessages]
      ..sort((a, b) {
        final da = a.decodeDate() ?? DateTime.now();
        final db = b.decodeDate() ?? DateTime.now();
        return db.compareTo(da);
      });

    _streamController.add(all);
  }

// Open draft for editing
  void _openDraft(MimeMessage m) async {
    // m.getHeaderValue(...) returns the first header‐value or null
    final idStr = m.getHeaderValue('X-Local-Draft-Id');
    final id = idStr == null ? null : int.tryParse(idStr);

    if (id != null) {
      final dm = await SqliteMimeStorage.instance.getDraftById(id);
      if (dm != null) {
        return Get.toNamed('/compose', arguments: {'draftModel': dm});
      }
    }

    // fallback to server‐side draft
    Get.toNamed('/compose', arguments: {'mimeMessage': m});
  }

  // Fetch a batch of messages
  Future<List<MimeMessage>> _fetchMessageBatch(MessageSequence sequence) async {
    try {
      return await service.client.fetchMessageSequence(
        sequence,
        fetchPreference: FetchPreference.envelope,
      );
    } catch (e) {
      debugPrint('Error fetching message batch: $e');
      return [];
    }
  }

  // Load more drafts
  Future<void> loadMoreDrafts() async {
    try {
      setState(() {
        _isLoadingMore = true;
      });

      // Increment page
      page++;

      // Get total message count
      int maxExist = mailbox.messagesExists;

      // Calculate start and end
      const batchSize = 20;
      final start = maxExist - ((page - 1) * batchSize);
      final end = start - batchSize + 1;

      // Ensure valid range
      final fetchStart = start < 1 ? 1 : start;
      final fetchEnd = end < 1 ? 1 : end;

      if (fetchStart < fetchEnd) {
        setState(() {
          _isLoadingMore = false;
        });
        return;
      }

      // Create sequence
      final sequence = MessageSequence.fromRange(fetchEnd, fetchStart);

      // Fetch messages
      final fetched = await _fetchMessageBatch(sequence);

      // Add to emails list
      emails.addAll(fetched);

      // Update stream
      _combineAndSortDrafts();

      setState(() {
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });

      // Show error
      Get.snackbar(
        'Error',
        'Failed to load more drafts: ${e.toString()}',
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        margin: const EdgeInsets.all(8),
        borderRadius: 8,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
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
              _showSearchDialog(context);
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
                  actionText: 'create_new_draft'.tr,
                  onActionPressed: () {
                    Get.toNamed('/compose');
                  },
                );
              }

              // Group drafts by date
              Map<DateTime, List<MimeMessage>> groupedDrafts = groupBy(
                snapshot.data!,
                    (MimeMessage m) => DateTime(
                  m.decodeDate()?.year ?? DateTime.now().year,
                  m.decodeDate()?.month ?? DateTime.now().month,
                  m.decodeDate()?.day ?? DateTime.now().day,
                ),
              );

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                itemCount: groupedDrafts.length + 1, // +1 for load more button
                itemBuilder: (context, index) {
                  // Add load more button at the end
                  if (index == groupedDrafts.length) {
                    if (_isLoadingMore) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          onPressed: () {
                            loadMoreDrafts();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Load More'.tr),
                        ),
                      );
                    }
                  }

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
                              _openDraft(drafts[i]);
                            },
                            onDelete: () {
                              _deleteDraft(drafts[i]);
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
        tooltip: 'new_draft'.tr,
        child: const Icon(
          Icons.edit_outlined,
          color: Colors.white,
        ),
      ),
    );
  }


  // Delete draft
  void _deleteDraft(MimeMessage draft) async {
    try {
      // Show confirmation dialog
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: Text('delete_draft'.tr),
          content: Text('confirm_delete_draft'.tr),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('cancel'.tr),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
              ),
              child: Text('delete'.tr),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      // Try to read our local‐draft PK from the header
      final idStr = draft.getHeaderValue('X-Local-Draft-Id');
      final localDraftId = idStr != null ? int.tryParse(idStr) : null;

      if (localDraftId != null) {
        // Delete local draft
        await SqliteMimeStorage.instance.deleteDraft(localDraftId);
        localDrafts.removeWhere((d) => d.id == localDraftId);
      } else {
        // Delete server draft
        await service.client.deleteMessage(draft);
        emails.remove(draft);
      }

      // Refresh UI
      _combineAndSortDrafts();

      Get.snackbar(
        'Success',
        'Draft deleted',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(8),
        borderRadius: 8,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete draft: ${e.toString()}',
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        margin: const EdgeInsets.all(8),
        borderRadius: 8,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
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

  // Show search dialog
  void _showSearchDialog(BuildContext context) {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Drafts'.tr),
        content: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Enter search term'.tr,
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              if (searchController.text.isNotEmpty) {
                _searchDrafts(searchController.text);
              }
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Search'.tr),
          ),
        ],
      ),
    );
  }

  // Search drafts
  void _searchDrafts(String query) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Search local drafts
      final sqliteStorage = SqliteMimeStorage.instance;
      final searchedLocalDrafts = await sqliteStorage.searchDrafts(query);

      // Update local drafts
      localDrafts = searchedLocalDrafts;

      // Filter server drafts
      final searchedServerDrafts = emails.where((draft) {
        final subject = draft.decodeSubject()?.toLowerCase() ?? '';
        final body = draft.decodeTextPlainPart()?.toLowerCase() ?? '';
        final recipients = draft.to?.map((e) => e.email.toLowerCase()).join(' ') ?? '';

        return subject.contains(query.toLowerCase()) ||
            body.contains(query.toLowerCase()) ||
            recipients.contains(query.toLowerCase());
      }).toList();

      // Update server drafts
      emails = searchedServerDrafts;

      // Update stream
      _combineAndSortDrafts();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // Show error
      Get.snackbar(
        'Error',
        'Failed to search drafts: ${e.toString()}',
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        margin: const EdgeInsets.all(8),
        borderRadius: 8,
        snackPosition: SnackPosition.BOTTOM,
      );
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
                child: const Icon(Icons.refresh, color: Colors.purple),
              ),
              title: Text('refresh'.tr),
              subtitle: Text('sync_with_server'.tr),
              onTap: () {
                Get.back();
                fetchMail();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.search, color: Colors.amber),
              ),
              title: Text('search_drafts'.tr),
              subtitle: Text('find_by_keyword'.tr),
              onTap: () {
                Get.back();
                _showSearchDialog(context);
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
              _deleteAllDrafts();
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

  // Delete all drafts
  void _deleteAllDrafts() async {
    try {
      // Show loading indicator
      Get.dialog(
        const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
        barrierDismissible: false,
      );

      // Delete server drafts
      if (emails.isNotEmpty) {
        // 1) pull out all the UIDs
        final uids = emails
            .map((m) => m.uid)           // extract the integer uid
            .where((u) => u != null)     // drop any nulls
            .cast<int>()                 // cast Iterable<int?>
            .toList();

        // 2) turn that list into the IMAP sequence-set string “1,2,3,5”
        final sequenceStr = uids.join(',');

        // 3) parse it into a MessageSequence
        final seq = MessageSequence.parse(sequenceStr);

        // 4) delete them in one command
        await service.client.deleteMessages(seq);
      }

      // Delete local drafts
      if (localDrafts.isNotEmpty) {
        final sqliteStorage = SqliteMimeStorage.instance;
        final draftIds = localDrafts.map((d) => d.id!).toList();
        await sqliteStorage.batchDeleteDrafts(draftIds);
      }

      // Clear lists & update UI
      emails.clear();
      localDrafts.clear();
      _streamController.add([]);

      // Close loading dialog
      Get.back();

      Get.snackbar(
        'Success',
        'All drafts deleted',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(8),
        borderRadius: 8,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.back();
      Get.snackbar(
        'Error',
        'Failed to delete all drafts: $e',
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        margin: const EdgeInsets.all(8),
        borderRadius: 8,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
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
  final VoidCallback onDelete;

  const DraftTile({
    super.key,
    required this.message,
    required this.mailBox,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final subject = message.decodeSubject() ?? 'No Subject';
    final preview = message.decodeTextPlainPart()?.substring(0,
        message.decodeTextPlainPart()!.length > 100
            ? 100
            : message.decodeTextPlainPart()!.length
    ) ?? '';
    final date = message.decodeDate() ?? DateTime.now();
    final hasAttachments = message.hasAttachments();

    // Get recipients
    final recipients = message.to?.map((e) => e.personalName ?? e.email).join(', ') ?? '';

    return Dismissible(
      key: Key(message.uid?.toString() ?? DateTime.now().toString()),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await Get.dialog<bool>(
          AlertDialog(
            title: Text('delete_draft'.tr),
            content: Text('confirm_delete_draft'.tr),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text('cancel'.tr),
              ),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  foregroundColor: Colors.white,
                ),
                child: Text('delete'.tr),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        onDelete();
      },
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Icon(
                    Icons.edit_note_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(date),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (recipients.isNotEmpty)
                      Text(
                        'To: $recipients',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasAttachments)
                          const Icon(
                            Icons.attachment,
                            color: Colors.grey,
                            size: 16,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (dateDay == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}';
    }
  }
}
