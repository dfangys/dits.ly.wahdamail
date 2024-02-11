import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wahda_bank/widgets/listile/swap_action_tile.dart';

class SwapSettingData {
  Map<String, Widget> swapActions = {
    'read_unread': const SwapActionTile(
      icon: CupertinoIcons.check_mark_circled_solid,
      text: 'Mark as read/unread',
      backgroundColor: Colors.blue,
      iconColor: Colors.blue,
      opacity: 0.2,
    ),
    'archieve': const SwapActionTile(
      icon: CupertinoIcons.archivebox,
      text: 'Archieve',
      backgroundColor: Colors.yellow,
      iconColor: Colors.red,
      opacity: 0.3,
    ),
    'delete': const SwapActionTile(
      icon: CupertinoIcons.delete,
      text: 'Delete',
      backgroundColor: Colors.red,
      iconColor: Colors.red,
      opacity: 0.4,
    ),
    'toggle_flag': const SwapActionTile(
      icon: CupertinoIcons.flag,
      text: 'Toggle Flag',
      backgroundColor: Colors.green,
      iconColor: Colors.green,
      opacity: 0.5,
    ),
    'mark_as_junk': const SwapActionTile(
      icon: CupertinoIcons.ant_circle,
      text: 'Mark as junk',
      backgroundColor: Colors.red,
      iconColor: Colors.red,
      opacity: 0.6,
    ),
  };
}
