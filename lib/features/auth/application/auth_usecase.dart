import 'package:injectable/injectable.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/infrastructure/api/mailsys_api_client.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/shared/auth/secure_token_store.dart';

/// Auth use-case: presentation-friendly facade over MailsysApiClient and MailService.
@lazySingleton
class AuthUseCaseException implements Exception {
  final String message;
  const AuthUseCaseException(this.message);
  @override
  String toString() => message;
}

@lazySingleton
class AuthUseCase {
  final MailsysApiClient _api;
  final SecureTokenStore _tokenStore;
  AuthUseCase(this._api, this._tokenStore);

  static const _storageKeyToken = 'mailsys_token';
  final GetStorage _storage = GetStorage();

  /// Returns true if a non-empty user token exists locally (prefers memory cache).
  bool hasValidToken() {
    final mem = _tokenStore.current;
    if (mem != null && mem.isNotEmpty) return true;
    final t = _storage.read<String>(_storageKeyToken);
    return t != null && t.isNotEmpty;
  }

  /// Ensures authentication is present: prime from disk if needed.
  Future<bool> ensureAuthenticated() async {
    if (_tokenStore.current != null) return true;
    final ok = await _tokenStore.primeFromDisk();
    return ok;
  }

  /// Persist IMAP credentials for legacy messaging usage later.
  Future<void> setCredentials(String email, String password) async {
    await MailService.instance.setAccount(email, password);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await _api.login(email, password);
      // Ensure token memory is primed after login
      if (_tokenStore.current == null) {
        await _tokenStore.primeFromDisk();
      }
      return res;
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

