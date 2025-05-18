import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:enough_mail/enough_mail.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/offline_mime_storage.dart';
import '../models/hive_mime_storage.dart';

class MigrationService {
  static final MigrationService instance = MigrationService._internal();
  
  MigrationService._internal();
  
  // Migration status
  final RxBool isMigrating = false.obs;
  final RxDouble migrationProgress = 0.0.obs;
  final RxString migrationStatus = 'Not started'.obs;
  
  // Migration method
  Future<bool> migrateFromHiveToSqlite() async {
    try {
      isMigrating.value = true;
      migrationStatus.value = 'Starting migration...';
      migrationProgress.value = 0.0;
      
      // Get all accounts and mailboxes from Hive
      final hiveStorage = HiveMimeStorage();
      final accounts = await hiveStorage.getAccounts();
      
      if (accounts.isEmpty) {
        migrationStatus.value = 'No accounts found to migrate';
        isMigrating.value = false;
        return true;
      }
      
      int totalMailboxes = 0;
      for (final account in accounts) {
        final mailboxes = await hiveStorage.getMailboxes(account);
        totalMailboxes += mailboxes.length;
      }
      
      if (totalMailboxes == 0) {
        migrationStatus.value = 'No mailboxes found to migrate';
        isMigrating.value = false;
        return true;
      }
      
      int processedMailboxes = 0;
      
      // Process each account and mailbox
      for (final account in accounts) {
        final mailboxes = await hiveStorage.getMailboxes(account);
        
        for (final mailbox in mailboxes) {
          migrationStatus.value = 'Migrating ${mailbox.path} for $account';
          
          // Get messages from Hive
          final messages = await hiveStorage.getMessages(account, mailbox.path);
          
          if (messages.isNotEmpty) {
            // Migrate to SQLite
            await OfflineMimeStorage.instance.migrateFromHive(
              account, 
              mailbox.path, 
              messages
            );
          }
          
          processedMailboxes++;
          migrationProgress.value = processedMailboxes / totalMailboxes;
        }
      }
      
      migrationStatus.value = 'Migration completed successfully';
      migrationProgress.value = 1.0;
      isMigrating.value = false;
      return true;
    } catch (e) {
      migrationStatus.value = 'Migration failed: $e';
      isMigrating.value = false;
      return false;
    }
  }
  
  // Validation method
  Future<Map<String, dynamic>> validateMigration() async {
    final result = {
      'success': true,
      'totalMessages': 0,
      'migratedMessages': 0,
      'totalAttachments': 0,
      'migratedAttachments': 0,
      'errors': <String>[],
    };
    
    try {
      // Get all accounts and mailboxes from Hive
      final hiveStorage = HiveMimeStorage();
      final accounts = await hiveStorage.getAccounts();
      
      for (final account in accounts) {
        final mailboxes = await hiveStorage.getMailboxes(account);
        
        for (final mailbox in mailboxes) {
          // Get messages from Hive
          final hiveMessages = await hiveStorage.getMessages(account, mailbox.path);
          result['totalMessages'] += hiveMessages.length;
          
          // Get messages from SQLite
          final sqliteMessages = await OfflineMimeStorage.instance.getMessages(
            account, 
            mailbox.path,
            limit: 1000000 // Large number to get all messages
          );
          result['migratedMessages'] += sqliteMessages.length;
          
          // Check attachments
          for (final message in hiveMessages) {
            if (message.hasAttachments()) {
              final contentInfo = message.findContentInfo();
              result['totalAttachments'] += contentInfo.length;
              
              // Check if message was migrated
              final messageId = '${account}_${mailbox.path}_${message.uid}';
              final attachments = await OfflineMimeStorage.instance.getAttachments(messageId);
              result['migratedAttachments'] += attachments.length;
              
              if (contentInfo.length != attachments.length) {
                result['errors'].add(
                  'Message ${message.decodeSubject()} has ${contentInfo.length} attachments but only ${attachments.length} were migrated'
                );
              }
            }
          }
        }
      }
      
      // Check for discrepancies
      if (result['totalMessages'] != result['migratedMessages']) {
        result['success'] = false;
        result['errors'].add(
          'Message count mismatch: ${result['totalMessages']} in Hive, ${result['migratedMessages']} in SQLite'
        );
      }
      
      if (result['totalAttachments'] != result['migratedAttachments']) {
        result['success'] = false;
        result['errors'].add(
          'Attachment count mismatch: ${result['totalAttachments']} in Hive, ${result['migratedAttachments']} in SQLite'
        );
      }
      
      return result;
    } catch (e) {
      result['success'] = false;
      result['errors'].add('Validation error: $e');
      return result;
    }
  }
  
  // Performance test method
  Future<Map<String, dynamic>> performanceTest() async {
    final result = {
      'hiveReadTime': 0.0,
      'sqliteReadTime': 0.0,
      'hiveAttachmentTime': 0.0,
      'sqliteAttachmentTime': 0.0,
      'improvement': 0.0,
    };
    
    try {
      // Get a sample account and mailbox
      final hiveStorage = HiveMimeStorage();
      final accounts = await hiveStorage.getAccounts();
      
      if (accounts.isEmpty) {
        return result;
      }
      
      final account = accounts.first;
      final mailboxes = await hiveStorage.getMailboxes(account);
      
      if (mailboxes.isEmpty) {
        return result;
      }
      
      final mailbox = mailboxes.first;
      
      // Test message reading performance
      final stopwatch = Stopwatch()..start();
      
      // Hive read test
      stopwatch.reset();
      await hiveStorage.getMessages(account, mailbox.path);
      result['hiveReadTime'] = stopwatch.elapsedMilliseconds / 1000.0;
      
      // SQLite read test
      stopwatch.reset();
      await OfflineMimeStorage.instance.getMessages(account, mailbox.path);
      result['sqliteReadTime'] = stopwatch.elapsedMilliseconds / 1000.0;
      
      // Test attachment reading performance
      final hiveMessages = await hiveStorage.getMessages(account, mailbox.path);
      
      // Find a message with attachments
      MimeMessage? messageWithAttachments;
      for (final message in hiveMessages) {
        if (message.hasAttachments()) {
          messageWithAttachments = message;
          break;
        }
      }
      
      if (messageWithAttachments != null) {
        // Hive attachment test
        stopwatch.reset();
        final contentInfo = messageWithAttachments.findContentInfo();
        for (final info in contentInfo) {
          final mimePart = messageWithAttachments.getPart(info.fetchId);
          if (mimePart != null) {
            mimePart.decodeContentBinary();
          }
        }
        result['hiveAttachmentTime'] = stopwatch.elapsedMilliseconds / 1000.0;
        
        // SQLite attachment test
        stopwatch.reset();
        final messageId = '${account}_${mailbox.path}_${messageWithAttachments.uid}';
        await OfflineMimeStorage.instance.getAttachments(messageId);
        result['sqliteAttachmentTime'] = stopwatch.elapsedMilliseconds / 1000.0;
      }
      
      // Calculate improvement
      if (result['hiveReadTime'] > 0 && result['sqliteReadTime'] > 0) {
        result['improvement'] = (result['hiveReadTime'] - result['sqliteReadTime']) / result['hiveReadTime'] * 100;
      }
      
      return result;
    } catch (e) {
      print('Performance test error: $e');
      return result;
    }
  }
}
