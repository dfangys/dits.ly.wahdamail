// lib/design_system/components/toolbar_spacer.dart
import 'package:flutter/material.dart';
import 'package:wahda_bank/design_system/theme/tokens.dart';

class ToolbarSpacer extends StatelessWidget {
  final double width;
  const ToolbarSpacer._(this.width, {super.key});

  const ToolbarSpacer.xs({super.key}) : width = Tokens.space3; // 8
  const ToolbarSpacer.sm({super.key}) : width = Tokens.space4; // 12
  const ToolbarSpacer.md({super.key}) : width = Tokens.space5; // 16
  const ToolbarSpacer.lg({super.key}) : width = Tokens.space6; // 24

  @override
  Widget build(BuildContext context) => SizedBox(width: width);
}
