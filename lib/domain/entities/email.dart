class Email {
  final MessageId id;
  final String subject;
  final EmailAddress from;
  final List<EmailAddress> to;
  final DateTime date;
  final bool isSeen;
  final bool isFlagged;
  final bool hasAttachments;
  final int? sizeBytes;
  final MailboxId mailboxId;

  const Email({
    required this.id,
    required this.subject,
    required this.from,
    required this.to,
    required this.date,
    required this.isSeen,
    required this.isFlagged,
    required this.hasAttachments,
    required this.mailboxId,
    this.sizeBytes,
  });
}

class MessageId {
  final int? uid;
  final int? sequenceId;
  const MessageId({this.uid, this.sequenceId});
}

class EmailAddress {
  final String? name;
  final String email;
  const EmailAddress(this.email, {this.name});
}

class MailboxId {
  final String encodedPath;
  const MailboxId(this.encodedPath);
}
