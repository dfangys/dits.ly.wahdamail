import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// MailSys Enterprise API client
///
/// Endpoints implemented from: MailSys API (Enterprise).postman_collection.json
/// Covers: auth, user, BCC, auto reply, signatures, contacts, contact groups.
///
/// Usage:
/// final api = Get.put(MailsysApiClient());
/// await api.configure(baseUrl: 'https://chase.com.ly', token: null);
/// final login = await api.login(email, password);
/// if (login.requiresOtp) { await api.verifyOtp(email, otp); }
import 'package:wahda_bank/config/api_config.dart';

class MailsysApiClient extends GetConnect {
  static const _storageKeyBaseUrl = 'mailsys_base_url';
  static const _storageKeyToken = 'mailsys_token';
  static const _storageKeyAppToken = 'mailsys_app_token';

  final GetStorage _storage = GetStorage();
  String? _appToken; // in-memory cache of the app-level bearer

  @override
  void onInit() {
    final savedBaseUrl = _storage.read<String>(_storageKeyBaseUrl);
    httpClient.baseUrl =
        (savedBaseUrl?.isNotEmpty == true) ? savedBaseUrl! : ApiConfig.baseUrl;
    httpClient.timeout = const Duration(seconds: 60);

    // Load app token from storage or from dart-define for pre-auth usage
    _appToken = _storage.read<String>(_storageKeyAppToken);
    if (_appToken == null || _appToken!.isEmpty) {
      if (ApiConfig.appToken.isNotEmpty) {
        _appToken = ApiConfig.appToken;
        _storage.write(_storageKeyAppToken, _appToken);
      }
    }

    httpClient.addRequestModifier<Object?>((request) {
      request.headers['Accept'] = 'application/json';
      request.headers['Content-Type'] = 'application/json';
      final userToken = _storage.read<String>(_storageKeyToken);
      // Prefer user token when present; otherwise fall back to app token for pre-auth endpoints
      final authToken =
          (userToken != null && userToken.isNotEmpty)
              ? userToken
              : (_appToken ?? '');
      if (authToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }
      return request;
    });
    super.onInit();
  }

  /// Configure baseUrl and optional tokens at runtime.
  Future<void> configure({
    required String baseUrl,
    String? appToken,
    String? token,
  }) async {
    httpClient.baseUrl = baseUrl;
    await _storage.write(_storageKeyBaseUrl, baseUrl);
    if (appToken != null && appToken.isNotEmpty) {
      _appToken = appToken;
      await _storage.write(_storageKeyAppToken, appToken);
    }
    if (token != null && token.isNotEmpty) {
      await _storage.write(_storageKeyToken, token);
    }
  }

  /// Clear stored token (used on logout or session expiry)
  Future<void> clearToken() async {
    await _storage.remove(_storageKeyToken);
  }

  // -------------------------------
  // Auth
  // -------------------------------

