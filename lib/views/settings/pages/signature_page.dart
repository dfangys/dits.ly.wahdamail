import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wahda_bank/views/settings/components/signature_sheet.dart';

class SignaturePage extends StatelessWidget {
  const SignaturePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signature'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            // enable or disable Signature for Reply, Forward, New Message
            ListTile(
              leading: Icon(Icons.check_circle),
              title: const Text('Reply'),
              onTap: () {},
            ),
            ListTile(
              leading: Icon(Icons.check_circle),
              title: const Text('Forward'),
              onTap: () {},
            ),
            ListTile(
              leading: Icon(Icons.check_circle),
              title: const Text('New Message'),
              onTap: () {},
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Text("Signature"),
                  Positioned(
                    // to position the button to the right
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        if (Platform.isAndroid) {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (context) => SignatureSheet(),
                          );
                        } else {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => SignatureSheet(),
                          );
                        }
                      },
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
