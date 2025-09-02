import 'dart:async';
import 'dart:collection';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/services/memory_budget.dart';

/// Wrapper classes for cached data with expiration support
class CachedMessage {
  final MimeMessage message;
  final DateTime cachedAt;
  final Duration? expiry;

  CachedMessage(this.message, {this.expiry}) : cachedAt = DateTime.now();

  bool get isExpired {
    if (expiry == null) return false;
    return DateTime.now().difference(cachedAt) > expiry!;
  }
}

class CachedMailbox {
  final List<MimeMessage> messages;
  final DateTime cachedAt;
  final Duration? expiry;

  CachedMailbox(this.messages, {this.expiry}) : cachedAt = DateTime.now();

  bool get isExpired {
    if (expiry == null) return false;
    return DateTime.now().difference(cachedAt) > expiry!;
  }
}

class CachedAttachment {
  final Uint8List data;
  final DateTime cachedAt;
  final Duration? expiry;

  CachedAttachment(this.data, {this.expiry}) : cachedAt = DateTime.now();

  bool get isExpired {
    if (expiry == null) return false;
    return DateTime.now().difference(cachedAt) > expiry!;
  }

  int get length => data.length;
}

class CachedContent {
  final String content;
  final DateTime cachedAt;
  final Duration? expiry;

  CachedContent(this.content, {this.expiry}) : cachedAt = DateTime.now();

  bool get isExpired {
    if (expiry == null) return false;
    return DateTime.now().difference(cachedAt) > expiry!;
  }

  int get length => content.length;
}

class CachedThumbnail {
  final Uint8List data;
  final DateTime cachedAt;
  final Duration? expiry;

  CachedThumbnail(this.data, {this.expiry}) : cachedAt = DateTime.now();

  bool get isExpired {
    if (expiry == null) return false;
    return DateTime.now().difference(cachedAt) > expiry!;
  }

  int get length => data.length;
}

/// Enterprise-grade cache manager with intelligent memory management,
/// cache invalidation strategies, and integrated attachment handling.
class CacheManager extends GetxService {
  static CacheManager get instance => Get.find<CacheManager>();

  // Memory caches with LRU eviction and expiration
  final LRUMap<String, CachedMessage> _messageCache =
      LRUMap<String, CachedMessage>(_maxMessageCacheSize);
  final LRUMap<String, CachedMailbox> _mailboxCache =
      LRUMap<String, CachedMailbox>(_maxMailboxCacheSize);
  final LRUMap<String, CachedAttachment> _attachmentCache =
      LRUMap<String, CachedAttachment>(_maxAttachmentCacheSize);

  // Legacy LRU maps for backward compatibility
  final LRUMap<String, MimeMessage> _legacyMessageCache =
      LRUMap<String, MimeMessage>(_maxMessageCacheSize);
  final LRUMap<String, List<MimeMessage>> _legacyMailboxCache =
      LRUMap<String, List<MimeMessage>>(_maxMailboxCacheSize);
  final LRUMap<String, Uint8List> _legacyAttachmentDataCache =
      LRUMap<String, Uint8List>(_maxAttachmentCacheSize);
  final LRUMap<String, String> _messageContentCache = LRUMap<String, String>(
    _maxContentCacheSize,
  );
  final LRUMap<String, List<MimePart>> _attachmentListCache =
      LRUMap<String, List<MimePart>>(_maxAttachmentCacheSize * 2);

  // Cache statistics with additional metrics
  final RxMap<String, int> _cacheStats =
      <String, int>{
        'message_hits': 0,
        'message_misses': 0,
        'mailbox_hits': 0,
        'mailbox_misses': 0,
        'attachment_hits': 0,
        'attachment_misses': 0,
        'content_hits': 0,
        'content_misses': 0,
        'thumbnail_hits': 0,
        'thumbnail_misses': 0,
        'evictions': 0,
        'cache_invalidations': 0,
      }.obs;

  // Enhanced cache configuration
  static const int _maxMessageCacheSize = 150;
  static const int _maxMailboxCacheSize = 25;
  static const int _maxAttachmentCacheSize = 75;
  static const int _maxContentCacheSize = 300;
  static const int _maxAttachmentDataSize =
      10 * 1024 * 1024; // 10MB per attachment

  // Preloading queues
  final Queue<String> _preloadQueue = Queue<String>();
  bool _isPreloading = false;

