import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';

/// Enhanced email chips field with improved UX and modern design
class EnhancedEmailChipsField extends StatefulWidget {
  final Function(MailAddress) onInsert;
  final Function(int index) onDelete;
  final List<MailAddress> emails;
  final String title;
  final IconData icon;
  final bool readOnly;
  final Widget? trailingWidget;

  const EnhancedEmailChipsField({
    super.key,
    required this.title,
    required this.icon,
    required this.emails,
    required this.onInsert,
    required this.onDelete,
    this.trailingWidget,
    this.readOnly = false,
  });

  @override
  State<EnhancedEmailChipsField> createState() => _EnhancedEmailChipsFieldState();
}

class _EnhancedEmailChipsFieldState extends State<EnhancedEmailChipsField>
    with SingleTickerProviderStateMixin {
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final composeController = Get.find<ComposeController>();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and title
              Row(
                children: [
                  Icon(
                    widget.icon,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (widget.trailingWidget != null) widget.trailingWidget!,
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Email chips
              if (widget.emails.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.emails.asMap().entries.map((entry) {
                    final index = entry.key;
                    final email = entry.value;
                    return _buildEmailChip(email, index, theme, isDarkMode);
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              
      // TypeAhead input field
      if (!widget.readOnly) _buildTypeAheadField(theme, isDarkMode),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmailChip(MailAddress email, int index, ThemeData theme, bool isDarkMode) {
    final personal = email.personalName ?? '';
    final displayLetter = personal.isNotEmpty
        ? personal[0].toUpperCase()
        : email.email[0].toUpperCase();

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        displayLetter,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Email text
                  Flexible(
                    child: Text(
                      personal.isNotEmpty ? personal : email.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Delete button
                  GestureDetector(
                    onTap: () => widget.onDelete(index),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeAheadField(ThemeData theme, bool isDarkMode) {
    return TypeAheadField<MailAddress>(
      controller: controller,
      focusNode: focusNode,
      suggestionsCallback: (pattern) async {
        if (pattern.isEmpty) return [];
        
        // Search in existing contacts
        final matches = composeController.mailAddresses
            .where((element) => 
                element.email.toLowerCase().contains(pattern.toLowerCase()) ||
                (element.personalName?.toLowerCase().contains(pattern.toLowerCase()) ?? false))
            .toList();
        
        // Sort by relevance (exact matches first, then starts with, then contains)
        matches.sort((a, b) {
          final aEmail = a.email.toLowerCase();
          final bEmail = b.email.toLowerCase();
          final aName = a.personalName?.toLowerCase() ?? '';
          final bName = b.personalName?.toLowerCase() ?? '';
          final searchPattern = pattern.toLowerCase();
          
          // Exact matches first
          if (aEmail == searchPattern || aName == searchPattern) return -1;
          if (bEmail == searchPattern || bName == searchPattern) return 1;
          
          // Starts with matches
          if (aEmail.startsWith(searchPattern) || aName.startsWith(searchPattern)) return -1;
          if (bEmail.startsWith(searchPattern) || bName.startsWith(searchPattern)) return 1;
          
          return 0;
        });
        
        return matches.take(5).toList(); // Limit to 5 suggestions
      },
      itemBuilder: (context, suggestion) {
        final personal = suggestion.personalName ?? '';
        final avatarText = personal.isNotEmpty
            ? personal[0].toUpperCase()
            : suggestion.email[0].toUpperCase();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    avatarText,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Contact info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (personal.isNotEmpty) ...[
                      Text(
                        personal,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      suggestion.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Add icon
              Icon(
                Icons.add_circle_outline,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ],
          ),
        );
      },
      onSelected: (suggestion) {
        widget.onInsert(suggestion);
        controller.clear();
        focusNode.unfocus();
      },
      builder: (context, controller, focusNode) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focusNode.hasFocus
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
              width: focusNode.hasFocus ? 2 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: 'add_recipient'.tr,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              prefixIcon: Icon(
                Icons.add,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Contact picker button
                  IconButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final themeSnapshot = Theme.of(context);
                      try {
                        if (await FlutterContacts.requestPermission(readonly: true)) {
                          final contact = await FlutterContacts.openExternalPick();
                          if (contact != null && contact.emails.isNotEmpty) {
                            widget.onInsert(
                              MailAddress(
                                contact.displayName,
                                contact.emails.first.address,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        // Handle permission denied or other errors
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('contact_picker_error'.tr),
                            backgroundColor: themeSnapshot.colorScheme.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      Icons.contacts_outlined,
                      color: theme.colorScheme.primary.withValues(alpha: 0.8),
                      size: 20,
                    ),
                    tooltip: 'select_from_contacts'.tr,
                  ),
                ],
              ),
            ),
            style: theme.textTheme.bodyMedium,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              // Auto-insert on space or comma (like original implementation)
              if ((value.trim().endsWith(' ') || value.trim().endsWith(',')) && 
                  value.trim().length > 1) {
                final email = value.trim().replaceAll(RegExp(r'[, ]+$'), '');
                if (email.isNotEmpty && email.contains('@')) {
                  final mailAddress = MailAddress('', email);
                  widget.onInsert(mailAddress);
                  controller.clear();
                }
              }
            },
            onEditingComplete: () {
              // Handle editing complete (like original implementation)
              if (controller.text.trim().isNotEmpty) {
                final email = controller.text.trim();
                if (email.contains('@')) {
                  final mailAddress = MailAddress('', email);
                  widget.onInsert(mailAddress);
                  controller.clear();
                }
              }
            },
            onSubmitted: (value) {
              if (value.trim().isNotEmpty && value.contains('@')) {
                final mailAddress = MailAddress('', value.trim());
                widget.onInsert(mailAddress);
                controller.clear();
              }
            },
          ),
        );
      },
    );
  }
}

