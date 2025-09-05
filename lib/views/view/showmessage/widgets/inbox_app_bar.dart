import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/compose/widgets/compose_modal.dart';

class InbocAppBar extends StatefulWidget {
  const InbocAppBar({super.key, required this.message, required this.mailbox});

  final MimeMessage message;
  final Mailbox mailbox;

  @override
  State<InbocAppBar> createState() => _InbocAppBarState();
}

class _InbocAppBarState extends State<InbocAppBar>
    with SingleTickerProviderStateMixin {
  bool isStarred = false;
  late AnimationController _starAnimationController;
  late Animation<double> _starAnimation;

  @override
  void initState() {
    super.initState();
    isStarred = widget.message.isFlagged;

    // Setup animation for star button
    _starAnimationController = AnimationController(
      duration: AppTheme.shortAnimationDuration,
      vsync: this,
    );

    _starAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _starAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    if (isStarred) {
      _starAnimationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _starAnimationController.dispose();
    super.dispose();
  }

  final controller = Get.find<MailBoxController>();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      leading: Semantics(
        button: true,
        label: 'Back',
        child: IconButton(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: Get.back,
          tooltip: 'Back',
        ),
      ),
      actions: [
        AnimatedBuilder(
          animation: _starAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _starAnimation.value,
              child: Semantics(
                button: true,
                label: isStarred ? 'Unstar' : 'Star',
                child: IconButton(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                    color:
                        isStarred
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  tooltip: isStarred ? 'Unstar' : 'Star',
                  onPressed: _toggleStar,
                ),
              ),
            );
          },
        ),
        Semantics(
          button: true,
          label: 'Reply',
          child: IconButton(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.reply_rounded),
            onPressed: () {
              ComposeModal.show(
                context,
                arguments: {'message': widget.message, 'type': 'reply'},
              );
            },
            tooltip: 'Reply',
          ),
        ),
        _buildMoreOptionsButton(),
      ],
    );
  }

  void _toggleStar() async {
    // Play animation
    if (!isStarred) {
      _starAnimationController.forward(from: 0.0);
    } else {
      _starAnimationController.reverse(from: 1.0);
    }

    // Update state and flag in backend
    setState(() {
      isStarred = !isStarred;
    });

    // Update flag in backend
    controller.updateFlag([widget.message], controller.mailBoxInbox);
  }

  Widget _buildMoreOptionsButton() {
    return Semantics(
      button: true,
      label: 'More options',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: PopupMenuButton(
          icon: const Icon(Icons.more_vert_rounded),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          ),
          position: PopupMenuPosition.under,
          itemBuilder:
              (context) => [
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(
                    Icons.forward_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text('Forward'),
                ],
              ),
              onTap: () {
                Future.delayed(const Duration(milliseconds: 100), () {
                  ComposeModal.show(
                    context,
                    arguments: {'message': widget.message, 'type': 'forward'},
                  );
                });
              },
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(
                    Icons.print_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text('Print'),
                ],
              ),
              onTap: () {
                // Print functionality would go here
              },
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(
                    Icons.move_to_inbox_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text('Move to'),
                ],
              ),
              onTap: () {
                Future.delayed(const Duration(milliseconds: 100), () {
                  _showMoveToDialog();
                });
              },
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Delete',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
              onTap: () {
                Future.delayed(const Duration(milliseconds: 100), () {
                  _showDeleteConfirmation();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveToDialog() {
    showCupertinoModalPopup(
      context: context,
      builder:
          (context) => CupertinoActionSheet(
            title: Text(
              'Move message',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            message: Text(
              'Select a folder to move this message to',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            actions: [
              for (var box
                  in controller.mailboxes
                      .whereNot((e) => e == widget.mailbox)
                      .toList())
                CupertinoActionSheetAction(
                  onPressed: () {
                    controller.moveMails([widget.message], widget.mailbox, box);
                    Get.back();
                    Get.back();
                  },
                  child: Text(
                    box.name,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () {
                Get.back();
              },
              child: const Text('Cancel'),
            ),
          ),
    );
  }

  void _showDeleteConfirmation() {
    showCupertinoModalPopup(
      context: context,
      builder:
          (context) => CupertinoActionSheet(
            title: const Text('Delete Message'),
            message: const Text(
              'Are you sure you want to delete this message?',
            ),
            actions: [
              CupertinoActionSheetAction(
                onPressed: () {
                  controller.deleteMails([widget.message], widget.mailbox);
                  Get.back(); // Close dialog
                  Get.back(); // Go back to inbox
                },
                isDestructiveAction: true,
                child: const Text('Delete'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () {
                Get.back();
              },
              child: const Text('Cancel'),
            ),
          ),
    );
  }
}
