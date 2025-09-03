import '../../domain/repositories/signatures_repository.dart';
import '../../domain/entities/signature.dart';
import '../../domain/value_objects/user_id.dart';

class UpsertSignature {
  final SignaturesRepository signatures;
  const UpsertSignature(this.signatures);

  Future<Signature> call(UserId userId, Signature signature) =>
      signatures.upsertSignature(userId: userId, signature: signature);
}
