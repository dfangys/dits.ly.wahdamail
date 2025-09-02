import '../../domain/repositories/contacts_repository.dart';
import '../../domain/entities/contact.dart';
import '../../domain/value_objects/user_id.dart';

class ListContacts {
  final ContactsRepository contacts;
  const ListContacts(this.contacts);

  Future<List<Contact>> call(UserId userId, {int? limit, int? offset}) =>
      contacts.listContacts(userId: userId, limit: limit, offset: offset);
}
