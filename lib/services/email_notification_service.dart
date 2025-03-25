// import 'dart:async';

// import 'package:enough_mail/enough_mail.dart';
// import 'package:flutter/foundation.dart';

// class EmailNotificationService {
//   // late ImapClient _client;
//   final String _host =
//       'wbmail.wahdabank.com.ly'; // Replace with your IMAP server
//   final String _username = kDebugMode ? "abdullah.salemnaseeb" : "";
//   final String _password = kDebugMode ? "Aa102030.@" : "";

//   // Future<void> connectAndListen({bool useIdle = true}) async {
//   //   _client = ImapClient(
//   //     isLogEnabled: true,
//   //   );

//   //   try {
//   //     if (kDebugMode) {
//   //       print("🔌 Connecting to IMAP server...");
//   //     }

//   //     // Use standard IMAP SSL port (993)
//   //     await _client.connectToServer(_host, 993, isSecure: false).then((value) {
//   //       if (kDebugMode) {
//   //         print("✅ IMAP Connected successfully");
//   //       }
//   //     });

//   //     // Or use STARTTLS if needed
//   //     // await _client.connectToServer(_host, 45734, isSecure: false);
//   //     // await _client.startTls();

//   //     await _client.login(_username, _password);
//   //     if (kDebugMode) {
//   //       print("✅ IMAP Logged in successfully");
//   //     }

//   //     await _client.selectInbox();
//   //     if (kDebugMode) {
//   //       print("📩 IMAP Inbox selected");
//   //     }

//   //     if (useIdle) {
//   //       if (kDebugMode) {
//   //         print("🔄 Listening for new emails (IMAP IDLE mode)...");
//   //       }
//   //       _client.enable(['IDLE']);
//   //       _client.idleStart();
//   //     }
//   //   } catch (e) {
//   //     if (kDebugMode) {
//   //       print("❌ IMAP Connection Error: $e");
//   //     }
//   //   }
//   // }

//   // void disconnect() {
//   //   _client.logout();
//   //   if (kDebugMode) {
//   //     print("🔌 Disconnected from IMAP server");
//   //   }
//   // }

//   Future<void> imapListener() async {
//     final client = ImapClient(isLogEnabled: false);
//     try {
//       await client.connectToServer(_host, 993, isSecure: false);
//       await client.login(_username, _password);
//       await client.selectInbox();

//       // Initial fetch to get the current message count
//       int lastMessageCount =
//           (await client.fetchRecentMessages()).messages.length;

//       // Polling interval (adjust as needed)
//       const Duration pollInterval = Duration(seconds: 3);

//       Timer.periodic(pollInterval, (Timer timer) async {
//         try {
//           final currentMessageCount =
//               (await client.fetchRecentMessages()).messages.length;

//           if (currentMessageCount > lastMessageCount) {
//             // New messages received
//             final newMessagesCount = currentMessageCount - lastMessageCount;
//             final fetchResult = await client.fetchRecentMessages(
//                 messageCount: newMessagesCount, criteria: 'BODY.PEEK[]');

//             for (final message in fetchResult.messages) {
//               printMessage(message); // Process the new message
//               // or your notification logic here.
//             }
//             lastMessageCount = currentMessageCount; // Update last count
//           }
//         } on ImapException catch (e) {
//           if (kDebugMode) {
//             print('IMAP poll failed with $e');
//           }
//           // Handle potential errors during polling (e.g., reconnect)
//         }
//       });

//       // You might want to handle app closure or interruptions here
//       // by canceling the timer and logging out.
//     } on ImapException catch (e) {
//       if (kDebugMode) {
//         print('IMAP connection failed with $e');
//       }
//     }
//   }

//   void printMessage(MimeMessage message) {
//     if (kDebugMode) {
//       print('From: ${message.from}');
//       print('Subject: ${message.body}');
//       print(
//           'Body: ${message.decodeTextPlainPart()}'); // Or decodeTextHtmlPart()
//       print('---');
//     }
//   }
// }




// // Future<void> imapListener() async {
// //   final client = ImapClient(isLogEnabled: false);
// //   try {
// //     await client.connectToServer(imapServerHost, imapServerPort,
// //         isSecure: isImapServerSecure);
// //     await client.login(userName, password);
// //     await client.selectInbox();

// //     // Initial fetch to get the current message count
// //     int lastMessageCount = (await client.fetchMessageCount()) ?? 0;

// //     // Polling interval (adjust as needed)
// //     const Duration pollInterval = Duration(seconds: 30);

// //     Timer.periodic(pollInterval, (Timer timer) async {
// //       try {
// //         final currentMessageCount = (await client.fetchMessageCount()) ?? 0;

// //         if (currentMessageCount > lastMessageCount) {
// //           // New messages received
// //           final newMessagesCount = currentMessageCount - lastMessageCount;
// //           final fetchResult = await client.fetchRecentMessages(
// //               messageCount: newMessagesCount, criteria: 'BODY.PEEK[]');

// //           for (final message in fetchResult.messages) {
// //             printMessage(message); // Process the new message
// //             // or your notification logic here.
// //           }
// //           lastMessageCount = currentMessageCount; // Update last count
// //         }
// //       } on ImapException catch (e) {
// //         print('IMAP poll failed with $e');
// //         // Handle potential errors during polling (e.g., reconnect)
// //       }
// //     });

// //     // You might want to handle app closure or interruptions here
// //     // by canceling the timer and logging out.
// //   } on ImapException catch (e) {
// //     print('IMAP connection failed with $e');
// //   }
// // }
