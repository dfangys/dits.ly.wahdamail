import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wahda_bank/widgets/listile/swap_action_tile.dart';

enum SwapAction { readUnread, archive, delete, toggleFlag, markAsJunk }

SwapAction getSwapActionFromString(String action) {
  return SwapAction.values.firstWhere(
        (e) => e.toString().split('.').last == action,
    orElse: () => SwapAction.readUnread,
  );
}

class SwapSettingData {
  // Modern styled swap action widgets with enhanced visual design
  Map<SwapAction, Widget> swapActions = {
    SwapAction.readUnread: const SwapActionTile(
      icon: CupertinoIcons.envelope_open,
      text: 'Mark as read/unread',
      backgroundColor: Color(0xFF4285F4),
      iconColor: Colors.white,
      opacity: 0.9,
    ),
    SwapAction.archive: const SwapActionTile(
      icon: CupertinoIcons.archivebox_fill,
      text: 'Archive',
      backgroundColor: Color(0xFFFBBC05),
      iconColor: Colors.white,
      opacity: 0.9,
    ),
    SwapAction.delete: const SwapActionTile(
      icon: CupertinoIcons.trash_fill,
      text: 'Delete',
      backgroundColor: Color(0xFFEA4335),
      iconColor: Colors.white,
      opacity: 0.9,
    ),
    SwapAction.toggleFlag: const SwapActionTile(
      icon: CupertinoIcons.flag_fill,
      text: 'Toggle Flag',
      backgroundColor: Color(0xFF34A853),
      iconColor: Colors.white,
      opacity: 0.9,
    ),
    SwapAction.markAsJunk: const SwapActionTile(
      icon: CupertinoIcons.exclamationmark_shield_fill,
      text: 'Mark as junk',
      backgroundColor: Color(0xFF9C27B0),
      iconColor: Colors.white,
      opacity: 0.9,
    ),
  };

  // Enhanced model data with improved colors and icons
  Map<SwapAction, SwapActionModel> swapActionModel = {
    SwapAction.readUnread: SwapActionModel(
      icon: CupertinoIcons.envelope_open,
      text: 'Mark as read/unread',
      backgroundColor: const Color(0xFF4285F4),
      iconColor: Colors.white,
      opacity: 0.9,
      description: 'Toggle read status of emails',
    ),
    SwapAction.archive: SwapActionModel(
      icon: CupertinoIcons.archivebox_fill,
      text: 'Archive',
      backgroundColor: const Color(0xFFFBBC05),
      iconColor: Colors.white,
      opacity: 0.9,
      description: 'Move emails to archive',
    ),
    SwapAction.delete: SwapActionModel(
      icon: CupertinoIcons.trash_fill,
      text: 'Delete',
      backgroundColor: const Color(0xFFEA4335),
      iconColor: Colors.white,
      opacity: 0.9,
      description: 'Delete emails',
    ),
    SwapAction.toggleFlag: SwapActionModel(
      icon: CupertinoIcons.flag_fill,
      text: 'Toggle Flag',
      backgroundColor: const Color(0xFF34A853),
      iconColor: Colors.white,
      opacity: 0.9,
      description: 'Flag or unflag emails',
    ),
    SwapAction.markAsJunk: SwapActionModel(
      icon: CupertinoIcons.exclamationmark_shield_fill,
      text: 'Mark as junk',
      backgroundColor: const Color(0xFF9C27B0),
      iconColor: Colors.white,
      opacity: 0.9,
      description: 'Move emails to junk folder',
    )
  };
}

class SwapActionModel {
  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color iconColor;
  final double opacity;
  final String description; // Added description for better UX

  SwapActionModel({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.iconColor,
    required this.opacity,
    this.description = '',
  });
}
