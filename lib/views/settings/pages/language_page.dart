import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Language'),
      ),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.check_circle_sharp),
            title: const Text('English'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.check_circle_sharp),
            title: const Text('Arabic'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
