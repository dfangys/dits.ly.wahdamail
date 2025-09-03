import 'dart:collection';

import 'package:wahda_bank/features/rendering/domain/services/message_rendering_service.dart';

/// Tiny LRU cache for RenderedContent and text previews.
/// Max entries: 100. Eviction policy: least recently used.
import 'package:wahda_bank/shared/logging/telemetry.dart';
import 'package:wahda_bank/shared/config/ddd_config.dart';
import 'package:wahda_bank/shared/utils/hashing.dart';

class PreviewCache {
  final int capacity;
  final _map = LinkedHashMap<String, RenderedContent>();

  int hits = 0;
  int misses = 0;
  int evicts = 0;

  PreviewCache({int? capacity}) : capacity = capacity ?? DddConfig.previewMaxItems;

  RenderedContent? get(String key) {
    final sw = Stopwatch()..start();
    final v = _map.remove(key);
    if (v != null) {
      hits++;
      _map[key] = v; // re-insert to update recency
      final size = (v.sanitizedHtml.length) + (v.plainText?.length ?? 0);
      Telemetry.event('cache_hit', props: {
        'cache': 'preview',
        'key_hash': Hashing.djb2(key).toString(),
        'size_bytes': size,
        'ms': sw.elapsedMilliseconds,
      });
    } else {
      misses++;
      Telemetry.event('cache_miss', props: {
        'cache': 'preview',
        'key_hash': Hashing.djb2(key).toString(),
        'ms': sw.elapsedMilliseconds,
      });
    }
    return v;
  }

  void put(String key, RenderedContent value) {
    // Size computed on hit/evict events; not needed on put
    if (_map.containsKey(key)) {
      _map.remove(key);
    } else if (_map.length >= capacity && _map.isNotEmpty) {
      // evict oldest
      final evictedKey = _map.keys.first;
      final evicted = _map.remove(evictedKey);
      evicts++;
      Telemetry.event('cache_evict', props: {
        'cache': 'preview',
        'key_hash': Hashing.djb2(evictedKey).toString(),
        'size_bytes': evicted != null ? (evicted.sanitizedHtml.length + (evicted.plainText?.length ?? 0)) : 0,
        'reason': 'lru_cap',
      });
    }
    _map[key] = value;
    // no event for put; relies on miss/hit/evict
  }

  int get length => _map.length;
}
