
abstract class SmtpGateway {
  Future<void> sendEnqueued(String queueId);
}

class EnoughSmtpGateway implements SmtpGateway {
  @override
  Future<void> sendEnqueued(String queueId) async {
    // P2 scope: headers-only. No-op for now.
    await Future.value();
  }
}
