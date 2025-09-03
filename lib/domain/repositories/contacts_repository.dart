import '../entities/contact.dart';

abstract class IContactsRepository {
  Future<List<Contact>> listContacts();
  Future<Contact> createContact(Contact contact);
  Future<Contact?> getContact(int id);
  Future<Contact> updateContact(Contact contact);
  Future<void> deleteContact(int id);
}
