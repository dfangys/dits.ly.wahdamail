import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/enterprise_api/infrastructure/gateways/rest_gateway.dart';
import 'package:wahda_bank/shared/error/index.dart';

class _FakeClient implements MailsysApiClient {
  int calls = 0;
  final Future<Map<String, dynamic>> Function(String path, {Map<String, String>? headers, Map<String, String>? query}) onGet;
  _FakeClient({required this.onGet});
  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers, Map<String, String>? query}) async {
    calls++;
    return onGet(path, headers: headers, query: query);
  }

  @override
  Future<Map<String, dynamic>> post(String path, {Map<String, String>? headers, Object? body}) async => {};

  @override
  Future<Map<String, dynamic>> put(String path, {Map<String, String>? headers, Object? body}) async => {};
}

void main() {
  test('401 maps to AuthError', () async {
    final client = _FakeClient(onGet: (path, {headers, query}) async {
      throw const RestException(401, 'Unauthorized');
    });
    final gw = RestGateway(client);
    expect(
      () => gw.fetchAccountProfile(userId: 'u1', accessToken: 't'),
      throwsA(isA<AuthError>()),
    );
  });

  test('429 retries then succeeds', () async {
    int i = 0;
    final client = _FakeClient(onGet: (path, {headers, query}) async {
      if (i++ == 0) {
        throw const RestException(429, 'Too Many Requests');
      }
      return {'userId': 'u1', 'email': 'e', 'displayName': 'n'};
    });
    final gw = RestGateway(client, backoff: const NoopBackoff(), max429Retries: 2);
    final dto = await gw.fetchAccountProfile(userId: 'u1', accessToken: 't');
    expect(dto.userId, 'u1');
    expect((client as _FakeClient).calls, 2);
  });

  test('5xx maps to TransientNetworkError', () async {
    final client = _FakeClient(onGet: (path, {headers, query}) async {
      throw const RestException(503, 'Service Unavailable');
    });
    final gw = RestGateway(client);
    expect(
      () => gw.fetchAccountProfile(userId: 'u1', accessToken: 't'),
      throwsA(isA<TransientNetworkError>()),
    );
  });
}
