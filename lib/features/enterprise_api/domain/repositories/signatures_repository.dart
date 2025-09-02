import '../entities/signature.dart';
import '../value_objects/user_id.dart';

abstract class SignaturesRepository {
  Future<Signature> upsertSignature({required UserId userId, required Signature signature});
}
