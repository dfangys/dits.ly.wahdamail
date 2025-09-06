import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/features/messaging/presentation/api/compose_controller_api.dart';

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
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final composeController = Get.find<ComposeController>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// Email chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              widget.emails.map((email) {
                final personal = email.personalName ?? '';
                final displayLetter =
                    personal.isNotEmpty
                        ? personal[0].toUpperCase()
                        : email.email[0].toUpperCase();

                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.2,
                    ),
                    child: Text(
                      displayLetter,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  label: Text(
                    "${personal.isNotEmpty ? personal : ''} <${email.email}>",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  onDeleted:
                      widget.readOnly
                          ? null
                          : () => widget.onDelete(widget.emails.indexOf(email)),
                  backgroundColor:
                      isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  deleteIconColor:
                      isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                );
              }).toList(),
        ),

        /// TypeAhead field using builder (your version)
        TypeAheadField<MailAddress>(
          controller: controller,
          focusNode: focusNode,
          suggestionsCallback: (pattern) {
            return composeController.mailAddresses
                .where((element) => element.email.contains(pattern))
                .toList();
          },
          itemBuilder: (context, suggestion) {
            final personal = suggestion.personalName ?? '';
            final subtitle = personal.isNotEmpty ? suggestion.email : null;
            final avatarText =
                personal.isNotEmpty
                    ? personal[0].toUpperCase()
                    : suggestion.email[0].toUpperCase();

            return ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.2,
                ),
                child: Text(
                  avatarText,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                personal.isNotEmpty ? personal : suggestion.email,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              subtitle:
                  subtitle != null
                      ? Text(
                        subtitle,
                        style: TextStyle(
                          color:
                              isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                        ),
                      )
                      : null,
            );
          },
          onSelected: (MailAddress address) {
            widget.onInsert(address);
            controller.clear();
          },
          hideOnEmpty: true,
          decorationBuilder: (context, child) {
            return Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              color: isDarkMode ? Colors.grey.shade900 : Colors.white,
              shadowColor: isDarkMode ? Colors.black26 : Colors.grey.shade300,
              child: child,
            );
          },
          builder: (context, ctrl, node) {
            return TextFormField(
              controller: ctrl,
              focusNode: node,
              readOnly: widget.readOnly,
              decoration: InputDecoration(
                hintText: widget.title,
                border: InputBorder.none,
                isDense: true,
                hintStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color:
                      isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.ccBccWidget != null) widget.ccBccWidget!,
                    IconButton(
                      onPressed: () async {
                        if (await FlutterContacts.requestPermission(
                          readonly: true,
                        )) {
                          final contact =
                              await FlutterContacts.openExternalPick();
                          if (contact != null && contact.emails.isNotEmpty) {
                            widget.onInsert(
                              MailAddress(
                                contact.displayName,
                                contact.emails.first.address,
                              ),
                            );
                          }
                        }
                      },
                      icon: Icon(
                        Icons.contacts_outlined,
                        color: theme.colorScheme.primary.withValues(alpha: 0.8),
                        size: 20,
                      ),
                      tooltip: "Select from contacts",
                    ),
                  ],
                ),
              ),
              autofocus: false,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              onChanged: (val) {
                if ((val.trim().endsWith(' ') || val.trim().endsWith(',')) &&
                    val.trim().length > 1) {
                  widget.onInsert(MailAddress("", val.trim()));
                  controller.clear();
                }
              },
              onEditingComplete: () {
                if (controller.text.trim().isNotEmpty) {
                  widget.onInsert(MailAddress("", controller.text.trim()));
                  controller.clear();
                }
              },
            );
          },
        ),
      ],
    );
  }
}