  @override
  Future<void> onInit() async {
    super.onInit();
    // Ensure memory budget service is initialized
    MemoryBudgetService.instance;
    _startPeriodicCleanup();
    _startPreloadProcessor();
    _startPeriodicEnforceBudget();
  }

  // Message caching
  String _getMessageKey(MimeMessage message) {
    return '${message.uid ?? message.sequenceId}';
  }

  void cacheMessage(MimeMessage message) {
    final key = _getMessageKey(message);
    _legacyMessageCache[key] = message;
  }

  MimeMessage? getCachedMessage(MimeMessage message) {
    final key = _getMessageKey(message);
    final cached = _legacyMessageCache[key];
    if (cached != null) {
      _cacheStats['message_hits'] = (_cacheStats['message_hits'] ?? 0) + 1;
    } else {
      _cacheStats['message_misses'] = (_cacheStats['message_misses'] ?? 0) + 1;
    }
    return cached;
  }

  // Mailbox caching
  String _getMailboxKey(Mailbox mailbox) {
    return '${mailbox.path}_${mailbox.name}';
  }

  void cacheMailboxMessages(Mailbox mailbox, List<MimeMessage> messages) {
    final key = _getMailboxKey(mailbox);
    _legacyMailboxCache[key] = List.from(
      messages,
    ); // Create a copy to avoid reference issues
  }

  List<MimeMessage>? getCachedMailboxMessages(Mailbox mailbox) {
    final key = _getMailboxKey(mailbox);
    final cached = _legacyMailboxCache[key];
    if (cached != null) {
      _cacheStats['mailbox_hits'] = (_cacheStats['mailbox_hits'] ?? 0) + 1;
      return List.from(cached); // Return a copy
    } else {
      _cacheStats['mailbox_misses'] = (_cacheStats['mailbox_misses'] ?? 0) + 1;
      return null;
    }
  }

  // Message content caching
  String _getContentKey(MimeMessage message) {
    return 'content_${_getMessageKey(message)}';
  }

  void cacheMessageContent(MimeMessage message, String content) {
    final key = _getContentKey(message);
    _messageContentCache[key] = content;
  }

  String? getCachedMessageContent(MimeMessage message) {
    final key = _getContentKey(message);
    final cached = _messageContentCache[key];
    if (cached != null) {
      _cacheStats['content_hits'] = (_cacheStats['content_hits'] ?? 0) + 1;
    } else {
      _cacheStats['content_misses'] = (_cacheStats['content_misses'] ?? 0) + 1;
    }
    return cached;
  }

  // Attachment list caching
  String _getAttachmentListKey(MimeMessage message) {
    return 'attachments_${_getMessageKey(message)}';
  }

  void cacheAttachmentList(MimeMessage message, List<MimePart> attachments) {
    final key = _getAttachmentListKey(message);
    _attachmentListCache[key] = List.from(attachments);
  }

  List<MimePart>? getCachedAttachmentList(MimeMessage message) {
    final key = _getAttachmentListKey(message);
    return _attachmentListCache[key];
  }

  // Attachment data caching
  String _getAttachmentKey(MimeMessage message, MimePart attachment) {
    final filename =
        attachment.getHeaderContentDisposition()?.filename ??
        attachment.getHeaderContentType()?.parameters['name'] ??
        'attachment_${attachment.hashCode}';
    return 'attachment_${_getMessageKey(message)}_$filename';
  }

  void cacheAttachmentData(
    MimeMessage message,
    MimePart attachment,
    Uint8List data,
  ) {
    if (data.length > _maxAttachmentDataSize) {
      if (kDebugMode) {
        print('Attachment too large to cache: ${data.length} bytes');
      }
      return;
    }

    final key = _getAttachmentKey(message, attachment);
    _legacyAttachmentDataCache[key] = data;
  }

  Uint8List? getCachedAttachmentData(MimeMessage message, MimePart attachment) {
    final key = _getAttachmentKey(message, attachment);
    final cached = _legacyAttachmentDataCache[key];
    if (cached != null) {
      _cacheStats['attachment_hits'] =
          (_cacheStats['attachment_hits'] ?? 0) + 1;
    } else {
      _cacheStats['attachment_misses'] =
          (_cacheStats['attachment_misses'] ?? 0) + 1;
    }
    return cached;
  }

