class CacheServiceImpl<K, V> {
  final Map<K, V> _mem = <K, V>{};
  V? get(K k) => _mem[k];
  void put(K k, V v) => _mem[k] = v;
  void remove(K k) => _mem.remove(k);
}
