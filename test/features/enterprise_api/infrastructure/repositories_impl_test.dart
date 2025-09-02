import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/enterprise_api/domain/entities/account_profile.dart' as dom;
import 'package:wahda_bank/features/enterprise_api/domain/entities/signature.dart' as dom;
import 'package:wahda_bank/features/enterprise_api/domain/value_objects/token.dart' as dom;
import 'package:wahda_bank/features/enterprise_api/domain/value_objects/user_id.dart';
import 'package:wahda_bank/features/enterprise_api/infrastructure/gateways/rest_gateway.dart';
import 'package:wahda_bank/features/enterprise_api/infrastructure/mappers/api_mappers.dart';
import 'package:wahda_bank/features/enterprise_api/infrastructure/repositories_impl/accounts_repository_impl.dart';
import 'package:wahda_bank/features/enterprise_api/infrastructure/repositories_impl/contacts_repository_impl.dart';
import 'package:wahda_bank/features/enterprise_api/infrastructure/repositories_impl/signatures_repository_impl.dart';
import 'package:wahda_bank/features/enterprise_api/infrastructure/token_store.dart';
import 'package:wahda_bank/shared/error/index.dart';

class _FakeGateway extends RestGateway {
  int profileCalls = 0;
  int refreshCalls = 0;
  int contactsCalls = 0;
  int signatureCalls = 0;

  _FakeGateway() : super(_NoopClient());

  @override
  Future<AccountDto> fetchAccountProfile({required String userId, required String accessToken}) async {
    profileCalls++;
    if (profileCalls == 1 && accessToken == 'expired') {
      throw const AuthError('Unauthorized');
    }
    return AccountDto(userId: userId, email: 'e', displayName: 'n');
  }

  @override
  Future<TokenDto> refreshToken({required String refreshToken}) async {
    refreshCalls++;
    return TokenDto(accessToken: 'fresh', refreshToken: 'r2', expiresAtEpochMs: DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch);
  }

  @override
  Future<List<ContactDto>> listContacts({required String userId, required String accessToken, int? limit, int? offset}) async {
    contactsCalls++;
    return [ContactDto(id: 'c1', name: 'Alice', email: 'a@e')];
  }

  @override
  Future<SignatureDto> upsertSignature({required String userId, required String accessToken, required SignatureDto dto}) async {
    signatureCalls++;
    return SignatureDto(id: dto.id, contentHtml: dto.contentHtml, isDefault: dto.isDefault);
  }
}

class _NoopClient implements MailsysApiClient {
  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers, Map<String, String>? query}) async => {};
  @override
  Future<Map<String, dynamic>> post(String path, {Map<String, String>? headers, Object? body}) async => {};
  @override
  Future<Map<String, dynamic>> put(String path, {Map<String, String>? headers, Object? body}) async => {};
}

void main() {
  test('AccountsRepositoryImpl.refreshToken updates store and returns new token', () async {
    final gw = _FakeGateway();
    final store = InMemoryTokenStore();
    final repo = AccountsRepositoryImpl(gateway: gw, tokens: store);
    final uid = UserId('u1');
    store.write(uid, dom.Token(accessToken: 'expired', refreshToken: 'r1', expiresAt: DateTime.now().subtract(const Duration(minutes: 1))));

    final t = await repo.refreshToken(userId: uid);
    expect(t.accessToken, 'fresh');
    expect(store.read(uid)?.accessToken, 'fresh');
    expect(gw.refreshCalls, 1);
  });

  test('AccountsRepositoryImpl.fetchAccountProfile retries after refresh on AuthError', () async {
    final gw = _FakeGateway();
    final store = InMemoryTokenStore();
    final repo = AccountsRepositoryImpl(gateway: gw, tokens: store);
    final uid = UserId('u1');
    store.write(uid, dom.Token(accessToken: 'expired', refreshToken: 'r1', expiresAt: DateTime.now().subtract(const Duration(minutes: 1))));

    final prof = await repo.fetchAccountProfile(userId: uid);
    expect(prof.userId.value, 'u1');
    expect(gw.profileCalls, 2);
    expect(gw.refreshCalls, 1);
  });

  test('ContactsRepositoryImpl.listContacts happy path', () async {
    final gw = _FakeGateway();
    final store = InMemoryTokenStore();
    final repo = ContactsRepositoryImpl(gateway: gw, tokens: store);
    final uid = UserId('u1');
    store.write(uid, dom.Token(accessToken: 'ok', refreshToken: 'r1', expiresAt: DateTime.now().add(const Duration(minutes: 10))));

    final list = await repo.listContacts(userId: uid);
    expect(list.length, 1);
    expect(list.first.email, 'a@e');
    expect(gw.contactsCalls, 1);
  });

  test('SignaturesRepositoryImpl.upsertSignature happy path', () async {
    final gw = _FakeGateway();
    final store = InMemoryTokenStore();
    final repo = SignaturesRepositoryImpl(gateway: gw, tokens: store);
    final uid = UserId('u1');
    store.write(uid, dom.Token(accessToken: 'ok', refreshToken: 'r1', expiresAt: DateTime.now().add(const Duration(minutes: 10))));

    final sig = await repo.upsertSignature(userId: uid, signature: dom.Signature(id: 's1', contentHtml: '<p>Hi</p>', isDefault: true));
    expect(sig.id, 's1');
    expect(sig.contentHtml, '<p>Hi</p>');
    expect(gw.signatureCalls, 1);
  });
}
