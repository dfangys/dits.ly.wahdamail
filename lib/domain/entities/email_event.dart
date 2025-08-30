import 'email.dart';

enum EmailEventType { added, updated, deleted }

class EmailEvent {
  final Email email;
  final EmailEventType type;
  const EmailEvent(this.email, this.type);
}
