import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'pages/security_page.dart';
import 'pages/signature_page.dart';
import 'pages/swipe_gesture.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            ListTile(
              title: Text('Language'),
              trailing: Text('English'),
              onTap: () {},
            ),
            Divider(),
            ListTile(
              title: Text('Read receipts'),
              trailing: Text('Off'),
              onTap: () {},
            ),
            Divider(),
            ListTile(
              title: Text('Security'),
              trailing: Text('Off'),
              onTap: () {
                Get.to(() => SecurityPage());
              },
            ),
            ListTile(
              title: Text('Swipe Gestures '),
              trailing: Text('Set your swipe preferences'),
              onTap: () {
                Get.to(() => SwipGestureSetting());
              },
            ),
            ListTile(
              title: Text('Signature'),
              trailing: Text('Set your signature'),
              onTap: () {
                Get.to(() => SignaturePage());
              },
            ),
            ListTile(
              title: Text('Logout'),
              trailing: Icon(Icons.logout),
            ),
          ],
        ),
      ),
    );
  }
}
