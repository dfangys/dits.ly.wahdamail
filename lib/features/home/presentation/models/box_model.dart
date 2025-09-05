import 'package:enough_mail/enough_mail.dart';

class BoxModel {
  static Mailbox fromJson(Map<String, dynamic> json) {
    return Mailbox(
      encodedName: json['name'],
      encodedPath: json['path'],
      messagesExists: json['messagesExists'],
      uidNext: json['uidNext'],
      pathSeparator: json['pathSeparator'],
      firstUnseenMessageSequenceId: json['firstUnseenMessageSequenceId'],
      messagesUnseen: json['messagesUnseen'],
      messagesRecent: json['messagesRecent'],
      flags: [],
    );
  }

  static Map<String, dynamic> toJson(Mailbox mailbox) {
    return {
      'name': mailbox.encodedName,
      'path': mailbox.encodedPath,
      'messagesExists': mailbox.messagesExists,
      'uidNext': mailbox.uidNext,
      'pathSeparator': mailbox.pathSeparator,
      'firstUnseenMessageSequenceId': mailbox.firstUnseenMessageSequenceId,
      'messagesUnseen': mailbox.messagesUnseen,
      'messagesRecent': mailbox.messagesRecent,
    };
  }
}
