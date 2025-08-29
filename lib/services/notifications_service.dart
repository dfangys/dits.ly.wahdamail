import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';

// @pragma('vm:entry-point')
// Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   // await NotificationService.instance.setup();
//   // NotificationService.instance.showFlutterNotification(message);
// }

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  if (kDebugMode) {
    print('notificationTapBackground');
    print(notificationResponse);
  }
  // final data = jsonDecode(notificationResponse.payload);
  // if (data['type'] == 'message') {
  //   Get.to(() => ComposeScreen());
  // }
}

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance {
    return _instance ??= NotificationService._();
  }

  NotificationService._();

  late FlutterLocalNotificationsPlugin plugin;
  late AndroidNotificationChannel channel;
  bool isFlutterLocalNotificationsInitialized = false;

  Future<void> setup() async {
    if (isFlutterLocalNotificationsInitialized) {
      return;
    }
    channel = const AndroidNotificationChannel(
      'com.wahda_bank.app.channel',
      'High Importance Notifications',
      description: 'about channel.',
      importance: Importance.high,
    );
    plugin = FlutterLocalNotificationsPlugin();

    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    if (Platform.isAndroid) {
      bool grant = await plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;
      if (!grant) {
        await plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    }
    isFlutterLocalNotificationsInitialized = true;
  }

  void showFlutterNotification(
      String title, String body, Map<String, dynamic> data,
      [int id = 0]) {
    plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: 'ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: data.isNotEmpty ? jsonEncode(data) : null,
    );
  }

  // Handle notification taps when app is in foreground/background (not terminated)
  Future<void> _onNotificationResponse(NotificationResponse details) async {
    try {
      final payloadStr = details.payload;
      if (payloadStr == null || payloadStr.isEmpty) return;
      final dynamic decoded = jsonDecode(payloadStr);
      if (decoded is! Map) return;
      final Map data = decoded as Map;
      final action = data['action'] as String?;
      if (action == 'view_message') {
        final uidStr = data['message_uid']?.toString();
        final mailboxPath = data['mailbox']?.toString();
        if (uidStr == null || mailboxPath == null) return;
        final uid = int.tryParse(uidStr);
        if (uid == null) return;

        // Ensure mail service is ready
        final mailService = MailService.instance;
        if (!mailService.isClientSet) {
          await mailService.init();
        }
        if (!mailService.client.isConnected) {
          await mailService.connect();
        }

        // Locate mailbox by path/name
        Mailbox? target;
        try {
          final boxes = await mailService.client.listMailboxes();
          target = boxes.firstWhereOrNull((mb) =>
              mb.encodedPath == mailboxPath || mb.path == mailboxPath || mb.name == mailboxPath || mb.name.toUpperCase() == mailboxPath.toUpperCase());
        } catch (_) {}
        target ??= await mailService.client.selectInbox();

        // Select mailbox
        try { await mailService.client.selectMailbox(target!); } catch (_) {}

        // Fetch the message by UID
        MimeMessage? message;
        try {
          final seq = MessageSequence.fromRange(uid, uid, isUidSequence: true);
          final msgs = await mailService.client.fetchMessageSequence(
            seq,
            fetchPreference: FetchPreference.fullWhenWithinSize,
          );
          if (msgs.isNotEmpty) {
            message = msgs.first;
          }
        } catch (_) {}

        if (message != null) {
          // Navigate to message details
          if (Get.isRegistered<GetMaterialController>()) {
            // Ensure navigator exists
          }
          Get.to(() => ShowMessage(message: message!, mailbox: target!));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling notification tap: $e');
      }
    }
  }
}
