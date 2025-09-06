import 'package:injectable/injectable.dart';
import 'package:wahda_bank/infrastructure/api/mailsys_api_client.dart';
import 'package:wahda_bank/services/mail_service.dart';

/// Auth use-case: presentation-friendly facade over MailsysApiClient and MailService.
@lazySingleton
class AuthUseCaseException implements Exception {
  final String message;
  const AuthUseCaseException(this.message);
  @override
  String toString() => message;
}

class AuthUseCase {
  final MailsysApiClient _api;
  AuthUseCase(this._api);

  /// Persist IMAP credentials for legacy messaging usage later.
  Future<void> setCredentials(String email, String password) async {
    await MailService.instance.setAccount(email, password);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      return await _api.login(email, password);
    } on MailsysApiException catch (e) {
      throw AuthUseCaseException(e.message);
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      return await _api.requestPasswordReset(email);
    } on MailsysApiException catch (e) {
      throw AuthUseCaseException(e.message);
    }
  }

  Future<Map<String, dynamic>> confirmPasswordReset({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      return await _api.confirmPasswordReset(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );
    } on MailsysApiException catch (e) {
      throw AuthUseCaseException(e.message);
    }
  }
}

