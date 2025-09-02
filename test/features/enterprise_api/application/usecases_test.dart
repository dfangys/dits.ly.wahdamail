import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wahda_bank/features/enterprise_api/application/usecases/fetch_account_profile.dart';
import 'package:wahda_bank/features/enterprise_api/application/usecases/list_contacts.dart';
import 'package:wahda_bank/features/enterprise_api/application/usecases/upsert_signature.dart';
import 'package:wahda_bank/features/enterprise_api/application/usecases/validate_session.dart';
import 'package:wahda_bank/features/enterprise_api/domain/entities/account_profile.dart';
import 'package:wahda_bank/features/enterprise_api/domain/entities/contact.dart';
import 'package:wahda_bank/features/enterprise_api/domain/entities/signature.dart' as dom;
import 'package:wahda_bank/features/enterprise_api/domain/value_objects/token.dart';
import 'package:wahda_bank/features/enterprise_api/domain/value_objects/user_id.dart';
import 'package:wahda_bank/features/enterprise_api/domain/repositories/accounts_repository.dart';
import 'package:wahda_bank/features/enterprise_api/domain/repositories/contacts_repository.dart';
import 'package:wahda_bank/features/enterprise_api/domain/repositories/signatures_repository.dart';

class _MockAccounts extends Mock implements AccountsRepository {}
class _MockContacts extends Mock implements ContactsRepository {}
class _MockSignatures extends Mock implements SignaturesRepository {}

void main() {
  test('FetchAccountProfile orchestrates repo call', () async {
    final repo = _MockAccounts();
    final uc = FetchAccountProfile(repo);
    final uid = UserId('u1');
    when(() => repo.fetchAccountProfile(userId: uid)).thenAnswer((_) async => AccountProfile(userId: uid, email: 'e', displayName: 'n'));
    final res = await uc(uid);
    expect(res.email, 'e');
    verify(() => repo.fetchAccountProfile(userId: uid)).called(1);
  });

  test('ListContacts orchestrates repo call', () async {
    final repo = _MockContacts();
    final uc = ListContacts(repo);
    final uid = UserId('u1');
    when(() => repo.listContacts(userId: uid, limit: any(named: 'limit'), offset: any(named: 'offset'))).thenAnswer((_) async => [Contact(id: 'c1', name: 'n', email: 'e')]);
    final res = await uc(uid, limit: 1);
    expect(res.first.id, 'c1');
  });

  test('UpsertSignature orchestrates repo call', () async {
    final repo = _MockSignatures();
    final uc = UpsertSignature(repo);
    final uid = UserId('u1');
    final sig = dom.Signature(id: 's1', contentHtml: '<p/>', isDefault: true);
    when(() => repo.upsertSignature(userId: uid, signature: sig)).thenAnswer((_) async => sig);
    final res = await uc(uid, sig);
    expect(res.id, 's1');
  });

  test('ValidateSession checks token expiry', () {
    final uc = const ValidateSession();
    final valid = Token(accessToken: 'a', refreshToken: 'r', expiresAt: DateTime.now().add(const Duration(minutes: 5)));
    final expired = Token(accessToken: 'a', refreshToken: 'r', expiresAt: DateTime.now().subtract(const Duration(minutes: 1)));
    expect(uc(valid), true);
    expect(uc(expired), false);
  });
}
