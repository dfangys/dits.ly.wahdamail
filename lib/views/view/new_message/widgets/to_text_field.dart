import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class WToTextField extends StatefulWidget {
  const WToTextField({
    super.key,
    this.initialValue,
    this.onChanged,
    this.onContactSelected,
  });

  final String? initialValue;
  final Function(String)? onChanged;
  final Function(String)? onContactSelected;

  @override
  State<WToTextField> createState() => _WToTextFieldState();
}

class _WToTextFieldState extends State<WToTextField> {
  final TextEditingController textController = TextEditingController();
  bool _showCc = false;
  bool _showBcc = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      textController.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main To field
        _buildRecipientField(
          label: 'To',
          controller: textController,
          onChanged: widget.onChanged,
        ),

        // CC field (conditionally shown)
        if (_showCc)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildRecipientField(
              label: 'Cc',
              controller: TextEditingController(),
              onChanged: null,
            ),
          ),

        // BCC field (conditionally shown)
        if (_showBcc)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildRecipientField(
              label: 'Bcc',
              controller: TextEditingController(),
              onChanged: null,
            ),
          ),
      ],
    );
  }

  Widget _buildRecipientField({
    required String label,
    required TextEditingController controller,
    Function(String)? onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Label
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),

        // Text field container
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                // Text field
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Enter email address',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimaryColor,
                    ),
                    onChanged: onChanged,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),

                // Show Cc/Bcc buttons only for the main To field
                if (label == 'To') ...[
                  // Cc button
                  if (!_showCc)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showCc = true;
                        });
                      },
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Cc',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  // Bcc button
                  if (!_showBcc)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showBcc = true;
                        });
                      },
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Bcc',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],

                // Contacts button
                IconButton(
                  icon: Icon(
                    CupertinoIcons.person_2_fill,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  onPressed: () {
                    _showContactsDialog();
                  },
                  splashRadius: 20,
                  tooltip: 'Select contacts',
                  padding: const EdgeInsets.all(8),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showContactsDialog() {
    // Mock contacts data - in a real app, this would come from a contacts repository
    final contacts = [
      {'name': 'John Smith', 'email': 'john.smith@example.com'},
      {'name': 'Sarah Johnson', 'email': 'sarah.j@example.com'},
      {'name': 'Michael Brown', 'email': 'michael.brown@example.com'},
      {'name': 'Emma Wilson', 'email': 'emma.wilson@example.com'},
      {'name': 'James Taylor', 'email': 'james.taylor@example.com'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Contact',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search contacts',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.colorPalette[index % AppTheme.colorPalette.length],
                      child: Text(
                        contact['name']![0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(contact['name']!),
                    subtitle: Text(contact['email']!),
                    onTap: () {
                      // Add the selected contact's email to the text field
                      if (textController.text.isEmpty) {
                        textController.text = contact['email']!;
                      } else if (!textController.text.endsWith(', ')) {
                        textController.text = '${textController.text}, ${contact['email']!}';
                      } else {
                        textController.text = '${textController.text}${contact['email']!}';
                      }

                      if (widget.onContactSelected != null) {
                        widget.onContactSelected!(contact['email']!);
                      }

                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
    );
  }
}