  // Preloading functionality
  void schedulePreload(String messageKey) {
    if (!_preloadQueue.contains(messageKey)) {
      _preloadQueue.add(messageKey);
    }
  }

  void _startPreloadProcessor() {
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isPreloading && _preloadQueue.isNotEmpty) {
        _processPreloadQueue();
      }
    });
  }

  Future<void> _processPreloadQueue() async {
    if (_isPreloading || _preloadQueue.isEmpty) return;

    _isPreloading = true;
    try {
      _preloadQueue.removeFirst();
      // Implement preloading logic here
      // This would typically involve fetching message content in background
      await Future.delayed(const Duration(milliseconds: 100)); // Placeholder
    } catch (e) {
      if (kDebugMode) {
        print('Preload error: $e');
      }
    } finally {
      _isPreloading = false;
    }
  }

  // Cache management
  void clearCache() {
    _messageCache.clear();
    _mailboxCache.clear();
    _attachmentCache.clear();
    _messageContentCache.clear();
    _attachmentListCache.clear();
    _resetStats();
  }

  void clearMailboxCache(Mailbox mailbox) {
    final key = _getMailboxKey(mailbox);
    _mailboxCache.remove(key);
  }

  void clearMessageCache(MimeMessage message) {
    final messageKey = _getMessageKey(message);
    _messageCache.remove(messageKey);
    _messageContentCache.remove(_getContentKey(message));
    _attachmentListCache.remove(_getAttachmentListKey(message));

    // Remove attachment data for this message
    final keysToRemove =
        _attachmentCache.keys
            .where((key) => key.startsWith('attachment_$messageKey'))
            .toList();
    for (final key in keysToRemove) {
      _attachmentCache.remove(key);
    }
  }

  void _resetStats() {
    _cacheStats.clear();
    _cacheStats.addAll({
      'message_hits': 0,
      'message_misses': 0,
      'mailbox_hits': 0,
      'mailbox_misses': 0,
      'attachment_hits': 0,
      'attachment_misses': 0,
      'content_hits': 0,
      'content_misses': 0,
    });
  }

  // Periodic cleanup
  void _startPeriodicCleanup() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      _performCleanup();
    });
  }

  void _performCleanup() {
    // Cleanup is automatically handled by LRUMap
    // But we can add additional logic here if needed

    if (kDebugMode) {
      print('Cache cleanup performed');
      print('Cache stats: ${Map.from(_cacheStats)}');
      print(
        'Cache sizes: Messages=${_messageCache.length}, '
        'Mailboxes=${_mailboxCache.length}, '
        'Attachments=${_attachmentCache.length}, '
        'Content=${_messageContentCache.length}',
      );
    }
  }

  // Budget enforcement
  void _startPeriodicEnforceBudget() {
    Timer.periodic(const Duration(minutes: 2), (timer) {
      try {
        _enforceMemoryBudget();
      } catch (e) {
        if (kDebugMode) {
          print('Memory budget enforce error: $e');
        }
      }
    });
  }

  void _enforceMemoryBudget() {
    final budget = MemoryBudgetService.instance;
    final rss = budget.sampleProcessRssBytes();
    final cacheBytes = estimatedMemoryUsage;
    final softMax = budget.cacheSoftMaxBytes;

    if (cacheBytes <= softMax) {
      return;
    }

    int toFree = cacheBytes - softMax;

    // Prefer to free from the largest buckets first: attachments, content
    toFree -= _evictAttachmentBytes(toFree);
    if (toFree > 0) {
      toFree -= _evictContentBytes(toFree);
    }
    if (toFree > 0) {
      // Then reduce message/mailbox cache sizes by count
      _evictCountFromMap(_messageCache, (_messageCache.length / 3).ceil());
      _evictCountFromMap(_mailboxCache, (_mailboxCache.length / 2).ceil());
    }

    if (kDebugMode) {
      print(
        'Memory budget enforced. RSS=${(rss / (1024 * 1024)).toStringAsFixed(1)}MB, '
        'cache=${(cacheBytes / (1024 * 1024)).toStringAsFixed(1)}MB -> '
        '${(estimatedMemoryUsage / (1024 * 1024)).toStringAsFixed(1)}MB',
      );
    }
  }

  int _evictAttachmentBytes(int bytesToFree) {
    int freed = 0;
    // LRU: keys.first is least recently used
    final keys = List<String>.from(_attachmentCache.keys);
    for (final k in keys) {
      if (freed >= bytesToFree) break;
      final data = _attachmentCache[k];
      if (data != null) {
        freed += data.length;
      }
      _attachmentCache.remove(k);
    }
    return freed;
  }

  int _evictContentBytes(int bytesToFree) {
    int freed = 0;
    final keys = List<String>.from(_messageContentCache.keys);
    for (final k in keys) {
      if (freed >= bytesToFree) break;
      final content = _messageContentCache[k];
      if (content != null) {
        freed += content.length * 2; // UTF-16 estimate
      }
      _messageContentCache.remove(k);
    }
    return freed;
  }

  void _evictCountFromMap<K, V>(LRUMap<K, V> map, int count) {
    for (int i = 0; i < count && map.length > 0; i++) {
      final firstKey = map.keys.isNotEmpty ? map.keys.first : null;
      if (firstKey == null) break;
      map.remove(firstKey);
    }
  }

  // Cache statistics
  Map<String, int> get cacheStats => Map.from(_cacheStats);

  // Expose cache sizes for monitoring
  int get messageCacheCount => _messageCache.length;
  int get mailboxCacheCount => _mailboxCache.length;
  int get attachmentCacheCount => _attachmentCache.length;
  int get contentCacheCount => _messageContentCache.length;
  int get attachmentListCacheCount => _attachmentListCache.length;

  int get attachmentCacheBytes {
    int total = 0;
    for (final data in _attachmentCache.values) {
      total += data.length;
    }
    return total;
  }

  int get contentCacheBytes {
    int total = 0;
    for (final content in _messageContentCache.values) {
      total += content.length * 2; // UTF-16 estimate
    }
    return total;
  }

  // Public trigger for budget enforcement
  void enforceBudgetNow() => _enforceMemoryBudget();

  double get messageHitRate {
    final hits = _cacheStats['message_hits'] ?? 0;
    final misses = _cacheStats['message_misses'] ?? 0;
    final total = hits + misses;
    return total > 0 ? hits / total : 0.0;
  }

  double get mailboxHitRate {
    final hits = _cacheStats['mailbox_hits'] ?? 0;
    final misses = _cacheStats['mailbox_misses'] ?? 0;
    final total = hits + misses;
    return total > 0 ? hits / total : 0.0;
  }

  double get attachmentHitRate {
    final hits = _cacheStats['attachment_hits'] ?? 0;
    final misses = _cacheStats['attachment_misses'] ?? 0;
    final total = hits + misses;
    return total > 0 ? hits / total : 0.0;
  }

  double get contentHitRate {
    final hits = _cacheStats['content_hits'] ?? 0;
    final misses = _cacheStats['content_misses'] ?? 0;
    final total = hits + misses;
    return total > 0 ? hits / total : 0.0;
  }

  // Memory usage estimation
  int get estimatedMemoryUsage {
    int total = 0;

    // Estimate message cache size
    total += _messageCache.length * 1024; // Rough estimate per message

    // Estimate mailbox cache size
    total += _mailboxCache.length * 10 * 1024; // Rough estimate per mailbox

    // Estimate attachment cache size
    for (final data in _attachmentCache.values) {
      total += data.length;
    }

    // Estimate content cache size
    for (final content in _messageContentCache.values) {
      total += content.length * 2; // UTF-16 encoding
    }

    return total;
  }

  String get formattedMemoryUsage {
    final bytes = estimatedMemoryUsage;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// LRU (Least Recently Used) Map implementation
class LRUMap<K, V> {
  final int _maxSize;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  LRUMap(this._maxSize);

  V? operator [](K key) {
    final value = _map.remove(key);
    if (value != null) {
      _map[key] = value; // Move to end (most recently used)
    }
    return value;
  }

  void operator []=(K key, V value) {
    if (_map.containsKey(key)) {
      _map.remove(key);
    } else if (_map.length >= _maxSize) {
      _map.remove(_map.keys.first); // Remove least recently used
    }
    _map[key] = value;
  }

  V? remove(K key) => _map.remove(key);

  bool containsKey(K key) => _map.containsKey(key);

  void clear() => _map.clear();

  int get length => _map.length;

  Iterable<K> get keys => _map.keys;

  Iterable<V> get values => _map.values;
}
