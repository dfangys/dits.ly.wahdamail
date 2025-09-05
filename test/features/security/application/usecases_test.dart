import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/security/application/usecases/decrypt_message.dart';
import 'package:wahda_bank/features/security/application/usecases/verify_signature.dart';
import 'package:wahda_bank/features/security/domain/services/encryption_service.dart';
import 'package:wahda_bank/features/security/domain/value_objects/email_identity.dart';
import 'package:wahda_bank/features/security/domain/value_objects/encryption_status.dart';
import 'package:wahda_bank/features/security/domain/value_objects/signature_status.dart';
import 'package:wahda_bank/features/security/domain/entities/key_pair.dart';
import 'package:wahda_bank/features/security/domain/value_objects/key_id.dart';
import 'package:wahda_bank/features/security/domain/value_objects/fingerprint.dart';
import 'package:wahda_bank/features/security/infrastructure/keyring_adapter.dart';
import 'package:wahda_bank/features/security/infrastructure/crypto_engine_stub.dart';
import 'package:wahda_bank/features/security/infrastructure/trust_store.dart';
import 'package:wahda_bank/features/security/domain/entities/trust_policy.dart';
import 'package:wahda_bank/shared/error/index.dart';

void main() {
  test('Decrypt success/failure maps to EncryptionStatus', () async {
    final keyring = InMemoryKeyringRepository();
    final engine = StubCryptoEngine(simulateDecryptionFailure: false);
    final svc = EncryptionService(engine: engine, keyring: keyring);
    final uid = EmailIdentity.normalized('alice@example.com');

    await keyring.importKeyPair(
      KeyPair(
        id: const KeyId('k1'),
        fingerprint: const Fingerprint('ABCDEF'),
        owner: uid,
        hasPrivate: true,
        createdAt: DateTime.now(),
      ),
    );

    final decrypt = DecryptMessage(svc);
    final resOk = await decrypt(ciphertext: [42], recipient: uid);
    expect(resOk.status, EncryptionStatus.success);

    engine.simulateDecryptionFailure = true;
    final resFail = await decrypt(ciphertext: [42], recipient: uid);
    expect(resFail.status, EncryptionStatus.failure);
  });

  test('Decrypt throws KeyNotFoundError when key missing', () async {
    final keyring = InMemoryKeyringRepository();
    final svc = EncryptionService(engine: StubCryptoEngine(), keyring: keyring);
    final decrypt = DecryptMessage(svc);
    expect(
      () => decrypt(
        ciphertext: [1, 2],
        recipient: EmailIdentity.normalized('bob@example.com'),
      ),
      throwsA(isA<KeyNotFoundError>()),
    );
  });

  test('VerifySignature valid/invalid maps to SignatureStatus', () async {
    final svc = EncryptionService(
      engine: StubCryptoEngine(verifyReturn: true),
      keyring: InMemoryKeyringRepository(),
    );
    final verify = VerifySignature(svc);
    var status = await verify(
      data: [1],
      signature: [2],
      signer: EmailIdentity.normalized('a@e'),
    );
    expect(status, SignatureStatus.valid);
    // Now invalid
    final svc2 = EncryptionService(
      engine: StubCryptoEngine(verifyReturn: false),
      keyring: InMemoryKeyringRepository(),
    );
    status = await VerifySignature(svc2)(
      data: [1],
      signature: [2],
      signer: EmailIdentity.normalized('a@e'),
    );
    expect(status, SignatureStatus.invalid);
  });

  test('Keyring import/list/remove flows', () async {
    final keyring = InMemoryKeyringRepository();
    final key = KeyPair(
      id: const KeyId('k2'),
      fingerprint: const Fingerprint('123456'),
      owner: EmailIdentity.normalized('c@e'),
      hasPrivate: true,
      createdAt: DateTime.now(),
    );
    await keyring.importKeyPair(key);
    var all = await keyring.list();
    expect(all.length, 1);
    await keyring.remove(const KeyId('k2'));
    all = await keyring.list();
    expect(all.isEmpty, true);
  });

  test('Trust set/get with default unknown', () async {
    final trust = InMemoryTrustRepository();
    final id = EmailIdentity.normalized('z@e');
    var level = await trust.getTrustFor(id);
    expect(level.toString(), contains('unknown'));
    await trust.setTrustFor(id, TrustLevel.verified);
    level = await trust.getTrustFor(id);
    expect(level, TrustLevel.verified);
  });
}
