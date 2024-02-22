import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';

class ToEmailsChipsField extends StatefulWidget {
  final Function(MailAddress) onInsert;
  final Function(int index) onDelete;
  final List<MailAddress> emails;
  final String title;
  final bool readOnly;
  final Widget? ccBccWidget;
  const ToEmailsChipsField({
    super.key,
    required this.title,
    required this.emails,
    required this.onInsert,
    required this.onDelete,
    this.ccBccWidget,
    this.readOnly = false,
  });

  @override
  State<ToEmailsChipsField> createState() => _ToEmailsChipsFieldState();
}

class _ToEmailsChipsFieldState extends State<ToEmailsChipsField> {
  TextEditingController controller = TextEditingController();
  FocusNode focusNode = FocusNode();
  final composeController = Get.find<ComposeController>();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 0,
            runSpacing: -3,
            children: <Widget>[
              ...widget.emails.map(
                (email) => Chip(
                  padding: EdgeInsets.zero,
                  label: Text(
                    "${email.personalName ?? ''} <${email.email}>",
                  ),
                  deleteIcon: const Icon(Icons.cancel_rounded),
                  onDeleted: () {
                    if (!widget.readOnly) {
                      widget.onDelete(widget.emails.indexOf(email));
                    }
                  },
                ),
              ),
            ],
          ),
          TypeAheadField(
            controller: controller,
            suggestionsCallback: (pattern) {
              return composeController.mailAddresses
                  .where((element) => element.email.contains(pattern))
                  .toList();
            },
            itemBuilder: (context, MailAddress suggestion) {
              return ListTile(
                dense: true,
                title: Text(suggestion.email),
              );
            },
            onSelected: (MailAddress address) {
              widget.onInsert(address);
              controller.clear();
            },
            hideOnEmpty: true,
            builder: (context, ctrl, focusNode) => TextFormField(
              readOnly: widget.readOnly,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: widget.title,
                border: InputBorder.none,
                isDense: true,
                hintStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.ccBccWidget != null) widget.ccBccWidget!,
                    IconButton(
                      onPressed: () async {
                        if (await FlutterContacts.requestPermission(
                            readonly: true)) {
                          final Contact? contact =
                              await FlutterContacts.openExternalPick();
                          if (contact != null) {
                            widget.onInsert(
                              MailAddress(
                                contact.displayName,
                                contact.emails.first.address,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.contacts_outlined),
                    ),
                  ],
                ),
              ),
              autofocus: false,
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onChanged: (String val) {
                if (val.endsWith(' ') || val.endsWith(',')) {
                  widget.onInsert(MailAddress("", val));
                  controller.clear();
                }
              },
              onEditingComplete: () {
                widget.onInsert(MailAddress("", controller.text));
                controller.clear();
              },
            ),
          ),
        ],
      ),
    );
  }
}
