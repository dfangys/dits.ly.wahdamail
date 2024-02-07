import 'package:flutter/material.dart';

class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security'),
      ),
      body: Column(
        children: [
          // Enable or disable security using Facelock, Fingerprint, or PIN
          ListTile(
            title: const Text('Enable Security'),
            trailing: const Icon(Icons.lock),
            onTap: () {},
          ),

          // Change the lock method (Facelock, Fingerprint, or PIN)
          ListTile(
            title: const Text('Change Lock Method'),
            trailing: const Text('PIN'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
