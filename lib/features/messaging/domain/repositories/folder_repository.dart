import '../entities/folder.dart';

/// Domain repository interface for folder operations.
abstract class FolderRepository {
  Future<List<Folder>> listFolders();
  Future<Folder?> getById(String id);
  Future<Folder?> getInbox();
}

