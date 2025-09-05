import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/infrastructure/api/mailsys_api_client.dart';
import 'package:wahda_bank/features/auth/presentation/screens/login/login.dart';
import 'package:wahda_bank/features/auth/presentation/screens/login/widgets/rounded_button.dart';
import 'package:wahda_bank/features/auth/presentation/screens/login/widgets/text_form_field.dart';
import 'package:wahda_bank/widgets/custom_loading_button.dart';

class ResetPasswordNewPasswordScreen extends StatefulWidget {
  const ResetPasswordNewPasswordScreen({
    super.key,
    required this.email,
    required this.otp,
  });
  final String email;
  final String otp;

  @override
  State<ResetPasswordNewPasswordScreen> createState() =>
      _ResetPasswordNewPasswordScreenState();
}

class _ResetPasswordNewPasswordScreenState
    extends State<ResetPasswordNewPasswordScreen> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final CustomLoadingButtonController _btnController =
      CustomLoadingButtonController();
  final mailsys = Get.find<MailsysApiClient>();

  bool _isSubmitting = false;

  // Password rules
  bool get _hasMinLen => _password.text.length >= 8;
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_password.text);
  bool get _hasLower => RegExp(r'[a-z]').hasMatch(_password.text);
  bool get _hasDigit => RegExp(r'\d').hasMatch(_password.text);
  bool get _hasSymbol => RegExp(r'[^A-Za-z0-9]').hasMatch(_password.text);

  int get _score {
    int s = 0;
    if (_hasMinLen) s++;
    if (_hasUpper) s++;
    if (_hasLower) s++;
    if (_hasDigit) s++;
    if (_hasSymbol) s++;
    return s;
  }

  Color _scoreColor(BuildContext context) {
    switch (_score) {
      case 0:
      case 1:
        return Colors.red.shade400;
      case 2:
        return Colors.orange.shade400;
      case 3:
        return Colors.amber.shade600;
      case 4:
        return Colors.lightGreen.shade600;
      default:
        return Colors.green.shade700;
    }
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Enter a new password';
    if (!_hasMinLen) return 'Minimum length is 8 characters';
    if (!_hasUpper) return 'Include at least one uppercase letter';
    if (!_hasLower) return 'Include at least one lowercase letter';
    if (!_hasDigit) return 'Include at least one number';
    if (!_hasSymbol) return 'Include at least one symbol';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Confirm your new password';
    if (v != _password.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isSubmitting = true);
      _btnController.start();
      final res = await mailsys.confirmPasswordReset(
        email: widget.email,
        otp: widget.otp,
        newPassword: _password.text,
      );
      if (res['status'] == 'success') {
        _btnController.success();
        if (mounted) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.success,
            title: 'Success',
            desc: 'Your password has been reset successfully.',
            btnOkOnPress: () {
              Get.offAll(() => const LoginScreen());
            },
          ).show();
        }
      } else {
        _btnController.error();
        if (mounted) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            title: 'Error',
            desc: (res['message'] ?? 'Something went wrong').toString(),
            btnOkOnPress: () {},
          ).show();
        }
      }
    } on MailsysApiException catch (e) {
      _btnController.error();
      if (mounted) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'Error',
          desc: e.message,
          btnOkOnPress: () {},
        ).show();
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 600), () {
        _btnController.reset();
      });
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password'), elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 48 : 20,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create a new password',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a strong password to protect your account.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // New password
                    WTextFormField(
                      controller: _password,
                      hintText: 'New Password',
                      obscureText: true,
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 12),

                    // Complexity indicator
                    _PasswordChecklist(
                      hasMinLen: _hasMinLen,
                      hasUpper: _hasUpper,
                      hasLower: _hasLower,
                      hasDigit: _hasDigit,
                      hasSymbol: _hasSymbol,
                      score: _score,
                      color: _scoreColor(context),
                    ),

                    const SizedBox(height: 20),

                    // Confirm password
                    WTextFormField(
                      controller: _confirm,
                      hintText: 'Confirm Password',
                      obscureText: true,
                      validator: _validateConfirm,
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: WRoundedButton(
                        controller: _btnController,
                        onPress: _submit,
                        text: 'Reset Password',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordChecklist extends StatelessWidget {
  const _PasswordChecklist({
    required this.hasMinLen,
    required this.hasUpper,
    required this.hasLower,
    required this.hasDigit,
    required this.hasSymbol,
    required this.score,
    required this.color,
  });

  final bool hasMinLen;
  final bool hasUpper;
  final bool hasLower;
  final bool hasDigit;
  final bool hasSymbol;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: score / 5,
            minHeight: 8,
            color: color,
            backgroundColor: Colors.grey.shade300,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _rule(context, '8+ chars', hasMinLen),
            _rule(context, 'Uppercase', hasUpper),
            _rule(context, 'Lowercase', hasLower),
            _rule(context, 'Number', hasDigit),
            _rule(context, 'Symbol', hasSymbol),
          ],
        ),
      ],
    );
  }

  Widget _rule(BuildContext context, String label, bool ok) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: ok ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: ok ? Colors.green.shade700 : Colors.grey.shade700,
            fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
