import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
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
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  late final ComposeController composeController;

  @override
  void initState() {
    super.initState();
    composeController = Get.find<ComposeController>();
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Email chips
          if (widget.emails.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ...widget.emails.map(
                      (email) => _buildEmailChip(email),
                ),
              ],
            ),

          if (widget.emails.isNotEmpty)
            const SizedBox(height: 8),

          // Typeahead field with explicit type parameter
          TypeAheadField<MailAddress>(
            controller: controller,
            focusNode: focusNode,
            debounceDuration: const Duration(milliseconds: 300),
            suggestionsCallback: (pattern) {
              if (pattern.isEmpty) {
                return const <MailAddress>[];
              }
              return composeController.mailAddresses
                  .where((element) =>
              element.email.toLowerCase().contains(pattern.toLowerCase()) ||
                  (element.personalName?.toLowerCase().contains(pattern.toLowerCase()) ?? false))
                  .toList();
            },
            // Removed suggestionsBoxDecoration parameter for compatibility
            itemBuilder: (context, MailAddress suggestion) {
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    (suggestion.personalName?.isNotEmpty ?? false)
                        ? suggestion.personalName![0].toUpperCase()
                        : suggestion.email[0].toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  suggestion.personalName ?? suggestion.email,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                subtitle: suggestion.personalName != null
                    ? Text(
                  suggestion.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
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
            hideOnLoading: false,
            hideOnError: true,
            animationDuration: const Duration(milliseconds: 300),
            builder: (context, ctrl, focusNode) => TextFormField(
              readOnly: widget.readOnly,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: widget.title,
                border: InputBorder.none,
                isDense: true,
                hintStyle: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondaryColor,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.ccBccWidget != null) widget.ccBccWidget!,
                    IconButton(
                      onPressed: widget.readOnly ? null : _pickContact,
                      icon: Icon(
                        Icons.contacts_outlined,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      tooltip: 'Select from contacts',
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
              autofocus: false,
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimaryColor,
              ),
              onChanged: (String val) {
                if (val.endsWith(' ') || val.endsWith(',')) {
                  final trimmedVal = val.trim().replaceAll(',', '');
                  if (trimmedVal.isNotEmpty) {
                    widget.onInsert(MailAddress("", trimmedVal));
                    controller.clear();
                  }
                }
              },
              onEditingComplete: () {
                if (controller.text.isNotEmpty) {
                  widget.onInsert(MailAddress("", controller.text.trim()));
                  controller.clear();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailChip(MailAddress email) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (email.personalName?.isNotEmpty ?? false)
            Text(
              email.personalName!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          if (email.personalName?.isNotEmpty ?? false)
            const SizedBox(width: 4),
          Text(
            "<${email.email}>",
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          if (!widget.readOnly)
            InkWell(
              onTap: () => widget.onDelete(widget.emails.indexOf(email)),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickContact() async {
    try {
      if (await FlutterContacts.requestPermission(readonly: true)) {
        final Contact? contact = await FlutterContacts.openExternalPick();
        if (contact != null && contact.emails.isNotEmpty) {
          widget.onInsert(
            MailAddress(
              contact.displayName,
              contact.emails.first.address,
            ),
          );
        } else if (contact != null) {
          Get.snackbar(
            'No Email',
            'The selected contact does not have an email address',
            snackPosition: SnackPosition.BOTTOM,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not access contacts: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }
}

// Enhanced version with animations and better visual feedback
class AnimatedEmailsChipsField extends StatefulWidget {
  final Function(MailAddress) onInsert;
  final Function(int index) onDelete;
  final List<MailAddress> emails;
  final String title;
  final bool readOnly;
  final Widget? ccBccWidget;
  final Color? accentColor;

  const AnimatedEmailsChipsField({
    super.key,
    required this.title,
    required this.emails,
    required this.onInsert,
    required this.onDelete,
    this.ccBccWidget,
    this.readOnly = false,
    this.accentColor,
  });

  @override
  State<AnimatedEmailsChipsField> createState() => _AnimatedEmailsChipsFieldState();
}

class _AnimatedEmailsChipsFieldState extends State<AnimatedEmailsChipsField> with SingleTickerProviderStateMixin {
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  late final ComposeController composeController;
  late AnimationController _animationController;
  late Animation<double> _focusAnimation;
  bool _isFocused = false;

  Color get accentColor => widget.accentColor ?? AppTheme.primaryColor;

  @override
  void initState() {
    super.initState();
    composeController = Get.find<ComposeController>();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _focusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    focusNode.addListener(() {
      setState(() {
        _isFocused = focusNode.hasFocus;
        if (_isFocused) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _focusAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color.lerp(
                Colors.grey.withOpacity(0.2),
                accentColor.withOpacity(0.5),
                _focusAnimation.value,
              )!,
              width: 1.0 + (_focusAnimation.value * 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.1 * _focusAnimation.value),
                blurRadius: 8 * _focusAnimation.value,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Email chips with animated list
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: widget.emails.isNotEmpty
                ? Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ...widget.emails.asMap().entries.map(
                      (entry) {
                    final index = entry.key;
                    final email = entry.value;
                    return _buildAnimatedEmailChip(email, index);
                  },
                ),
              ],
            )
                : const SizedBox.shrink(),
          ),

          if (widget.emails.isNotEmpty)
            const SizedBox(height: 8),

          // Typeahead field with explicit type parameter
          TypeAheadField<MailAddress>(
            controller: controller,
            focusNode: focusNode,
            debounceDuration: const Duration(milliseconds: 300),
            suggestionsCallback: (pattern) {
              if (pattern.isEmpty) {
                return const <MailAddress>[];
              }
              return composeController.mailAddresses
                  .where((element) =>
              element.email.toLowerCase().contains(pattern.toLowerCase()) ||
                  (element.personalName?.toLowerCase().contains(pattern.toLowerCase()) ?? false))
                  .toList();
            },
            // Removed suggestionsBoxDecoration parameter for compatibility
            itemBuilder: (context, MailAddress suggestion) {
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: accentColor.withOpacity(0.1),
                  child: Text(
                    (suggestion.personalName?.isNotEmpty ?? false)
                        ? suggestion.personalName![0].toUpperCase()
                        : suggestion.email[0].toUpperCase(),
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  suggestion.personalName ?? suggestion.email,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                subtitle: suggestion.personalName != null
                    ? Text(
                  suggestion.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
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
            hideOnLoading: false,
            hideOnError: true,
            animationDuration: const Duration(milliseconds: 300),
            builder: (context, ctrl, focusNode) => TextFormField(
              readOnly: widget.readOnly,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: widget.title,
                border: InputBorder.none,
                isDense: true,
                hintStyle: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondaryColor,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.ccBccWidget != null) widget.ccBccWidget!,
                    IconButton(
                      onPressed: widget.readOnly ? null : _pickContact,
                      icon: Icon(
                        Icons.contacts_outlined,
                        color: accentColor,
                        size: 20,
                      ),
                      tooltip: 'Select from contacts',
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
              autofocus: false,
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimaryColor,
              ),
              onChanged: (String val) {
                if (val.endsWith(' ') || val.endsWith(',')) {
                  final trimmedVal = val.trim().replaceAll(',', '');
                  if (trimmedVal.isNotEmpty) {
                    widget.onInsert(MailAddress("", trimmedVal));
                    controller.clear();
                  }
                }
              },
              onEditingComplete: () {
                if (controller.text.isNotEmpty) {
                  widget.onInsert(MailAddress("", controller.text.trim()));
                  controller.clear();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedEmailChip(MailAddress email, int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (email.personalName?.isNotEmpty ?? false)
            Text(
              email.personalName!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          if (email.personalName?.isNotEmpty ?? false)
            const SizedBox(width: 4),
          Text(
            "<${email.email}>",
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          if (!widget.readOnly)
            InkWell(
              onTap: () => widget.onDelete(index),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickContact() async {
    try {
      if (await FlutterContacts.requestPermission(readonly: true)) {
        final Contact? contact = await FlutterContacts.openExternalPick();
        if (contact != null && contact.emails.isNotEmpty) {
          widget.onInsert(
            MailAddress(
              contact.displayName,
              contact.emails.first.address,
            ),
          );
        } else if (contact != null) {
          Get.snackbar(
            'No Email',
            'The selected contact does not have an email address',
            snackPosition: SnackPosition.BOTTOM,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not access contacts: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }
}
