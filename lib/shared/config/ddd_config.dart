class DddConfig {
  DddConfig._();

  // Defaults (MB)
  static const int _bodiesMaxMbDefault = 200;
  static const int _attachmentsMaxMbDefault = 400;
  static const int _attachmentsMaxItemMbDefault = 100;
  static const int _previewMaxItemsDefault = 100;

  // Keys (documented; not dynamically read here)
  static const String kBodiesMaxMb = 'ddd.cache.bodies.max_mb';
  static const String kAttachmentsMaxMb = 'ddd.cache.attachments.max_mb';
  static const String kAttachmentsMaxItemMb =
      'ddd.cache.attachments.max_item_mb';
  static const String kPreviewMaxItems = 'ddd.cache.preview.max_items';

  // Return constants for P11 scope (flags OFF; values fixed)
  static int get bodiesMaxBytes => _bodiesMaxMbDefault * 1024 * 1024;
  static int get attachmentsMaxBytes => _attachmentsMaxMbDefault * 1024 * 1024;
  static int get attachmentsMaxItemBytes =>
      _attachmentsMaxItemMbDefault * 1024 * 1024;
  static int get previewMaxItems => _previewMaxItemsDefault;
}
