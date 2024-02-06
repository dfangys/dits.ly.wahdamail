import 'package:flutter/material.dart';

class ToEmailsChipsField extends StatelessWidget {
  final Function(String) onInsert;
  final Function(String) onDelete;
  final List<String> emails;
  final TextEditingController controller;
  final String title;
  final bool readOnly;
  const ToEmailsChipsField({
    super.key,
    required this.title,
    required this.emails,
    required this.onInsert,
    required this.onDelete,
    required this.controller,
    this.readOnly = false,
  });
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            child: Wrap(
              spacing: 2,
              runSpacing: -3,
              children: <Widget>[
                ...emails
                    .map((email) => Chip(
                          label: Text(email),
                          deleteIcon: const Icon(Icons.cancel_rounded),
                          onDeleted: () {
                            if (!readOnly) {
                              onDelete(email);
                            }
                          },
                        ))
                    .toList(),
              ],
            ),
          ),
          Focus(
            onFocusChange: ((value) {}),
            child: TextFormField(
              readOnly: readOnly,
              decoration: InputDecoration.collapsed(
                hintText: title,
                hintStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              autofocus: true,
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onChanged: (String val) {},
              onEditingComplete: () {},
            ),
          )
        ],
      ),
    );
  }
}
