import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';

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
      onDidReceiveNotificationResponse: (details) async {
        try {
          final payload = details.payload;
          if (payload == null || payload.isEmpty) return;
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final action = data['action'] as String?;
          if (action == 'view_message') {
            final uidStr = data['message_uid']?.toString();
            final mailboxPath = data['mailbox']?.toString();
            if (uidStr == null || mailboxPath == null) return;
            final uid = int.tryParse(uidStr);
            if (uid == null || uid <= 0) return;

            MailBoxController controller;
            if (Get.isRegistered<MailBoxController>()) {
              controller = Get.find<MailBoxController>();
            } else {
              controller = Get.put(MailBoxController());
            }

            // Open the specific email by UID
            await controller.openEmailByUid(mailboxPath, uid);
          }
        } catch (e) {
          if (kDebugMode) {
            print('Notification tap handling error: $e');
          }
        }
      },
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
}
