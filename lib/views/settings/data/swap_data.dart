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
  Map<SwapAction, Widget> swapActions = {
    SwapAction.readUnread: const SwapActionTile(
      icon: CupertinoIcons.check_mark_circled_solid,
      text: 'Mark as read/unread',
      backgroundColor: Colors.blue,
      iconColor: Colors.blue,
      opacity: 0.2,
    ),
    SwapAction.archive: const SwapActionTile(
      icon: CupertinoIcons.archivebox,
      text: 'Archive',
      backgroundColor: Colors.yellow,
      iconColor: Colors.red,
      opacity: 0.3,
    ),
    SwapAction.delete: const SwapActionTile(
      icon: CupertinoIcons.delete,
      text: 'Delete',
      backgroundColor: Colors.red,
      iconColor: Colors.red,
      opacity: 0.4,
    ),
    SwapAction.toggleFlag: const SwapActionTile(
      icon: CupertinoIcons.flag,
      text: 'Toggle Flag',
      backgroundColor: Colors.green,
      iconColor: Colors.green,
      opacity: 0.5,
    ),
    SwapAction.markAsJunk: const SwapActionTile(
      icon: CupertinoIcons.ant_circle,
      text: 'Mark as junk',
      backgroundColor: Colors.red,
      iconColor: Colors.red,
      opacity: 0.6,
    ),
  };

  Map<SwapAction, SwapActionModel> swapActionModel = {
    SwapAction.readUnread: SwapActionModel(
      icon: CupertinoIcons.check_mark_circled_solid,
      text: 'Mark as read/unread',
      backgroundColor: Colors.blue,
      iconColor: Colors.blue,
      opacity: 0.2,
    ),
    SwapAction.archive: SwapActionModel(
      icon: CupertinoIcons.archivebox,
      text: 'Archive',
      backgroundColor: Colors.yellow,
      iconColor: Colors.red,
      opacity: 0.3,
    ),
    SwapAction.delete: SwapActionModel(
      icon: CupertinoIcons.delete,
      text: 'Delete',
      backgroundColor: Colors.red,
      iconColor: Colors.red,
      opacity: 0.4,
    ),
    SwapAction.toggleFlag: SwapActionModel(
      icon: CupertinoIcons.flag,
      text: 'Toggle Flag',
      backgroundColor: Colors.green,
      iconColor: Colors.green,
      opacity: 0.5,
    ),
    SwapAction.markAsJunk: SwapActionModel(
      icon: CupertinoIcons.ant_circle,
      text: 'Mark as junk',
      backgroundColor: Colors.red,
      iconColor: Colors.red,
      opacity: 0.6,
    )
  };
}

class SwapActionModel {
  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color iconColor;
  final double opacity;

  SwapActionModel({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.iconColor,
    required this.opacity,
  });
}
