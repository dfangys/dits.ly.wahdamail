import '../../domain/entities/email.dart';

class ForwardReplyUseCase {
  const ForwardReplyUseCase();

  Future<Email> prepareReply(Email original, {bool replyAll = false}) async {
    // Build a derived email for reply/reply_all – actual body building lives in infra mapper
    return original;
  }
}
