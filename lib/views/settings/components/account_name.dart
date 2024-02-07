import 'package:flutter/material.dart';
import 'package:html_editor_enhanced/html_editor.dart';

class AccountNameSheet extends StatelessWidget {
  AccountNameSheet({super.key});
  final htmlController = HtmlEditorController();

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Text("Name"),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  )
                ],
              ),
              const Divider(),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter your name',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
