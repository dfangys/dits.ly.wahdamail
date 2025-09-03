import 'email.dart';

class Mailbox {
  final MailboxId id;
  final String name;
  final bool isInbox;
  final bool isSent;
  final bool isDrafts;

  const Mailbox({
    required this.id,
    required this.name,
    this.isInbox = false,
    this.isSent = false,
    this.isDrafts = false,
  });
}