  /// POST /api/login
  /// Returns either {requires_otp: bool} or token in data.token
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await post('/api/login', {
      'email': email,
      'password': password,
    });
    final body = _parse(res);
    // If token present, store it
    final token = body['data']?['token'] as String?;
    if (token != null && token.isNotEmpty) {
      await _storage.write(_storageKeyToken, token);
    }
    return body as Map<String, dynamic>;
  }

  /// POST /api/verify-otp
  /// Returns token in data.token
  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    final res = await post('/api/verify-otp', {'email': email, 'otp': otp});
    final body = _parse(res);
    final token = body['data']?['token'] as String?;
    if (token != null && token.isNotEmpty) {
      await _storage.write(_storageKeyToken, token);
    }
    return body as Map<String, dynamic>;
  }

  /// POST /api/logout
  Future<Map<String, dynamic>> logout() async {
    final res = await post('/api/logout', {});
    final body = _parse(res);
    await clearToken();
    return body;
  }

  // -------------------------------
  // User
  // -------------------------------

  /// GET /api/user
  Future<Map<String, dynamic>> getUserProfile() async {
    final res = await get('/api/user');
    return _parse(res);
  }

  /// PATCH /api/user/two-factor {enabled: bool}
  Future<Map<String, dynamic>> updateTwoFactor({required bool enabled}) async {
    final res = await patch('/api/user/two-factor', {'enabled': enabled});
    return _parse(res);
  }

  // -------------------------------
  // BCC
  // -------------------------------

  /// GET /api/bcc
  Future<Map<String, dynamic>> listBcc() async {
    final res = await get('/api/bcc');
    return _parse(res);
  }

  /// GET /api/bcc/:email
  Future<Map<String, dynamic>> getBccByEmail(String email) async {
    final res = await get('/api/bcc/$email');
    return _parse(res);
  }

  /// POST /api/bcc
  /// { username, forward_user, type: 'sender'|'recipient', active: bool }
  Future<Map<String, dynamic>> createBcc({
    required String username,
    required String forwardUser,
    required String type,
    required bool active,
  }) async {
    final res = await post('/api/bcc', {
      'username': username,
      'forward_user': forwardUser,
      'type': type,
      'active': active,
    });
    return _parse(res);
  }

  // Note: Update/Delete BCC endpoints in the Postman collection are marked disabled due to route/controller mismatch.
  // Implement once backend contract is clarified (ID vs email parameter).

  // -------------------------------
  // Auto-Reply
  // -------------------------------

  /// GET /api/auto-reply/:email
  Future<Map<String, dynamic>> getAutoReply(String email) async {
    final res = await get('/api/auto-reply/$email');
    return _parse(res);
  }

  /// POST /api/auto-reply (upsert)
  /// username, full_name, subject, content, start_time (unix), end_time (unix or -1), interval (seconds)
  Future<Map<String, dynamic>> upsertAutoReply({
    required String username,
    required String fullName,
    required String subject,
    required String content,
    required int startTime,
    required int endTime,
    required int interval,
  }) async {
    final res = await post('/api/auto-reply', {
      'username': username,
      'full_name': fullName,
      'subject': subject,
      'content': content,
      'start_time': startTime,
      'end_time': endTime,
      'interval': interval,
    });
    return _parse(res);
  }

  /// PUT /api/auto-reply/:email
  Future<Map<String, dynamic>> updateAutoReply(
    String email,
    Map<String, dynamic> body,
  ) async {
    final res = await put('/api/auto-reply/$email', body);
    return _parse(res);
  }

  /// DELETE /api/auto-reply/:email
  Future<Map<String, dynamic>> deleteAutoReply(String email) async {
    final res = await delete('/api/auto-reply/$email');
    return _parse(res);
  }

  // -------------------------------
  // Signatures
  // -------------------------------

  /// GET /api/signatures
  Future<Map<String, dynamic>> listSignatures() async {
    final res = await get('/api/signatures');
    return _parse(res);
  }

  /// POST /api/signatures
  /// { name, content, is_default }
  Future<Map<String, dynamic>> createSignature({
    required String name,
    required String content,
    bool isDefault = false,
  }) async {
    final res = await post('/api/signatures', {
      'name': name,
      'content': content,
      'is_default': isDefault,
    });
    return _parse(res);
  }

  /// GET /api/signatures/:id
  Future<Map<String, dynamic>> getSignature(int id) async {
    final res = await get('/api/signatures/$id');
    return _parse(res);
  }

  /// PUT /api/signatures/:id
  Future<Map<String, dynamic>> updateSignature(
    int id,
    Map<String, dynamic> body,
  ) async {
    final res = await put('/api/signatures/$id', body);
    return _parse(res);
  }

  /// DELETE /api/signatures/:id
  Future<Map<String, dynamic>> deleteSignature(int id) async {
    final res = await delete('/api/signatures/$id');
    return _parse(res);
  }

  // -------------------------------
  // Password Reset
  // -------------------------------

  /// POST /api/reset-password { email }
  /// Sends OTP to user's phone
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final res = await post('/api/reset-password', {'email': email});
    return _parse(res) as Map<String, dynamic>;
  }

  /// POST /api/reset-password/confirm { email, otp, new_password }
  /// Confirms OTP and sets new password
  Future<Map<String, dynamic>> confirmPasswordReset({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final res = await post('/api/reset-password/confirm', {
      'email': email,
      'otp': otp,
      'new_password': newPassword,
    });
    return _parse(res) as Map<String, dynamic>;
  }

  // -------------------------------
  // Contacts
  // -------------------------------

  /// GET /api/contacts
  Future<Map<String, dynamic>> listContacts() async {
    final res = await get('/api/contacts');
    return _parse(res);
  }

  /// POST /api/contacts
  /// { name, email, phone, notes, group_ids: [] }
  Future<Map<String, dynamic>> createContact({
    required String name,
    required String email,
    String? phone,
    String? notes,
    List<int>? groupIds,
  }) async {
    final res = await post('/api/contacts', {
      'name': name,
      'email': email,
      if (phone != null) 'phone': phone,
      if (notes != null) 'notes': notes,
      'group_ids': groupIds ?? <int>[],
    });
    return _parse(res);
  }

  /// GET /api/contacts/:id
  Future<Map<String, dynamic>> getContact(int id) async {
    final res = await get('/api/contacts/$id');
    return _parse(res);
  }

  /// PUT /api/contacts/:id
  Future<Map<String, dynamic>> updateContact(
    int id,
    Map<String, dynamic> body,
  ) async {
    final res = await put('/api/contacts/$id', body);
    return _parse(res);
  }

  /// DELETE /api/contacts/:id
  Future<Map<String, dynamic>> deleteContact(int id) async {
    final res = await delete('/api/contacts/$id');
    return _parse(res);
  }

  // -------------------------------
  // Contact Groups
  // -------------------------------

  /// GET /api/contact-groups
  Future<Map<String, dynamic>> listContactGroups() async {
    final res = await get('/api/contact-groups');
    return _parse(res);
  }

  /// POST /api/contact-groups
  /// { name, description, contact_ids: [] }
  Future<Map<String, dynamic>> createContactGroup({
    required String name,
    String? description,
    List<int>? contactIds,
  }) async {
    final res = await post('/api/contact-groups', {
      'name': name,
      if (description != null) 'description': description,
      'contact_ids': contactIds ?? <int>[],
    });
    return _parse(res);
  }

  /// GET /api/contact-groups/:id
  Future<Map<String, dynamic>> getContactGroup(int id) async {
    final res = await get('/api/contact-groups/$id');
    return _parse(res);
  }

  /// PUT /api/contact-groups/:id
  Future<Map<String, dynamic>> updateContactGroup(
    int id,
    Map<String, dynamic> body,
  ) async {
    final res = await put('/api/contact-groups/$id', body);
    return _parse(res);
  }

  /// DELETE /api/contact-groups/:id
  Future<Map<String, dynamic>> deleteContactGroup(int id) async {
    final res = await delete('/api/contact-groups/$id');
    return _parse(res);
  }

  // -------------------------------
  // Helpers
  // -------------------------------

  dynamic _parse(Response response) {
    if (kDebugMode) {
      // Avoid printing secrets; only print status
      print(
        'MailSys API: ${response.request?.method} ${response.request?.url} -> ${response.statusCode}',
      );
    }
    if (response.isOk && response.body is Map) {
      return response.body;
    }
    if (response.body == null) {
      throw MailsysApiException(
        message: response.statusText ?? 'Network error',
        code: MailsysApiCode.noInternet,
      );
    }
    // Normalize error
    final status = response.statusCode ?? 500;
    final body = response.body;
    final msg =
        (body is Map && body['message'] is String)
            ? body['message'] as String
            : (response.statusText ?? 'Server error');

    if (status == 401) {
      // Token invalid; clear it proactively
      clearToken();
      throw MailsysApiException(
        message: msg,
        code: MailsysApiCode.unAuthorized,
      );
    }
    if (status == 404) {
      throw MailsysApiException(message: msg, code: MailsysApiCode.notFound);
    }
    if (status == 422) {
      throw MailsysApiException(message: msg, code: MailsysApiCode.validation);
    }
    if (status >= 500) {
      throw MailsysApiException(message: msg, code: MailsysApiCode.server);
    }
    throw MailsysApiException(message: msg, code: MailsysApiCode.unknown);
  }
}

enum MailsysApiCode {
  noInternet,
  validation,
  notFound,
  server,
  unknown,
  unAuthorized,
}

class MailsysApiException implements Exception {
  final String message;
  final MailsysApiCode code;
  MailsysApiException({required this.message, required this.code});
  @override
  String toString() => 'MailsysApiException($code): $message';
}
