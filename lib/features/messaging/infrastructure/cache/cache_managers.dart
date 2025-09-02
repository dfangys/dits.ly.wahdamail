import 'dart:collection';

import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/shared/config/ddd_config.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';
import 'package:wahda_bank/shared/utils/hashing.dart';

typedef ProtectPredicate = Future<bool> Function(String messageUid);

class BodyCacheManager {
  final LocalStore store;
  final int maxTotalBytes;
  final ProtectPredicate isProtected;
  final _lru = LinkedHashMap<String, int>(); // uid -> lastAccess epoch

  BodyCacheManager({
    required this.store,
    int? maxTotalBytes,
    ProtectPredicate? isProtected,
  })  : maxTotalBytes = maxTotalBytes ?? DddConfig.bodiesMaxBytes,
        isProtected = isProtected ?? ((uid) async {
          // Default protection: starred/flagged (and answered)
          try {
            final h = await store.getHeaderById(messageUid: uid);
            return (h?.flagged ?? false) || (h?.answered ?? false);
          } catch (_) {
            return false;
          }
        });

  void touch(String messageUid) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lru.remove(messageUid);
    _lru[messageUid] = now;
  }

  Future<void> enforceCaps() async {
    final sw = Stopwatch()..start();
    // compute total bytes
    int total = 0;
    final sizes = <String, int>{};
    for (final uid in _lru.keys) {
      final b = await store.getBody(messageUid: uid);
      if (b != null) {
        final s = (b.html?.length ?? 0) + (b.plainText?.length ?? 0);
        sizes[uid] = s;
        total += s;
      }
    }
    if (total <= maxTotalBytes) return;

    final entries = _lru.entries.toList();
    // Evict least-recently-used first (excluding protected items)
    entries.sort((a, b) => a.value.compareTo(b.value));
    int bytesOver = total - maxTotalBytes;
    for (final e in entries) {
      if (bytesOver <= 0) break;
      final uid = e.key;
      if (await isProtected(uid)) continue;
      final s = sizes[uid] ?? 0;
      if (s <= 0) continue;
      // Evict by replacing body with empty placeholder
      final body = await store.getBody(messageUid: uid);
      if (body != null) {
        final empty = body.copyWith(html: '', plainText: '');
        await store.upsertBody(empty);
        bytesOver -= s;
        Telemetry.event('cache_evict', props: {
          'cache': 'bodies',
          'key_hash': Hashing.djb2(uid).toString(),
          'size_bytes': s,
          'reason': 'lru_cap',
          'ms': sw.elapsedMilliseconds,
        });
      }
    }
  }
}

class AttachmentCacheManager {
  final LocalStore store;
  final int maxTotalBytes;
  final int maxPerAttachmentBytes;
  final _lru = LinkedHashMap<String, int>(); // key=uid:part -> lastAccess

  AttachmentCacheManager({
    required this.store,
    int? maxTotalBytes,
    int? maxPerAttachmentBytes,
  })  : maxTotalBytes = maxTotalBytes ?? DddConfig.attachmentsMaxBytes,
        maxPerAttachmentBytes = maxPerAttachmentBytes ?? DddConfig.attachmentsMaxItemBytes;

  void touch(String messageUid, String partId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lru.remove('$messageUid:$partId');
    _lru['$messageUid:$partId'] = now;
  }

  Future<bool> canStore(String messageUid, String partId, List<int> bytes) async {
    if (bytes.length > maxPerAttachmentBytes) {
      Telemetry.event('cache_miss', props: {
        'cache': 'attachments',
        'key_hash': Hashing.djb2('$messageUid:$partId').toString(),
        'size_bytes': bytes.length,
        'reason': 'too_large_to_cache',
      });
      return false;
    }
    return true;
  }

  Future<void> enforceCaps() async {
    final sw = Stopwatch()..start();
    // Estimate total bytes by summing blobs present in LRU keys
    int total = 0;
    final sizes = <String, int>{};
    for (final key in _lru.keys) {
      final parts = key.split(':');
      if (parts.length != 2) continue;
      final uid = parts[0], part = parts[1];
      final blob = await store.getAttachmentBlobRef(messageUid: uid, partId: part);
      final s = blob?.length ?? 0;
      sizes[key] = s;
      total += s;
    }
    if (total <= maxTotalBytes) return;

    final entries = _lru.entries.toList();
    entries.sort((a, b) => a.value.compareTo(b.value));
    for (final e in entries) {
      if (total <= maxTotalBytes) break;
      final key = e.key;
      final parts = key.split(':');
      if (parts.length != 2) continue;
      final uid = parts[0], part = parts[1];
      final s = sizes[key] ?? 0;
      // Evict by storing empty
      await store.putAttachmentBlob(messageUid: uid, partId: part, bytes: <int>[]);
      total -= s;
      Telemetry.event('cache_evict', props: {
        'cache': 'attachments',
        'key_hash': Hashing.djb2(key).toString(),
        'size_bytes': s,
        'reason': 'lru_cap',
        'ms': sw.elapsedMilliseconds,
      });
    }
  }
}
