import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wahda_bank/utills/constants/colors.dart';
import 'package:wahda_bank/utills/constants/text_strings.dart';

/// Ensures only the username portion is kept when users paste a full email.
/// - Strips everything after the first '@'
/// - Removes any characters not in [a-zA-Z0-9.]
class _UsernameOnlyFormatter extends TextInputFormatter {
  final RegExp _allowed = RegExp(r'[^a-zA-Z0-9\.]');
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;
    // Keep only the substring before '@'
    final atIdx = text.indexOf('@');
    if (atIdx != -1) {
      text = text.substring(0, atIdx);
    }
    // Remove any disallowed characters (including spaces)
    text = text.replaceAll(_allowed, '');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }
}

class WTextFormField extends StatelessWidget {
  const WTextFormField({
    super.key,
    required this.controller,
    this.image = '',
    this.icon = const SizedBox(),
    required this.hintText,
    required this.obscureText,
    required this.validator,
    this.domainFix = false,
  });

  final TextEditingController controller;
  final String image;
  final Widget icon;
  final String hintText;
  final bool obscureText;
  final String? Function(String?)? validator;
  final bool domainFix;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.9,
      child: TextFormField(
        controller: controller,
        validator: validator,
        autofocus: true,
        obscureText: obscureText,
        inputFormatters: [if (domainFix) _UsernameOnlyFormatter()],
        decoration: InputDecoration(
          fillColor: Colors.white,
          filled: true,
          prefixIcon: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            height: 2,
            width: 2,
            child: image != '' ? Image.asset(image) : icon,
          ),
          suffixText: domainFix ? WText.emailSuffix : '',
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          hintText: hintText,
          errorStyle: const TextStyle(height: 0, color: WColors.errorColor),
          hintStyle: const TextStyle(
            fontSize: 16,
            color: WColors.textFieldFont,
            fontWeight: FontWeight.w200,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              // color: Color(0xFF0A993C),
              width: .5,
            ),
          ),
        ),
        style: const TextStyle(fontSize: 16, color: WColors.fieldBlackFont),
      ),
    );
  }
}
