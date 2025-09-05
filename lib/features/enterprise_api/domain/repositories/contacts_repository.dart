import '../entities/contact.dart';
import '../value_objects/user_id.dart';

abstract class ContactsRepository {
  Future<List<Contact>> listContacts({
    required UserId userId,
    int? limit,
    int? offset,
  });
}
