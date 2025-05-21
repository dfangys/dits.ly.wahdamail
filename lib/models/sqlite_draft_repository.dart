import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'package:wahda_bank/views/compose/models/draft_model.dart';

import 'sqlite_database_helper.dart';

/// Repository for managing draft emails in SQLite
class SQLiteDraftRepository {
  static final SQLiteDraftRepository _instance = SQLiteDraftRepository._internal();
  static SQLiteDraftRepository get instance => _instance;

  SQLiteDraftRepository._internal();

  // Stream controller for notifying listeners of changes
  final _draftsStreamController = StreamController<List<DraftModel>>.broadcast();
  Stream<List<DraftModel>> get draftsStream => _draftsStreamController.stream;

  // Value notifier for UI updates
  final ValueNotifier<List<DraftModel>> draftsNotifier = ValueNotifier<List<DraftModel>>([]);

  /// Initialize the repository
  Future<void> init() async {
    // Load initial data
    final drafts = await getAllDrafts();
    draftsNotifier.value = drafts;
    _draftsStreamController.add(drafts);
  }

  /// Save a draft to the database
  Future<DraftModel> saveDraft(DraftModel draft) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final Map<String, dynamic> draftMap = draft.toMap();

      int id;
      if (draft.id == null) {
        // Insert new draft
        id = await db.insert(
          SQLiteDatabaseHelper.tableDrafts,
          draftMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        // Update existing draft
        await db.update(
          SQLiteDatabaseHelper.tableDrafts,
          draftMap,
          where: '${SQLiteDatabaseHelper.columnId} = ?',
          whereArgs: [draft.id],
        );
        id = draft.id!;
      }

      // Create updated DraftModel with correct ID and timestamp
      final updatedDraft = draft.copyWith(
        id: id,
        updatedAt: DateTime.now(),
      );

      // Notify listeners
      final drafts = await getAllDrafts();
      draftsNotifier.value = drafts;
      _draftsStreamController.add(drafts);

      return updatedDraft;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving draft: $e');
      }
      rethrow;
    }
  }
  /// Get a draft by ID
  Future<DraftModel?> getDraft(int id) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;

      final List<Map<String, dynamic>> results = await db.query(
        SQLiteDatabaseHelper.tableDrafts,
        where: '${SQLiteDatabaseHelper.columnId} = ?',
        whereArgs: [id],
      );

      if (results.isEmpty) {
        return null;
      }

      return DraftModel.fromMap(results.first);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting draft: $e');
      }
      return null;
    }
  }

  /// Get all drafts
  Future<List<DraftModel>> getAllDrafts() async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;

      final List<Map<String, dynamic>> results = await db.query(
        SQLiteDatabaseHelper.tableDrafts,
        orderBy: '${SQLiteDatabaseHelper.columnUpdatedAt} DESC',
      );

      return results.map((map) => DraftModel.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all drafts: $e');
      }
      return [];
    }
  }

  /// Delete a draft
  Future<bool> deleteDraft(int id) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;

      final count = await db.delete(
        SQLiteDatabaseHelper.tableDrafts,
        where: '${SQLiteDatabaseHelper.columnId} = ?',
        whereArgs: [id],
      );

      // Notify listeners
      final drafts = await getAllDrafts();
      draftsNotifier.value = drafts;
      _draftsStreamController.add(drafts);

      return count > 0;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting draft: $e');
      }
      return false;
    }
  }

  /// Delete all drafts
  Future<bool> deleteAllDrafts() async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;

      await db.delete(SQLiteDatabaseHelper.tableDrafts);

      // Notify listeners
      draftsNotifier.value = [];
      _draftsStreamController.add([]);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting all drafts: $e');
      }
      return false;
    }
  }

  /// Get drafts by category
  Future<List<DraftModel>> getDraftsByCategory(String category) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;

      final List<Map<String, dynamic>> results = await db.query(
        SQLiteDatabaseHelper.tableDrafts,
        where: '${SQLiteDatabaseHelper.columnCategory} = ?',
        whereArgs: [category],
        orderBy: '${SQLiteDatabaseHelper.columnUpdatedAt} DESC',
      );

      return results.map((map) => DraftModel.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting drafts by category: $e');
      }
      return [];
    }
  }

  /// Get drafts by tag
  Future<List<DraftModel>> getDraftsByTag(String tag) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;

      final List<Map<String, dynamic>> results = await db.query(
        SQLiteDatabaseHelper.tableDrafts,
        where: '${SQLiteDatabaseHelper.columnTags} LIKE ?',
        whereArgs: ['%$tag%'],
        orderBy: '${SQLiteDatabaseHelper.columnUpdatedAt} DESC',
      );

      return results
          .map((map) => DraftModel.fromMap(map))
          .where((draft) => draft.tags.contains(tag))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting drafts by tag: $e');
      }
      return [];
    }
  }

  /// Get scheduled drafts
  Future<List<DraftModel>> getScheduledDrafts() async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;

      final List<Map<String, dynamic>> results = await db.query(
        SQLiteDatabaseHelper.tableDrafts,
        where: '${SQLiteDatabaseHelper.columnIsScheduled} = ?',
        whereArgs: [1],
        orderBy: '${SQLiteDatabaseHelper.columnScheduledFor} ASC',
      );

      return results.map((map) => DraftModel.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting scheduled drafts: $e');
      }
      return [];
    }
  }

  /// Get drafts that need to be synced
  Future<List<DraftModel>> getDirtyDrafts() async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;

      final List<Map<String, dynamic>> results = await db.query(
        SQLiteDatabaseHelper.tableDrafts,
        where: '${SQLiteDatabaseHelper.columnIsDirty} = ?',
        whereArgs: [1],
        orderBy: '${SQLiteDatabaseHelper.columnUpdatedAt} DESC',
      );

      return results.map((map) => DraftModel.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting dirty drafts: $e');
      }
      return [];
    }
  }

  /// Mark a draft as having a sync error with a given error message
  Future<void> markDraftSyncError(int draftId, String error) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;

      await db.update(
        SQLiteDatabaseHelper.tableDrafts,
        {
          SQLiteDatabaseHelper.columnIsSynced: 0,
          SQLiteDatabaseHelper.columnIsDirty: 1,
          SQLiteDatabaseHelper.columnLastError: error,
          SQLiteDatabaseHelper.columnUpdatedAt: DateTime.now().millisecondsSinceEpoch,
        },
        where: '${SQLiteDatabaseHelper.columnId} = ?',
        whereArgs: [draftId],
      );

      // Notify listeners
      final drafts = await getAllDrafts();
      draftsNotifier.value = drafts;
      _draftsStreamController.add(drafts);
    } catch (e) {
      if (kDebugMode) {
        print('Error marking draft sync error: $e');
      }
    }
  }

  /// Update the category of a specific draft
  Future<void> updateDraftCategory(int draftId, String category) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;

      await db.update(
        SQLiteDatabaseHelper.tableDrafts,
        {
          SQLiteDatabaseHelper.columnCategory: category,
          SQLiteDatabaseHelper.columnUpdatedAt: DateTime.now().millisecondsSinceEpoch,
        },
        where: '${SQLiteDatabaseHelper.columnId} = ?',
        whereArgs: [draftId],
      );

      // Notify listeners
      final drafts = await getAllDrafts();
      draftsNotifier.value = drafts;
      _draftsStreamController.add(drafts);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating draft category: $e');
      }
    }
  }

  /// Mark a draft as synced with the server
  Future<void> markDraftSynced(int draftId, int serverUid) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;

      await db.update(
        SQLiteDatabaseHelper.tableDrafts,
        {
          SQLiteDatabaseHelper.columnIsSynced: 1,
          SQLiteDatabaseHelper.columnServerUid: serverUid,
          SQLiteDatabaseHelper.columnIsDirty: 0,
          SQLiteDatabaseHelper.columnUpdatedAt: DateTime.now().millisecondsSinceEpoch,
        },
        where: '${SQLiteDatabaseHelper.columnId} = ?',
        whereArgs: [draftId],
      );

      // Notify listeners
      final drafts = await getAllDrafts();
      draftsNotifier.value = drafts;
      _draftsStreamController.add(drafts);
    } catch (e) {
      if (kDebugMode) {
        print('Error marking draft as synced: $e');
      }
    }
  }

  /// Get a draft by its message ID
  Future<DraftModel?> getDraftByMessageId(String messageId) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;

      final List<Map<String, dynamic>> results = await db.query(
        SQLiteDatabaseHelper.tableDrafts,
        where: '${SQLiteDatabaseHelper.columnMessageId} = ?',
        whereArgs: [messageId],
      );

      if (results.isEmpty) return null;

      return DraftModel.fromMap(results.first);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting draft by messageId: $e');
      }
      return null;
    }
  }
  /// Dispose resources
  void dispose() {
    _draftsStreamController.close();
  }
}
