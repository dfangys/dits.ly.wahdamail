import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enough_mail/enough_mail.dart';

/// Email cache service for performance optimization
class EmailCacheService {
  static EmailCacheService? _instance;
  static EmailCacheService get instance => _instance ??= EmailCacheService._();
  
  EmailCacheService._();

  static const String _cachePrefix = 'email_cache_';
  static const String _metadataPrefix = 'email_metadata_';
  static const int _maxCacheAge = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
  static const int _maxCacheSize = 100; // Maximum number of cached emails

  SharedPreferences? _prefs;

  /// Initialize the cache service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _cleanupExpiredCache();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing email cache: $e');
      }
    }
  }

  /// Cache email content for faster loading
  Future<void> cacheEmail(MimeMessage message) async {
    try {
      if (_prefs == null || message.uid == null) return;

      final cacheKey = '$_cachePrefix${message.uid}';
      final metadataKey = '$_metadataPrefix${message.uid}';

      // Create cache entry
      final cacheEntry = {
        'uid': message.uid,
        'subject': message.decodeSubject(),
        'from': _serializeAddresses(message.from),
        'to': _serializeAddresses(message.to),
        'cc': _serializeAddresses(message.cc),
        'bcc': _serializeAddresses(message.bcc),
        'date': message.decodeDate()?.millisecondsSinceEpoch,
        'hasAttachments': message.hasAttachments(),
        'isAnswered': message.isAnswered,
        'isForwarded': message.isForwarded,
        'isFlagged': message.isFlagged,
        'isSeen': message.isSeen,
        'plainText': message.decodeTextPlainPart(),
        'htmlText': message.decodeTextHtmlPart(),
        'attachments': _serializeAttachments(message),
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };

      // Store cache entry
      await _prefs!.setString(cacheKey, jsonEncode(cacheEntry));

      // Store metadata for cache management
      final metadata = {
        'uid': message.uid,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
        'size': jsonEncode(cacheEntry).length,
      };
      await _prefs!.setString(metadataKey, jsonEncode(metadata));

      // Cleanup old cache if needed
      await _cleanupOldCache();

      if (kDebugMode) {
        print('Cached email UID ${message.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error caching email: $e');
      }
    }
  }

  /// Retrieve cached email content
  Future<MimeMessage?> getCachedEmail(int uid) async {
    try {
      if (_prefs == null) return null;

      final cacheKey = '$_cachePrefix$uid';
      final cachedData = _prefs!.getString(cacheKey);
      
      if (cachedData == null) return null;

      final cacheEntry = jsonDecode(cachedData) as Map<String, dynamic>;
      final cachedAt = cacheEntry['cachedAt'] as int?;
      
      // Check if cache is expired
      if (cachedAt == null || 
          DateTime.now().millisecondsSinceEpoch - cachedAt > _maxCacheAge) {
        await _removeCachedEmail(uid);
        return null;
      }

      // Reconstruct MimeMessage from cache
      final message = MimeMessage();
      message.uid = cacheEntry['uid'] as int?;
      
      // Set basic properties with proper encoding for decoding
      if (cacheEntry['subject'] != null) {
        final subject = cacheEntry['subject'] as String;
        message.setHeader('subject', subject);
      }
      
      if (cacheEntry['from'] != null) {
        message.from = _deserializeAddresses(cacheEntry['from'] as List);
      }
      
      if (cacheEntry['to'] != null) {
        message.to = _deserializeAddresses(cacheEntry['to'] as List);
      }
      
      if (cacheEntry['cc'] != null) {
        message.cc = _deserializeAddresses(cacheEntry['cc'] as List);
      }
      
      if (cacheEntry['bcc'] != null) {
        message.bcc = _deserializeAddresses(cacheEntry['bcc'] as List);
      }
      
      if (cacheEntry['date'] != null) {
        final dateMs = cacheEntry['date'] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(dateMs);
        message.setHeader('date', date.toUtc().toString());
      }

      // Set flags
      if (cacheEntry['isAnswered'] == true) {
        message.flags = [...(message.flags ?? []), MessageFlags.answered];
      }
      if (cacheEntry['isForwarded'] == true) {
        // Note: MessageFlags.forwarded might not exist in this version
        // Using a custom flag or skipping this for now
        if (kDebugMode) {
          print('Message was forwarded (flag not set due to API limitation)');
        }
      }
      if (cacheEntry['isFlagged'] == true) {
        message.flags = [...(message.flags ?? []), MessageFlags.flagged];
      }
      if (cacheEntry['isSeen'] == true) {
        message.flags = [...(message.flags ?? []), MessageFlags.seen];
      }

      // Set content from cache
      if (cacheEntry['plainText'] != null || cacheEntry['htmlText'] != null) {
        // Create a simple MIME structure for the content
        final plainText = cacheEntry['plainText'] as String?;
        final htmlText = cacheEntry['htmlText'] as String?;
        
        if (htmlText != null && htmlText.isNotEmpty) {
          // Create HTML part
          final htmlPart = MimePart();
          htmlPart.setHeader('content-type', 'text/html; charset=utf-8');
          htmlPart.mimeData = TextMimeData(htmlText, containsHeader: false);
          message.addPart(htmlPart);
        } else if (plainText != null && plainText.isNotEmpty) {
          // Create plain text part
          final textPart = MimePart();
          textPart.setHeader('content-type', 'text/plain; charset=utf-8');
          textPart.mimeData = TextMimeData(plainText, containsHeader: false);
          message.addPart(textPart);
        }
      }
      
      if (kDebugMode) {
        print('Retrieved cached email UID $uid with content reconstruction');
      }

      return message;
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving cached email: $e');
      }
      return null;
    }
  }

  /// Check if email is cached and not expired
  Future<bool> isEmailCached(int uid) async {
    try {
      if (_prefs == null) return false;

      final metadataKey = '$_metadataPrefix$uid';
      final metadataData = _prefs!.getString(metadataKey);
      
      if (metadataData == null) return false;

      final metadata = jsonDecode(metadataData) as Map<String, dynamic>;
      final cachedAt = metadata['cachedAt'] as int?;
      
      if (cachedAt == null) return false;

      // Check if cache is expired
      return DateTime.now().millisecondsSinceEpoch - cachedAt <= _maxCacheAge;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking cache status: $e');
      }
      return false;
    }
  }

  /// Remove cached email
  Future<void> _removeCachedEmail(int uid) async {
    try {
      if (_prefs == null) return;

      final cacheKey = '$_cachePrefix$uid';
      final metadataKey = '$_metadataPrefix$uid';
      
      await _prefs!.remove(cacheKey);
      await _prefs!.remove(metadataKey);
    } catch (e) {
      if (kDebugMode) {
        print('Error removing cached email: $e');
      }
    }
  }

  /// Clean up expired cache entries
  Future<void> _cleanupExpiredCache() async {
    try {
      if (_prefs == null) return;

      final keys = _prefs!.getKeys();
      final metadataKeys = keys.where((key) => key.startsWith(_metadataPrefix));
      
      for (final metadataKey in metadataKeys) {
        final metadataData = _prefs!.getString(metadataKey);
        if (metadataData == null) continue;

        final metadata = jsonDecode(metadataData) as Map<String, dynamic>;
        final cachedAt = metadata['cachedAt'] as int?;
        final uid = metadata['uid'] as int?;
        
        if (cachedAt == null || uid == null) continue;

        // Remove expired entries
        if (DateTime.now().millisecondsSinceEpoch - cachedAt > _maxCacheAge) {
          await _removeCachedEmail(uid);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up expired cache: $e');
      }
    }
  }

  /// Clean up old cache entries to maintain size limit
  Future<void> _cleanupOldCache() async {
    try {
      if (_prefs == null) return;

      final keys = _prefs!.getKeys();
      final metadataKeys = keys.where((key) => key.startsWith(_metadataPrefix)).toList();
      
      if (metadataKeys.length <= _maxCacheSize) return;

      // Sort by cache time (oldest first)
      final metadataEntries = <Map<String, dynamic>>[];
      for (final key in metadataKeys) {
        final data = _prefs!.getString(key);
        if (data != null) {
          final metadata = jsonDecode(data) as Map<String, dynamic>;
          metadata['key'] = key;
          metadataEntries.add(metadata);
        }
      }

      metadataEntries.sort((a, b) => (a['cachedAt'] as int).compareTo(b['cachedAt'] as int));

      // Remove oldest entries
      final entriesToRemove = metadataEntries.length - _maxCacheSize;
      for (int i = 0; i < entriesToRemove; i++) {
        final uid = metadataEntries[i]['uid'] as int?;
        if (uid != null) {
          await _removeCachedEmail(uid);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up old cache: $e');
      }
    }
  }

  /// Clear all cached emails
  Future<void> clearCache() async {
    try {
      if (_prefs == null) return;

      final keys = _prefs!.getKeys();
      final cacheKeys = keys.where((key) => 
        key.startsWith(_cachePrefix) || key.startsWith(_metadataPrefix));
      
      for (final key in cacheKeys) {
        await _prefs!.remove(key);
      }

      if (kDebugMode) {
        print('Cleared all email cache');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing cache: $e');
      }
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      if (_prefs == null) return {};

      final keys = _prefs!.getKeys();
      final metadataKeys = keys.where((key) => key.startsWith(_metadataPrefix));
      
      int totalSize = 0;
      int expiredCount = 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      for (final key in metadataKeys) {
        final data = _prefs!.getString(key);
        if (data != null) {
          final metadata = jsonDecode(data) as Map<String, dynamic>;
          totalSize += (metadata['size'] as int? ?? 0);
          
          final cachedAt = metadata['cachedAt'] as int?;
          if (cachedAt != null && now - cachedAt > _maxCacheAge) {
            expiredCount++;
          }
        }
      }

      return {
        'totalEntries': metadataKeys.length,
        'totalSize': totalSize,
        'expiredEntries': expiredCount,
        'maxCacheSize': _maxCacheSize,
        'maxCacheAge': _maxCacheAge,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting cache stats: $e');
      }
      return {};
    }
  }

  List<Map<String, dynamic>> _serializeAddresses(List<MailAddress>? addresses) {
    if (addresses == null) return [];
    return addresses.map((addr) => {
      'email': addr.email,
      'personalName': addr.personalName,
    }).toList();
  }

  List<MailAddress> _deserializeAddresses(List<dynamic> addressData) {
    return addressData.map((data) => MailAddress(
      data['personalName'] as String?,
      data['email'] as String,
    )).toList();
  }

  List<Map<String, dynamic>> _serializeAttachments(MimeMessage message) {
    try {
      final contentInfo = message.findContentInfo();
      return contentInfo.map((info) => {
        'fileName': info.fileName,
        'size': info.size,
        'mimeType': info.contentType?.mediaType?.toString(),
        'isInline': false, // Simplified for now
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error serializing attachments: $e');
      }
      return [];
    }
  }
}

