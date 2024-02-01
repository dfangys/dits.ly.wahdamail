import 'package:flutter/material.dart';
import 'package:wahda_bank/utills/constants/colors.dart';

class WTextFormField extends StatelessWidget {
  const WTextFormField({
    super.key,
    required this.controller,
    required this.icon,
    required this.hintText,
    required this.obscureText,
    required this.validatorText,
  });

  final TextEditingController controller;
  final String icon;
  final String hintText;
  final String validatorText;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width - 40,
      child: TextFormField(
        controller: controller,
        validator: (value) {
          if (value!.isEmpty) {
            return validatorText;
          }
          return null;
        },
        cursorColor: WColors.welcomeScafhold,
        autofocus: true,
        obscureText: obscureText,
        decoration: InputDecoration(
          fillColor: Colors.white,
          filled: true,
          prefixIcon: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              height: 2,
              width: 2,
              child: Image.asset(icon)),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
          hintText: hintText,
          focusColor: WColors.welcomeScafhold,
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
              )),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                // color: Color(0xFF0A993C),
                width: .5,
              )),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: WColors.welcomeScafhold,
              width: .5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: WColors.welcomeScafhold,
              width: .5,
            ),
          ),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: WColors.fieldBlackFont,
        ),
      ),
    );
  }
}
