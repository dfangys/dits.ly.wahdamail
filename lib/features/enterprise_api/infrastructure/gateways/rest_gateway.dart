import 'dart:async';

import 'package:wahda_bank/shared/error/index.dart';

// Internal client interface (no HTTP types leaked above infra)
abstract class MailsysApiClient {
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers, Map<String, String>? query});
  Future<Map<String, dynamic>> post(String path, {Map<String, String>? headers, Object? body});
  Future<Map<String, dynamic>> put(String path, {Map<String, String>? headers, Object? body});
}

class RestException implements Exception {
  final int status;
  final String message;
  final Map<String, String>? headers;
  const RestException(this.status, this.message, {this.headers});
}

abstract class BackoffStrategy {
  Duration delayForAttempt(int attempt);
}

class NoopBackoff implements BackoffStrategy {
  const NoopBackoff();
  @override
  Duration delayForAttempt(int attempt) => Duration.zero;
}

// DTOs
class AccountDto {
  final String userId;
  final String email;
  final String displayName;
  AccountDto({required this.userId, required this.email, required this.displayName});
  factory AccountDto.fromJson(Map<String, dynamic> j) => AccountDto(
        userId: j['userId'] as String,
        email: j['email'] as String,
        displayName: j['displayName'] as String? ?? '',
      );
}

class ContactDto {
  final String id;
  final String name;
  final String email;
  ContactDto({required this.id, required this.name, required this.email});
  factory ContactDto.fromJson(Map<String, dynamic> j) => ContactDto(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
      );
}

class SignatureDto {
  final String id;
  final String contentHtml;
  final bool isDefault;
  SignatureDto({required this.id, required this.contentHtml, required this.isDefault});
  factory SignatureDto.fromJson(Map<String, dynamic> j) => SignatureDto(
        id: j['id'] as String,
        contentHtml: j['contentHtml'] as String? ?? '',
        isDefault: (j['isDefault'] as bool?) ?? false,
      );
}

class TokenDto {
  final String accessToken;
  final String refreshToken;
  final int expiresAtEpochMs;
  TokenDto({required this.accessToken, required this.refreshToken, required this.expiresAtEpochMs});
  factory TokenDto.fromJson(Map<String, dynamic> j) => TokenDto(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        expiresAtEpochMs: j['expiresAt'] as int,
      );
}

class RestGateway {
  final MailsysApiClient _client;
  final BackoffStrategy _backoff;
  final int _max429Retries;

  RestGateway(this._client, {BackoffStrategy backoff = const NoopBackoff(), int max429Retries = 2})
      : _backoff = backoff,
        _max429Retries = max429Retries;

  Future<AccountDto> fetchAccountProfile({required String userId, required String accessToken}) async {
    return _with429Retry(() async {
      final res = await _client.get('/accounts/$userId', headers: {'Authorization': 'Bearer $accessToken'});
      return AccountDto.fromJson(res);
    });
  }

  Future<List<ContactDto>> listContacts({required String userId, required String accessToken, int? limit, int? offset}) async {
    return _with429Retry(() async {
      final res = await _client.get('/accounts/$userId/contacts', headers: {'Authorization': 'Bearer $accessToken'}, query: {
        if (limit != null) 'limit': '$limit',
        if (offset != null) 'offset': '$offset',
      });
      final list = (res['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      return list.map(ContactDto.fromJson).toList();
    });
  }

  Future<SignatureDto> upsertSignature({required String userId, required String accessToken, required SignatureDto dto}) async {
    return _with429Retry(() async {
      final res = await _client.put('/accounts/$userId/signature', headers: {'Authorization': 'Bearer $accessToken'}, body: {
        'id': dto.id,
        'contentHtml': dto.contentHtml,
        'isDefault': dto.isDefault,
      });
      return SignatureDto.fromJson(res);
    });
  }

  Future<TokenDto> refreshToken({required String refreshToken}) async {
    try {
      final res = await _client.post('/auth/refresh', body: {'refreshToken': refreshToken});
      return TokenDto.fromJson(res);
    } on RestException catch (e) {
      throw _mapError(e);
    } catch (e) {
      throw TransientNetworkError('Network error during refresh', e);
    }
  }

  Future<T> _with429Retry<T>(Future<T> Function() run) async {
    int attempt = 0;
    while (true) {
      try {
        return await run();
      } on RestException catch (e) {
        final err = _mapError(e);
        if (err is RateLimitError && attempt < _max429Retries) {
          final retryAfter = _parseRetryAfterMs(e.headers?['Retry-After']);
          final delay = retryAfter != null ? Duration(milliseconds: retryAfter) : _backoff.delayForAttempt(attempt);
          attempt++;
          if (delay > Duration.zero) {
            await Future<void>.delayed(delay);
          }
          continue;
        }
        throw err;
      } catch (e) {
        throw TransientNetworkError('Network error', e);
      }
    }
  }

  AppError _mapError(RestException e) {
    if (e.status == 401 || e.status == 403) return AuthError('Unauthorized', e);
    if (e.status == 429) return RateLimitError('Rate limited', e);
    if (e.status >= 500) return TransientNetworkError('Server error ${e.status}', e);
    return PermanentProtocolError('HTTP ${e.status}: ${e.message}', e);
  }

  int? _parseRetryAfterMs(String? value) {
    if (value == null) return null;
    final v = int.tryParse(value);
    if (v != null) return v * 1000; // seconds
    return null;
  }
}
