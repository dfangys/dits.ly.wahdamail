import 'dart:collection';

import 'package:wahda_bank/features/rendering/domain/services/message_rendering_service.dart';

/// Tiny LRU cache for RenderedContent and text previews.
/// Max entries: 100. Eviction policy: least recently used.
class PreviewCache {
  final int capacity;
  final _map = LinkedHashMap<String, RenderedContent>();

  PreviewCache({this.capacity = 100});

  RenderedContent? get(String key) {
    final v = _map.remove(key);
    if (v != null) {
      _map[key] = v; // re-insert to update recency
    }
    return v;
  }

  void put(String key, RenderedContent value) {
    if (_map.containsKey(key)) {
      _map.remove(key);
    } else if (_map.length >= capacity && _map.isNotEmpty) {
      // evict oldest
      _map.remove(_map.keys.first);
    }
    _map[key] = value;
  }

  int get length => _map.length;
}
