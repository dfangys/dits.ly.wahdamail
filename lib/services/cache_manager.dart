import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Comprehensive cache manager for email application performance optimization
class CacheManager extends GetxService {
  static CacheManager get instance => Get.find<CacheManager>();

  // Memory caches with LRU eviction
  final LRUMap<String, MimeMessage> _messageCache = LRUMap<String, MimeMessage>(100);
  final LRUMap<String, List<MimeMessage>> _mailboxCache = LRUMap<String, List<MimeMessage>>(20);
  final LRUMap<String, Uint8List> _attachmentCache = LRUMap<String, Uint8List>(50);
  final LRUMap<String, String> _messageContentCache = LRUMap<String, String>(200);
  final LRUMap<String, List<MimePart>> _attachmentListCache = LRUMap<String, List<MimePart>>(100);

  // Cache statistics
  final RxMap<String, int> _cacheStats = <String, int>{
    'message_hits': 0,
    'message_misses': 0,
    'mailbox_hits': 0,
    'mailbox_misses': 0,
    'attachment_hits': 0,
    'attachment_misses': 0,
    'content_hits': 0,
    'content_misses': 0,
  }.obs;

  // Cache configuration
  static const int _maxMessageCacheSize = 100;
  static const int _maxMailboxCacheSize = 20;
  static const int _maxAttachmentCacheSize = 50;
  static const int _maxContentCacheSize = 200;
  static const int _maxAttachmentDataSize = 5 * 1024 * 1024; // 5MB per attachment

  // Preloading queues
  final Queue<String> _preloadQueue = Queue<String>();
  bool _isPreloading = false;

  @override
  Future<void> onInit() async {
    super.onInit();
    _startPeriodicCleanup();
    _startPreloadProcessor();
  }

  // Message caching
  String _getMessageKey(MimeMessage message) {
    return '${message.uid ?? message.sequenceId}';
  }

  void cacheMessage(MimeMessage message) {
    final key = _getMessageKey(message);
    _messageCache[key] = message;
  }

  MimeMessage? getCachedMessage(MimeMessage message) {
    final key = _getMessageKey(message);
    final cached = _messageCache[key];
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
    _mailboxCache[key] = List.from(messages); // Create a copy to avoid reference issues
  }

  List<MimeMessage>? getCachedMailboxMessages(Mailbox mailbox) {
    final key = _getMailboxKey(mailbox);
    final cached = _mailboxCache[key];
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
    final filename = attachment.getHeaderContentDisposition()?.filename ?? 
                    attachment.getHeaderContentType()?.parameters['name'] ?? 
                    'attachment_${attachment.hashCode}';
    return 'attachment_${_getMessageKey(message)}_$filename';
  }

  void cacheAttachmentData(MimeMessage message, MimePart attachment, Uint8List data) {
    if (data.length > _maxAttachmentDataSize) {
      if (kDebugMode) {
        print('Attachment too large to cache: ${data.length} bytes');
      }
      return;
    }
    
    final key = _getAttachmentKey(message, attachment);
    _attachmentCache[key] = data;
  }

  Uint8List? getCachedAttachmentData(MimeMessage message, MimePart attachment) {
    final key = _getAttachmentKey(message, attachment);
    final cached = _attachmentCache[key];
    if (cached != null) {
      _cacheStats['attachment_hits'] = (_cacheStats['attachment_hits'] ?? 0) + 1;
    } else {
      _cacheStats['attachment_misses'] = (_cacheStats['attachment_misses'] ?? 0) + 1;
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
      final messageKey = _preloadQueue.removeFirst();
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
    final keysToRemove = _attachmentCache.keys
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
      print('Cache stats: ${_cacheStats.value}');
      print('Cache sizes: Messages=${_messageCache.length}, '
            'Mailboxes=${_mailboxCache.length}, '
            'Attachments=${_attachmentCache.length}, '
            'Content=${_messageContentCache.length}');
    }
  }

  // Cache statistics
  Map<String, int> get cacheStats => Map.from(_cacheStats.value);
  
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

