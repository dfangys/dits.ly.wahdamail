// import 'dart:async';
// import 'dart:math' as math;
// import 'package:enough_mail/enough_mail.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:logger/logger.dart';
// import 'package:rxdart/rxdart.dart';
// import 'package:wahda_bank/app/controllers/mail_count_controller.dart';
// import 'package:wahda_bank/app/controllers/settings_controller.dart';
// import 'package:wahda_bank/services/background_service.dart';
// import 'package:wahda_bank/services/internet_service.dart';
// import 'package:wahda_bank/views/box/mailbox_view.dart';
// import 'package:wahda_bank/views/settings/data/swap_data.dart';
// import 'package:workmanager/workmanager.dart';
// import '../../models/sqlite_mailbox_storage.dart';
// import '../../services/mail_service.dart';
// import '../../views/authantication/screens/login/login.dart';
// import '../../views/view/models/box_model.dart';
//
// // Define SwapDirection enum since it's missing
// enum SwapDirection { ltr, rtl }
//
// class MailBoxController extends GetxController {
//   late MailService mailService;
//   final RxBool isBusy = true.obs;
//   final RxBool isBoxBusy = true.obs;
//   final RxBool isLoadingMore = false.obs;
//   final RxBool isRefreshing = false.obs; // Added to track refresh state
//   final getStoarage = GetStorage();
//
//   // Changed from HiveMailboxMimeStorage to SqliteMailboxStorage
//
//
//   final RxMap<Mailbox, SqliteMailboxStorage> mailboxStorage =
//       <Mailbox, SqliteMailboxStorage>{}.obs;
//   final RxMap<Mailbox, List<MimeMessage>> emails =
//       <Mailbox, List<MimeMessage>>{}.obs;
//
//   List<MimeMessage> get boxMails =>
//       emails[mailService.client.selectedMailbox] ?? [];
//
//   SettingController settingController = Get.find<SettingController>();
//
//   Mailbox mailBoxInbox = Mailbox(
//     encodedName: 'inbox',
//     encodedPath: 'inbox',
//     flags: [],
//     pathSeparator: '',
//   );
//
//   final Logger logger = Logger();
//   RxList<Mailbox> mailboxes = <Mailbox>[].obs;
//
//   // Enhanced stream controller for reactive updates with BehaviorSubject
//   final _emailsSubject = BehaviorSubject<Map<Mailbox, List<MimeMessage>>>();
//   Stream<Map<Mailbox, List<MimeMessage>>> get emailsStream => _emailsSubject.stream;
//
//   // Track last fetched UID for each mailbox
//   final Map<Mailbox, int> _lastFetchedUids = {};
//
//   // Track if initial load has been done for each mailbox
//   final Map<Mailbox, bool> _initialLoadDone = {};
//
//   // Track pagination for each mailbox
//   final Map<Mailbox, int> _currentPage = {};
//   final int pageSize = 20;
//
//   // Debounce timer for UI updates
//   Timer? _debounceTimer;
//
//   // Operation queue for background tasks
//   final _operationQueue = <Future Function()>[];
//   bool _isProcessingQueue = false;
//
//   List<String> predefinedOrder = [
//     'inbox',
//     'sent',
//     'drafts',
//     'trash',
//     'junk',
//     'archive',
//   ];
//
//   List<Mailbox> get sortedMailBoxes {
//     return mailboxes.toList()
//       ..sort((a, b) {
//         // Get the index of each item in the predefined order
//         int indexA = predefinedOrder.indexOf(a.name.toLowerCase());
//         int indexB = predefinedOrder.indexOf(b.name.toLowerCase());
//         // Handle cases where the item is not in the predefined order
//         if (indexA == -1) indexA = predefinedOrder.length;
//         if (indexB == -1) indexB = predefinedOrder.length;
//         // Compare based on the indices
//         return indexA.compareTo(indexB);
//       });
//   }
//
//   @override
//   void onInit() async {
//     try {
//       mailService = MailService.instance;
//       await mailService.init();
//       await loadMailBoxes();
//
//       // Start processing the operation queue
//       _startQueueProcessing();
//
//       super.onInit();
//     } catch (e) {
//       logger.e(e);
//     }
//   }
//
//   // Process operations in background to prevent UI blocking
//   void _startQueueProcessing() {
//     if (_isProcessingQueue) return;
//
//     _isProcessingQueue = true;
//     Future.microtask(() async {
//       while (_operationQueue.isNotEmpty) {
//         final operation = _operationQueue.removeAt(0);
//         try {
//           await operation();
//         } catch (e) {
//           logger.e('Error processing queued operation: $e');
//         }
//         // Yield to UI thread
//         await Future.delayed(Duration.zero);
//       }
//       _isProcessingQueue = false;
//     });
//   }
//
//   // Add operation to queue and start processing
//   void _queueOperation(Future Function() operation) {
//     _operationQueue.add(operation);
//     if (!_isProcessingQueue) {
//       _startQueueProcessing();
//     }
//   }
//   Future logout() async {
//     try {
//       await GetStorage().erase();
//       MailService.instance.client.disconnect();
//       MailService.instance.dispose();
//       await deleteAccount();
//       // await BackgroundFetch.stop();
//       await Workmanager().cancelAll();
//       Get.offAll(() => LoginScreen());
//     } catch (e) {
//       logger.e(e);
//     }
//   }
//   Future<void> initInbox() async {
//     mailBoxInbox = mailboxes.firstWhere(
//           (element) => element.isInbox,
//       orElse: () => mailboxes.first,
//     );
//     loadEmailsForBox(mailBoxInbox);
//   }
//   Future<void> sendMail(MimeMessage message, {Mailbox? sentMailbox, MimeMessage? draftToDelete}) async {
//     try {
//       await mailService.client.sendMessage(message);
//
//       // Delete draft if provided
//       if (draftToDelete != null) {
//         await mailService.client.deleteMessage(draftToDelete);
//       }
//
//       // Save to Sent mailbox
//       final sentBox = sentMailbox ?? mailboxes.firstWhereOrNull((m) => m.isSent);
//       if (sentBox != null) {
//         if (emails[sentBox] == null) emails[sentBox] = [];
//         emails[sentBox]!.add(message);
//         emails.refresh();
//         _emailsSubject.add(emails);
//         if (mailboxStorage[sentBox] != null) {
//           _saveMessagesInBackground([message], sentBox);
//         }
//       }
//     } catch (e) {
//       logger.e("Error sending message: $e");
//     }
//   }
//   Future loadMailBoxes() async {
//     List b = getStoarage.read('boxes') ?? [];
//     if (b.isEmpty) {
//       await mailService.connect();
//       mailboxes(await mailService.client.listMailboxes());
//     } else {
//       mailboxes(
//         b.map((e) => BoxModel.fromJson(e as Map<String, dynamic>)).toList(),
//       );
//     }
//
//     // Initialize mailboxes in parallel for better performance
//     await Future.wait(
//         mailboxes.map((mailbox) async {
//           if (mailboxStorage[mailbox] != null) return;
//
//           // Create and initialize storage for this mailbox
//           mailboxStorage[mailbox] = SqliteMailboxStorage(
//             mailAccount: mailService.account,
//             mailbox: mailbox,
//           );
//           emails[mailbox] = <MimeMessage>[];
//           await mailboxStorage[mailbox]!.init();
//
//           // Set up listener for storage updates
//           mailboxStorage[mailbox]!.messageStream.listen((messages) {
//             // Always sort messages by date (newest first)
//             messages.sort((a, b) {
//               final dateA = a.decodeDate() ?? DateTime.now();
//               final dateB = b.decodeDate() ?? DateTime.now();
//               return dateB.compareTo(dateA);
//             });
//
//             emails[mailbox] = messages;
//             emails.refresh(); // Force UI update
//             _notifyEmailsChanged(); // Update stream with debouncing
//
//             // Update unread count
//             _updateUnreadCount(mailbox);
//           });
//
//           // Initialize tracking variables
//           _lastFetchedUids[mailbox] = 0;
//           _initialLoadDone[mailbox] = false;
//           _currentPage[mailbox] = 1;
//         })
//     );
//
//     // Initialize the emails subject if not already done
//     if (!_emailsSubject.hasValue) {
//       _emailsSubject.add(emails);
//     }
//
//     isBusy(false);
//     initInbox();
//   }
//
//   // Update unread count for a mailbox
//   void _updateUnreadCount(Mailbox mailbox) {
//     if (Get.isRegistered<MailCountController>()) {
//       final countController = Get.find<MailCountController>();
//       String key = "${mailbox.name.toLowerCase()}_count";
//       countController.counts[key] =
//           emails[mailbox]?.where((e) => !e.isSeen).length ?? 0;
//     }
//   }
//
//   Future loadEmailsForBox(Mailbox mailbox) async {
//     if (!mailService.client.isConnected) {
//       await mailService.connect();
//     }
//     await mailService.client.selectMailbox(mailbox);
//
//     // Check if this is the first load or a refresh
//     if (!_initialLoadDone[mailbox]!) {
//       await fetchMailbox(mailbox);
//       _initialLoadDone[mailbox] = true;
//     } else {
//       // For subsequent loads, only fetch new emails
//       await fetchNewEmails(mailbox);
//     }
//   }
//
//   // Load more emails when scrolling down (pagination)
//   Future<void> loadMoreEmails(Mailbox mailbox) async {
//     if (isLoadingMore.value || isBoxBusy.value) return;
//
//     isLoadingMore(true);
//
//     try {
//       final currentPage = _currentPage[mailbox] ?? 1;
//       final nextPage = currentPage + 1;
//
//       // Calculate start and end indices for this page
//       final startIndex = (nextPage - 1) * pageSize + 1;
//       final endIndex = startIndex + pageSize - 1;
//
//       // Check if we've reached the end
//       if (startIndex > mailbox.messagesExists) {
//         isLoadingMore(false);
//         return;
//       }
//
//       // Create sequence for this page
//       final sequence = MessageSequence.fromRange(
//           mailbox.messagesExists - endIndex + 1 > 0 ? mailbox.messagesExists - endIndex + 1 : 1,
//           mailbox.messagesExists - startIndex + 1 > 0 ? mailbox.messagesExists - startIndex + 1 : 1
//       );
//
//       // Fetch messages for this page
//       final messages = await queue(sequence);
//
//       if (messages.isNotEmpty) {
//         // Sort by date (newest first)
//         messages.sort((a, b) {
//           final dateA = a.decodeDate() ?? DateTime.now();
//           final dateB = b.decodeDate() ?? DateTime.now();
//           return dateB.compareTo(dateA);
//         });
//
//         // Add to emails list
//         if (emails[mailbox] == null) {
//           emails[mailbox] = <MimeMessage>[];
//         }
//
//         // Check for duplicates before adding
//         final existingUids = emails[mailbox]!.map((m) => m.uid).toSet();
//         final newMessages = messages.where((m) => !existingUids.contains(m.uid)).toList();
//
//         if (newMessages.isNotEmpty) {
//           emails[mailbox]!.addAll(newMessages);
//
//           // Sort all messages by date
//           emails[mailbox]!.sort((a, b) {
//             final dateA = a.decodeDate() ?? DateTime.now();
//             final dateB = b.decodeDate() ?? DateTime.now();
//             return dateB.compareTo(dateA);
//           });
//
//           emails.refresh(); // Force UI update
//           _notifyEmailsChanged(); // Update stream with debouncing
//
//           // Save to local storage in background
//           _saveMessagesInBackground(newMessages, mailbox);
//         }
//
//         // Update current page
//         _currentPage[mailbox] = nextPage;
//       }
//     } catch (e) {
//       logger.e("Error loading more emails: $e");
//     } finally {
//       isLoadingMore(false);
//     }
//   }
//
//   // Fetch only new emails since last fetch
//   Future<void> fetchNewEmails(Mailbox mailbox) async {
//     isBoxBusy(true);
//     isRefreshing(true); // Set refreshing state to true
//
//     try {
//       int lastUid = _lastFetchedUids[mailbox] ?? 0;
//
//       if (mailbox.uidNext != null && mailbox.isInbox) {
//         await GetStorage().write(
//           BackgroundService.keyInboxLastUid,
//           mailbox.uidNext,
//         );
//       }
//
//       // If we have no last UID, do a full fetch
//       if (lastUid == 0) {
//         await fetchMailbox(mailbox);
//         return;
//       }
//
//       logger.d('Fetching new emails since UID $lastUid for ${mailbox.name}');
//
//       // First try to load from local storage
//       final newLocalMessages = await mailboxStorage[mailbox]!.loadNewMessages(lastUid);
//
//       // Then fetch from server
//       if (mailService.client.isConnected) {
//         // Create a sequence for UIDs greater than lastUid
//         final sequence = MessageSequence();
//
//         // Add UIDs from lastUid+1 to uidNext
//         if (mailbox.uidNext != null && mailbox.uidNext! > lastUid) {
//           for (int uid = lastUid + 1; uid < mailbox.uidNext!; uid++) {
//             sequence.add(uid);
//           }
//         }
//
//         if (!sequence.isEmpty) {
//           final newServerMessages = await mailService.client.fetchMessageSequence(
//             sequence,
//             fetchPreference: FetchPreference.envelope,
//           );
//
//           if (newServerMessages.isNotEmpty) {
//             // Sort by date (newest first)
//             newServerMessages.sort((a, b) {
//               final dateA = a.decodeDate() ?? DateTime.now();
//               final dateB = b.decodeDate() ?? DateTime.now();
//               return dateB.compareTo(dateA);
//             });
//
//             // Update last fetched UID
//             for (var msg in newServerMessages) {
//               if (msg.uid != null && msg.uid! > lastUid) {
//                 lastUid = msg.uid!;
//               }
//             }
//             _lastFetchedUids[mailbox] = lastUid;
//
//             // Save to local storage in background using batch operation
//             _saveMessagesInBackground(newServerMessages, mailbox);
//
//             // Add to emails list
//             if (emails[mailbox] == null) {
//               emails[mailbox] = <MimeMessage>[];
//             }
//
//             // Check for duplicates before adding
//             final existingUids = emails[mailbox]!.map((m) => m.uid).toSet();
//             final uniqueNewMessages = newServerMessages.where((m) => !existingUids.contains(m.uid)).toList();
//
//             if (uniqueNewMessages.isNotEmpty) {
//               emails[mailbox]!.insertAll(0, uniqueNewMessages); // Insert at beginning (newest first)
//
//               // Re-sort all messages by date
//               emails[mailbox]!.sort((a, b) {
//                 final dateA = a.decodeDate() ?? DateTime.now();
//                 final dateB = b.decodeDate() ?? DateTime.now();
//                 return dateB.compareTo(dateA);
//               });
//
//               emails.refresh(); // Force UI update
//               _notifyEmailsChanged(); // Update stream with debouncing
//
//               // Show notification of new emails
//               if (uniqueNewMessages.length > 0) {
//                 Get.showSnackbar(
//                   GetSnackBar(
//                     message: 'Received ${uniqueNewMessages.length} new email(s)',
//                     backgroundColor: Colors.green,
//                     duration: const Duration(seconds: 2),
//                   ),
//                 );
//               }
//             }
//           }
//         }
//       }
//
//       if (mailbox.isInbox) {
//         // Use platform-safe background service check
//         _safeCheckForNewMail(false);
//       }
//
//       // Update unread count
//       _updateUnreadCount(mailbox);
//
//       storeContactMails(emails[mailbox]!);
//     } catch (e) {
//       logger.e("Error fetching new emails: $e");
//       // Show error message to user
//       Get.showSnackbar(
//         GetSnackBar(
//           message: 'Error refreshing emails: ${e.toString()}',
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//     } finally {
//       isBoxBusy(false);
//       isRefreshing(false); // Set refreshing state to false when done
//     }
//   }
//
//   // Pagination for emails with optimized loading
//   Future<void> fetchMailbox(Mailbox mailbox) async {
//     isBoxBusy(true);
//     isRefreshing(true); // Set refreshing state to true
//
//     try {
//       int max = mailbox.messagesExists;
//       if (mailbox.uidNext != null && mailbox.isInbox) {
//         await GetStorage().write(
//           BackgroundService.keyInboxLastUid,
//           mailbox.uidNext,
//         );
//       }
//
//       if (max == 0) {
//         isBoxBusy(false);
//         isRefreshing(false); // Set refreshing state to false
//         return;
//       }
//
//       if (emails[mailbox] == null) {
//         emails[mailbox] = <MimeMessage>[];
//       }
//
//       // Only clear emails on first load, not on refresh
//       if (!_initialLoadDone[mailbox]!) {
//         _currentPage[mailbox] = 1;
//         emails[mailbox]!.clear();
//         emails.refresh(); // Force UI update
//         _notifyEmailsChanged(); // Update stream with debouncing
//       }
//
//       if (mailboxStorage[mailbox] == null) {
//         mailboxStorage[mailbox] = SqliteMailboxStorage(
//           mailAccount: mailService.account,
//           mailbox: mailbox,
//         );
//         await mailboxStorage[mailbox]!.init();
//
//         // Set up listener for storage updates
//         mailboxStorage[mailbox]!.messageStream.listen((messages) {
//           // Always sort messages by date (newest first)
//           messages.sort((a, b) {
//             final dateA = a.decodeDate() ?? DateTime.now();
//             final dateB = b.decodeDate() ?? DateTime.now();
//             return dateB.compareTo(dateA);
//           });
//
//           emails[mailbox] = messages;
//           emails.refresh(); // Force UI update
//           _notifyEmailsChanged(); // Update stream with debouncing
//
//           // Update unread count
//           _updateUnreadCount(mailbox);
//         });
//       }
//
//       // Load messages in smaller batches to prevent UI blocking
//       const int batchSize = 20; // Define constant batch size
//       int loadedCount = 0;
//       int highestUid = 0;
//
//       // Calculate how many messages to load initially (first page)
//       // For initial load, fetch more messages to ensure we have enough data
//       final initialLoadCount = _initialLoadDone[mailbox]!
//           ? math.min(batchSize, max)
//           : math.min(batchSize * 3, max); // Load more on first fetch
//
//       // Load messages from newest to oldest
//       final startIndex = max - initialLoadCount + 1 > 0 ? max - initialLoadCount + 1 : 1;
//       final endIndex = max;
//
//       // Always fetch from server first to ensure we have data
//       List<MimeMessage> newMessages = await queue(
//           MessageSequence.fromRange(startIndex, endIndex)
//       );
//
//       if (newMessages.isNotEmpty) {
//         // Sort by date (newest first)
//         newMessages.sort((a, b) {
//           final dateA = a.decodeDate() ?? DateTime.now();
//           final dateB = b.decodeDate() ?? DateTime.now();
//           return dateB.compareTo(dateA);
//         });
//
//         // Track highest UID for incremental fetching
//         for (var msg in newMessages) {
//           if (msg.uid != null && msg.uid! > highestUid) {
//             highestUid = msg.uid!;
//           }
//         }
//
//         // Update last fetched UID for incremental updates
//         if (highestUid > (_lastFetchedUids[mailbox] ?? 0)) {
//           _lastFetchedUids[mailbox] = highestUid;
//         }
//
//         // Add messages to the list
//         // Check for duplicates before adding
//         final existingUids = emails[mailbox]!.map((m) => m.uid).toSet();
//         final uniqueNewMessages = newMessages.where((m) => !existingUids.contains(m.uid)).toList();
//
//         if (uniqueNewMessages.isNotEmpty) {
//           emails[mailbox]!.addAll(uniqueNewMessages);
//
//           // Sort all messages by date
//           emails[mailbox]!.sort((a, b) {
//             final dateA = a.decodeDate() ?? DateTime.now();
//             final dateB = b.decodeDate() ?? DateTime.now();
//             return dateB.compareTo(dateA);
//           });
//
//           emails.refresh(); // Force UI update
//           _notifyEmailsChanged(); // Update stream with debouncing
//
//           // Save to local storage in background using batch operation
//           _saveMessagesInBackground(uniqueNewMessages, mailbox);
//
//           loadedCount += uniqueNewMessages.length;
//         }
//       }
//
//       // Try to load additional messages from local storage if needed
//       if (loadedCount < initialLoadCount) {
//         final messages = await mailboxStorage[mailbox]!.loadMessageEnvelopes(
//             MessageSequence.fromRange(startIndex, endIndex)
//         );
//
//         if (messages != null && messages.isNotEmpty) {
//           // Sort by date (newest first)
//           messages.sort((a, b) {
//             final dateA = a.decodeDate() ?? DateTime.now();
//             final dateB = b.decodeDate() ?? DateTime.now();
//             return dateB.compareTo(dateA);
//           });
//
//           // Check for duplicates before adding
//           final existingUids = emails[mailbox]!.map((m) => m.uid).toSet();
//           final uniqueMessages = messages.where((m) => !existingUids.contains(m.uid)).toList();
//
//           if (uniqueMessages.isNotEmpty) {
//             emails[mailbox]!.addAll(uniqueMessages);
//             emails.refresh(); // Force UI update
//             _notifyEmailsChanged(); // Update stream with debouncing
//           }
//         }
//       }
//
//       if (mailbox.isInbox) {
//         // Use platform-safe background service check
//         _safeCheckForNewMail(false);
//       }
//
//       // Update unread count
//       _updateUnreadCount(mailbox);
//
//       storeContactMails(emails[mailbox]!);
//     } catch (e) {
//       logger.e("Error fetching mailbox: $e");
//       // Show error message to user
//       Get.showSnackbar(
//         GetSnackBar(
//           message: 'Error loading emails: ${e.toString()}',
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//     } finally {
//       isBoxBusy(false);
//       isRefreshing(false); // Set refreshing state to false when done
//     }
//   }
//
//   // Platform-safe method to check for new mail
//   void _safeCheckForNewMail(bool isBackground) {
//     try {
//       // Skip background service on iOS and web
//       if (defaultTargetPlatform == TargetPlatform.iOS ||
//           defaultTargetPlatform == TargetPlatform.macOS ||
//           kIsWeb) {
//         logger.d("Skipping background service on unsupported platform");
//         return;
//       }
//
//       // Only call on Android
//       if (defaultTargetPlatform == TargetPlatform.android) {
//         BackgroundService.checkForNewMail(isBackground);
//       }
//     } catch (e) {
//       logger.e("Error checking for new mail: $e");
//     }
//   }
//
//   // Save messages in background to prevent UI blocking
//   Future<void> _saveMessagesInBackground(List<MimeMessage> messages, Mailbox mailbox) async {
//     if (messages.isEmpty) return;
//
//     // Use compute for heavy processing to prevent UI blocking
//     _queueOperation(() async {
//       try {
//         await mailboxStorage[mailbox]!.saveMessageEnvelopes(messages);
//       } catch (e) {
//         logger.e("Error saving messages in background: $e");
//       }
//     });
//   }
//
//   Future<List<MimeMessage>> queue(MessageSequence sequence) async {
//     try {
//       return await mailService.client.fetchMessageSequence(
//         sequence,
//         fetchPreference: FetchPreference.envelope,
//       );
//     } catch (e) {
//       logger.e("Error fetching message sequence: $e");
//
//       // Retry once after reconnecting
//       try {
//         await mailService.connect();
//         return await mailService.client.fetchMessageSequence(
//           sequence,
//           fetchPreference: FetchPreference.envelope,
//         );
//       } catch (e) {
//         logger.e("Error retrying fetch: $e");
//         return [];
//       }
//     }
//   }
//
//   // Operations on emails
//   Future markAsReadUnread(List<MimeMessage> messages, Mailbox box,
//       [bool isSeen = true]) async {
//     // Create a copy of messages to avoid modifying the original list
//     final updatedMessages = <MimeMessage>[];
//
//     for (var message in messages) {
//       // Only update if the status is changing
//       if (message.isSeen != isSeen) {
//         message.isSeen = isSeen;
//         updatedMessages.add(message);
//
//         // Update storage immediately
//         if (mailboxStorage[box] != null) {
//           _queueOperation(() async {
//             await mailboxStorage[box]!.updateMessageFlags(message);
//           });
//         }
//       }
//     }
//
//     // If no messages were actually updated, return early
//     if (updatedMessages.isEmpty) return;
//
//     // Update the emails list
//     if (emails[box] != null) {
//       for (var message in updatedMessages) {
//         final index = emails[box]!.indexWhere((m) => m.uid == message.uid);
//         if (index >= 0) {
//           emails[box]![index] = message;
//         }
//       }
//       emails.refresh(); // Force UI update
//       _notifyEmailsChanged(); // Update stream with debouncing
//
//       // Update unread count
//       _updateUnreadCount(box);
//     }
//
//     // Update on server if connected
//     if (InternetService.instance.connected && mailService.client.isConnected) {
//       _queueOperation(() async {
//         for (var message in updatedMessages) {
//           try {
//             await mailService.client.flagMessage(message, isSeen: isSeen);
//           } catch (e) {
//             logger.e("Error updating message flags on server: $e");
//             // Continue with other messages even if one fails
//           }
//         }
//       });
//     }
//   }
//
//   //
//   DeleteResult? deleteResult;
//   Map<Mailbox, List<MimeMessage>> deletedMessages = {};
//
//   Future deleteMails(List<MimeMessage> messages, Mailbox mailbox) async {
//     if (messages.isEmpty) return;
//
//     // Store deleted messages for potential undo
//     if (deletedMessages[mailbox] == null) {
//       deletedMessages[mailbox] = [];
//     }
//     deletedMessages[mailbox]!.addAll(messages);
//
//     // Remove from emails list immediately for real-time UI update
//     if (emails[mailbox] != null) {
//       for (var message in messages) {
//         emails[mailbox]!.removeWhere((m) => m.uid == message.uid);
//       }
//       emails.refresh(); // Force UI update
//       _notifyEmailsChanged(); // Update stream with debouncing
//
//       // Update unread count
//       _updateUnreadCount(mailbox);
//     }
//
//     // Delete from storage in background
//     _queueOperation(() async {
//       for (var message in messages) {
//         if (mailboxStorage[mailbox] != null) {
//           try {
//             await mailboxStorage[mailbox]!.deleteMessage(message);
//           } catch (e) {
//             logger.e("Error deleting message from storage: $e");
//           }
//         }
//       }
//     });
//
//     // Delete on server if connected
//     if (mailService.client.isConnected) {
//       try {
//         deleteResult = await mailService.client.deleteMessages(
//           MessageSequence.fromMessages(messages),
//           messages: messages,
//           expunge: false,
//         );
//
//         if (deleteResult != null && deleteResult!.canUndo) {
//           Get.showSnackbar(
//             GetSnackBar(
//               message: 'messages_deleted'.tr,
//               backgroundColor: Colors.redAccent,
//               duration: const Duration(seconds: 5),
//               mainButton: TextButton(
//                 onPressed: () async {
//                   await undoDelete();
//                 },
//                 child: Text('undo'.tr),
//               ),
//             ),
//           );
//         }
//       } catch (e) {
//         logger.e("Error deleting messages on server: $e");
//         // Show error message
//         Get.showSnackbar(
//           GetSnackBar(
//             message: 'Error deleting messages: ${e.toString()}',
//             backgroundColor: Colors.redAccent,
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       }
//     }
//   }
//
//   Future undoDelete() async {
//     if (deleteResult != null) {
//       try {
//         await mailService.client.undoDeleteMessages(deleteResult!);
//         deleteResult = null;
//
//         // Restore deleted messages
//         for (var mailbox in deletedMessages.keys) {
//           if (emails[mailbox] != null) {
//             emails[mailbox]!.addAll(deletedMessages[mailbox]!);
//
//             // Sort messages by date
//             emails[mailbox]!.sort((a, b) {
//               final dateA = a.decodeDate() ?? DateTime.now();
//               final dateB = b.decodeDate() ?? DateTime.now();
//               return dateB.compareTo(dateA);
//             });
//
//             emails.refresh(); // Force UI update
//             _notifyEmailsChanged(); // Update stream with debouncing
//
//             // Update unread count
//             _updateUnreadCount(mailbox);
//           }
//
//           // Restore in storage
//           _queueOperation(() async {
//             await mailboxStorage[mailbox]!
//                 .saveMessageEnvelopes(deletedMessages[mailbox]!);
//           });
//         }
//         deletedMessages.clear();
//
//         // Show success message
//         Get.showSnackbar(
//           GetSnackBar(
//             message: 'Messages restored',
//             backgroundColor: Colors.green,
//             duration: const Duration(seconds: 2),
//           ),
//         );
//       } catch (e) {
//         logger.e("Error undoing delete: $e");
//         // Show error message
//         Get.showSnackbar(
//           GetSnackBar(
//             message: 'Error restoring messages: ${e.toString()}',
//             backgroundColor: Colors.redAccent,
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       }
//     }
//   }
//
//   Future moveMails(List<MimeMessage> messages, Mailbox from, Mailbox to) async {
//     if (messages.isEmpty) return;
//
//     // Remove from source mailbox immediately for real-time UI update
//     if (emails[from] != null) {
//       for (var message in messages) {
//         emails[from]!.removeWhere((m) => m.uid == message.uid);
//       }
//       emails.refresh(); // Force UI update
//       _notifyEmailsChanged(); // Update stream with debouncing
//
//       // Update unread count
//       _updateUnreadCount(from);
//     }
//
//     // Add to destination mailbox
//     if (emails[to] != null) {
//       emails[to]!.addAll(messages);
//
//       // Sort messages by date
//       emails[to]!.sort((a, b) {
//         final dateA = a.decodeDate() ?? DateTime.now();
//         final dateB = b.decodeDate() ?? DateTime.now();
//         return dateB.compareTo(dateA);
//       });
//
//       emails.refresh(); // Force UI update
//       _notifyEmailsChanged(); // Update stream with debouncing
//
//       // Update unread count
//       _updateUnreadCount(to);
//     }
//
//     // Update storage in background
//     _queueOperation(() async {
//       for (var message in messages) {
//         try {
//           if (mailboxStorage[from] != null) {
//             await mailboxStorage[from]!.deleteMessage(message);
//           }
//           if (mailboxStorage[to] != null) {
//             await mailboxStorage[to]!.saveMessageEnvelopes([message]);
//           }
//         } catch (e) {
//           logger.e("Error moving message in storage: $e");
//         }
//       }
//     });
//
//     // Move on server if connected
//     if (mailService.client.isConnected) {
//       _queueOperation(() async {
//         for (var message in messages) {
//           try {
//             await mailService.client.moveMessage(message, to);
//           } catch (e) {
//             logger.e("Error moving message on server: $e");
//           }
//         }
//       });
//     }
//   }
//
//   // update flag on messages on server
//   Future updateFlag(List<MimeMessage> messages, Mailbox mailbox) async {
//     if (messages.isEmpty) return;
//
//     final updatedMessages = <MimeMessage>[];
//
//     for (var message in messages) {
//       // Toggle flag status
//       message.isFlagged = !message.isFlagged;
//       updatedMessages.add(message);
//
//       // Update storage immediately
//       if (mailboxStorage[mailbox] != null) {
//         _queueOperation(() async {
//           await mailboxStorage[mailbox]!.updateMessageFlags(message);
//         });
//       }
//     }
//
//     // Update emails list
//     if (emails[mailbox] != null) {
//       for (var message in updatedMessages) {
//         final index = emails[mailbox]!.indexWhere((m) => m.uid == message.uid);
//         if (index >= 0) {
//           emails[mailbox]![index] = message;
//         }
//       }
//       emails.refresh(); // Force UI update
//       _notifyEmailsChanged(); // Update stream with debouncing
//     }
//
//     // Update on server if connected
//     if (mailService.client.isConnected) {
//       _queueOperation(() async {
//         for (var message in updatedMessages) {
//           try {
//             await mailService.client.flagMessage(
//               message,
//               isFlagged: message.isFlagged,
//             );
//           } catch (e) {
//             logger.e("Error updating flag on server: $e");
//           }
//         }
//       });
//     }
//   }
//
//   // Operations on emails
//   Future deleteAccount() async {
//     for (var mailbox in MailService.instance.client.mailboxes ?? []) {
//       if (mailboxStorage[mailbox] != null) {
//         await mailboxStorage[mailbox]!.onAccountRemoved();
//       }
//     }
//
//     // Clear emails
//     emails.clear();
//     emails.refresh(); // Force UI update
//     _notifyEmailsChanged(); // Update stream with debouncing
//   }
//
//   // Method to map SwapDirection to SwapAction
//   SwapAction getSwapAction(SwapDirection direction) {
//     // Default actions for each direction
//     if (direction == SwapDirection.ltr) {
//       return SwapAction.delete; // Default action for left-to-right swipe
//     } else {
//       return SwapAction.readUnread; // Default action for right-to-left swipe
//     }
//
//     // In a real implementation, this would likely read from settings
//     // For example:
//     // return settingController.getSwapActionForDirection(direction);
//   }
//
//   Future ltrTap(MimeMessage message, Mailbox mailbox) async {
//     SwapAction action = getSwapAction(SwapDirection.ltr);
//     switch (action) {
//       case SwapAction.readUnread:
//         await markAsReadUnread([message], mailbox, !message.isSeen);
//         break;
//       case SwapAction.archive:
//         final archive = mailboxes.firstWhereOrNull(
//               (element) => element.isArchive,
//         );
//         if (archive != null) {
//           await moveMails([message], mailbox, archive);
//         }
//         break;
//       case SwapAction.delete:
//         await deleteMails([message], mailbox);
//         break;
//       case SwapAction.toggleFlag:
//         await updateFlag([message], mailbox);
//         break;
//       case SwapAction.markAsJunk:
//         final spam = mailboxes.firstWhereOrNull(
//               (element) => element.isJunk,
//         );
//         if (spam != null) {
//           await moveMails([message], mailbox, spam);
//         }
//         break;
//     }
//   }
//
//   Future rtlTap(MimeMessage message, Mailbox mailbox) async {
//     SwapAction action = getSwapAction(SwapDirection.rtl);
//     switch (action) {
//       case SwapAction.readUnread:
//         await markAsReadUnread([message], mailbox, !message.isSeen);
//         break;
//       case SwapAction.archive:
//         final archive = mailboxes.firstWhereOrNull(
//               (element) => element.isArchive,
//         );
//         if (archive != null) {
//           await moveMails([message], mailbox, archive);
//         }
//         break;
//       case SwapAction.delete:
//         await deleteMails([message], mailbox);
//         break;
//       case SwapAction.toggleFlag:
//         await updateFlag([message], mailbox);
//         break;
//       case SwapAction.markAsJunk:
//         final spam = mailboxes.firstWhereOrNull(
//               (element) => element.isJunk,
//         );
//         if (spam != null) {
//           await moveMails([message], mailbox, spam);
//         }
//         break;
//     }
//   }
//
//   void storeContactMails(List<MimeMessage> messages) {
//     // Process in background to avoid blocking UI
//     _queueOperation(() async {
//       // Get existing contacts from storage
//       Set<String> mails = {};
//       mails.addAll((getStoarage.read('mails') ?? []).cast<String>());
//
//       // Process new contacts from messages
//       for (var message in messages) {
//         if (message.from != null) {
//           for (var from in message.from!) {
//             try {
//               if (from.email.isNotEmpty) {
//                 // Store with personal name if available for better display
//                 String formattedAddress = from.personalName != null && from.personalName!.isNotEmpty
//                     ? "${from.personalName} <${from.email}>"
//                     : from.email;
//                 mails.add(formattedAddress);
//               }
//             } catch (e) {
//               logger.e("Error adding contact: $e");
//             }
//           }
//         }
//       }
//
//       // Save updated contacts back to storage
//       getStoarage.write('mails', mails.toList());
//     });
//   }
//
//   // Implement missing methods
//   Future<void> handleIncomingMail(MimeMessage message, [Mailbox? mailbox]) async {
//     // If mailbox is not provided, use the inbox
//     final targetMailbox = mailbox ?? mailBoxInbox;
//
//     // Add new message to the mailbox
//     if (emails[targetMailbox] == null) {
//       emails[targetMailbox] = <MimeMessage>[];
//     }
//
//     // Check for duplicates
//     final existingUids = emails[targetMailbox]!.map((m) => m.uid).toSet();
//     if (!existingUids.contains(message.uid)) {
//       emails[targetMailbox]!.add(message);
//
//       // Sort by date
//       emails[targetMailbox]!.sort((a, b) {
//         final dateA = a.decodeDate() ?? DateTime.now();
//         final dateB = b.decodeDate() ?? DateTime.now();
//         return dateB.compareTo(dateA);
//       });
//
//       emails.refresh();
//       _notifyEmailsChanged(); // Update stream with debouncing
//
//       // Update unread count
//       _updateUnreadCount(targetMailbox);
//
//       // Save to storage
//       if (mailboxStorage[targetMailbox] != null) {
//         _saveMessagesInBackground([message], targetMailbox);
//       }
//     }
//   }
//   Future navigatToMailBox(Mailbox mailbox) async {
//     // if (mailbox.name.toLowerCase() == 'drafts') {
//     //   Get.to(() => const DraftView());
//     // } else {
//     Get.to(() => MailBoxView(mailBox: mailbox));
//     await loadEmailsForBox(mailbox);
//     // }
//   }
//   Future<void> vanishMails(List<MimeMessage> messages, Mailbox mailbox) async {
//     if (messages.isEmpty) return;
//
//     // Remove from emails list immediately for real-time UI update
//     if (emails[mailbox] != null) {
//       for (var message in messages) {
//         emails[mailbox]!.removeWhere((m) => m.uid == message.uid);
//       }
//       emails.refresh(); // Force UI update
//       _notifyEmailsChanged(); // Update stream with debouncing
//
//       // Update unread count
//       _updateUnreadCount(mailbox);
//     }
//
//     // Delete from storage in background
//     _queueOperation(() async {
//       for (var message in messages) {
//         if (mailboxStorage[mailbox] != null) {
//           try {
//             await mailboxStorage[mailbox]!.deleteMessage(message);
//           } catch (e) {
//             logger.e("Error vanishing message from storage: $e");
//           }
//         }
//       }
//     });
//
//     // Vanish on server if connected
//     if (mailService.client.isConnected) {
//       _queueOperation(() async {
//         try {
//           await mailService.client.deleteMessages(
//             MessageSequence.fromMessages(messages),
//           );
//         } catch (e) {
//           logger.e("Error vanishing messages on server: $e");
//         }
//       });
//     }
//   }
//
//   // Notify listeners with debouncing to prevent UI jank
//   void _notifyEmailsChanged() {
//     // Cancel existing timer
//     _debounceTimer?.cancel();
//
//     // Set new timer
//     _debounceTimer = Timer(const Duration(milliseconds: 100), () {
//       if (!_emailsSubject.isClosed) {
//         _emailsSubject.add(emails);
//       }
//     });
//   }
//
//   @override
//   void onClose() {
//     _debounceTimer?.cancel();
//     _emailsSubject.close();
//     super.onClose();
//   }
// }
