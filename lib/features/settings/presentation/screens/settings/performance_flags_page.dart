import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/api/mailbox_controller_api.dart';
import 'package:wahda_bank/services/cache_manager.dart';
import 'package:wahda_bank/services/memory_budget.dart';
import 'package:wahda_bank/services/feature_flags.dart';

class PerformanceFlagsPage extends StatefulWidget {
  const PerformanceFlagsPage({super.key});

  @override
  State<PerformanceFlagsPage> createState() => _PerformanceFlagsPageState();
}

class _PerformanceFlagsPageState extends State<PerformanceFlagsPage> {
  late final CacheManager _cache;
  late final MemoryBudgetService _budget;
  late Timer _timer;

  // Monitoring values
  int _rssBytes = 0;
  int _cacheBytes = 0;

  // Flags local state
  late bool _perTileNotifiers;
  late bool _virtTuning;
  late bool _previewWorker;
  late bool _animationsCapped;
  late bool _fixedExtentList;

  // Mail sync flags
  late bool _foregroundPolling;
  late int _pollingIntervalSecs;
  late bool _attachmentPrefetch;

  @override
  void initState() {
    super.initState();
    _cache = CacheManager.instance;
    _budget = MemoryBudgetService.instance;

    final ff = FeatureFlags.instance;
    _perTileNotifiers = ff.perTileNotifiersEnabled;
    _virtTuning = ff.virtualizationTuningEnabled;
    _previewWorker = ff.previewWorkerEnabled;
    _animationsCapped = ff.animationsCappedEnabled;
    _fixedExtentList = ff.fixedExtentListEnabled;
    _foregroundPolling = ff.foregroundPollingEnabled;
    _pollingIntervalSecs = ff.foregroundPollingIntervalSecs;
    _attachmentPrefetch = ff.attachmentPrefetchEnabled;

    _sample();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _sample());
  }

  void _sample() {
    setState(() {
      _rssBytes = _budget.sampleProcessRssBytes();
      _cacheBytes = _cache.estimatedMemoryUsage;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final softMax = _budget.cacheSoftMaxBytes;

    return Scaffold(
      appBar: AppBar(title: const Text('Performance & Feature Flags')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader(theme, Icons.monitor_heart, 'Monitoring'),
          const SizedBox(height: 8),
          _metricCard(
            theme,
            title: 'Process RSS',
            value: _fmtBytes(_rssBytes),
            subtitle: 'Resident set size of current process',
          ),
          const SizedBox(height: 8),
          _metricCard(
            theme,
            title: 'Cache Usage',
            value: _fmtBytes(_cacheBytes),
            subtitle: 'Estimated cache memory usage',
            trailing: Text(
              'Soft max: ${_fmtBytes(softMax)}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          _cacheBreakdown(theme),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _cache.clearCache()),
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear caches'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _cache.enforceBudgetNow();
                    _sample();
                  },
                  icon: const Icon(Icons.safety_check),
                  label: const Text('Enforce budget now'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _sectionHeader(theme, Icons.flag, 'Feature Flags'),
          const SizedBox(height: 8),
          _flagSwitch(
            theme,
            title: 'Virtualization tuning',
            subtitle: 'Adjusts cacheExtent/prototype for smoother lists',
            value: _virtTuning,
            onChanged: (v) async {
              await FeatureFlags.instance.setVirtualizationTuning(v);
              setState(() => _virtTuning = v);
            },
          ),
          _flagSwitch(
            theme,
            title: 'Fixed extent inbox rows',
            subtitle: 'Use itemExtent for faster layout when feasible',
            value: _fixedExtentList,
            onChanged: (v) async {
              await FeatureFlags.instance.setFixedExtentList(v);
              setState(() => _fixedExtentList = v);
            },
          ),
          _flagSwitch(
            theme,
            title: 'Per-tile notifiers',
            subtitle: 'Granular updates for preview/attachments',
            value: _perTileNotifiers,
            onChanged: (v) async {
              await FeatureFlags.instance.setPerTileNotifiers(v);
              setState(() => _perTileNotifiers = v);
            },
          ),
          _flagSwitch(
            theme,
            title: 'Preview worker',
            subtitle: 'Offload preview normalization to background',
            value: _previewWorker,
            onChanged: (v) async {
              await FeatureFlags.instance.setPreviewWorker(v);
              setState(() => _previewWorker = v);
            },
          ),
          _flagSwitch(
            theme,
            title: 'Cap UI animations',
            subtitle: 'Shorter animation durations for responsiveness',
            value: _animationsCapped,
            onChanged: (v) async {
              await FeatureFlags.instance.setAnimationsCapped(v);
              setState(() => _animationsCapped = v);
            },
          ),

          const SizedBox(height: 24),
          _sectionHeader(theme, Icons.sync, 'Mail sync'),
          const SizedBox(height: 8),
          _flagSwitch(
            theme,
            title: 'Foreground polling',
            subtitle: 'Quietly checks for new mail and prefetches content',
            value: _foregroundPolling,
            onChanged: (v) async {
              await FeatureFlags.instance.setForegroundPollingEnabled(v);
              setState(() => _foregroundPolling = v);
              _applyPollingSettingsNow();
            },
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: const Text('Polling interval'),
              subtitle: const Text('How frequently to check for updates'),
              trailing: DropdownButton<int>(
                value: _pollingIntervalSecs,
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30s')),
                  DropdownMenuItem(value: 60, child: Text('60s')),
                  DropdownMenuItem(value: 90, child: Text('90s')),
                  DropdownMenuItem(value: 120, child: Text('2 min')),
                  DropdownMenuItem(value: 300, child: Text('5 min')),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  await FeatureFlags.instance.setForegroundPollingIntervalSecs(
                    v,
                  );
                  setState(() => _pollingIntervalSecs = v);
                  _applyPollingSettingsNow();
                },
              ),
            ),
          ),
          _flagSwitch(
            theme,
            title: 'Attachment prefetch',
            subtitle: 'Preload small attachments (<512KB) for recent messages',
            value: _attachmentPrefetch,
            onChanged: (v) async {
              await FeatureFlags.instance.setAttachmentPrefetchEnabled(v);
              setState(() => _attachmentPrefetch = v);
            },
          ),

          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _resetFlags,
              icon: const Icon(Icons.restore),
              label: const Text('Reset to defaults'),
            ),
          ),
        ],
      ),
    );
  }

  void _resetFlags() async {
    // Defaults are mostly true except fixed extent list defaulting to false
    await FeatureFlags.instance.setPerTileNotifiers(true);
    await FeatureFlags.instance.setVirtualizationTuning(true);
    await FeatureFlags.instance.setPreviewWorker(true);
    await FeatureFlags.instance.setAnimationsCapped(true);
    await FeatureFlags.instance.setFixedExtentList(false);

    // Mail sync defaults
    await FeatureFlags.instance.setForegroundPollingEnabled(true);
    await FeatureFlags.instance.setForegroundPollingIntervalSecs(90);
    await FeatureFlags.instance.setAttachmentPrefetchEnabled(false);

    setState(() {
      final ff = FeatureFlags.instance;
      _perTileNotifiers = ff.perTileNotifiersEnabled;
      _virtTuning = ff.virtualizationTuningEnabled;
      _previewWorker = ff.previewWorkerEnabled;
      _animationsCapped = ff.animationsCappedEnabled;
      _fixedExtentList = ff.fixedExtentListEnabled;
      _foregroundPolling = ff.foregroundPollingEnabled;
      _pollingIntervalSecs = ff.foregroundPollingIntervalSecs;
      _attachmentPrefetch = ff.attachmentPrefetchEnabled;
    });
    _applyPollingSettingsNow();
  }

  void _applyPollingSettingsNow() {
    if (Get.isRegistered<MailBoxController>()) {
      try {
        Get.find<MailBoxController>().restartForegroundPolling();
      } catch (_) {}
    }
  }

  Widget _cacheBreakdown(ThemeData theme) {
    final items = [
      _CacheItem('Messages', _cache.messageCacheCount, null),
      _CacheItem('Mailboxes', _cache.mailboxCacheCount, null),
      _CacheItem(
        'Attachments',
        _cache.attachmentCacheCount,
        _fmtBytes(_cache.attachmentCacheBytes),
      ),
      _CacheItem(
        'Message content',
        _cache.contentCacheCount,
        _fmtBytes(_cache.contentCacheBytes),
      ),
      _CacheItem('Attachment lists', _cache.attachmentListCacheCount, null),
    ];
    final stats = _cache.cacheStats;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cache breakdown', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...items.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(e.name)),
                    Text('count: ${e.count}'),
                    if (e.bytesLabel != null) ...[
                      const SizedBox(width: 12),
                      Text(e.bytesLabel!),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 24),
            Text('Hit rates', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _hitRow(
              theme,
              'Message',
              _cache.messageHitRate,
              stats['message_hits'],
              stats['message_misses'],
            ),
            _hitRow(
              theme,
              'Mailbox',
              _cache.mailboxHitRate,
              stats['mailbox_hits'],
              stats['mailbox_misses'],
            ),
            _hitRow(
              theme,
              'Attachment',
              _cache.attachmentHitRate,
              stats['attachment_hits'],
              stats['attachment_misses'],
            ),
            _hitRow(
              theme,
              'Content',
              _cache.contentHitRate,
              stats['content_hits'],
              stats['content_misses'],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hitRow(
    ThemeData theme,
    String name,
    double rate,
    int? hits,
    int? misses,
  ) {
    final pct = (rate * 100).toStringAsFixed(1);
    final h = hits ?? 0;
    final m = misses ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(name)),
          Text('$pct%'),
          const SizedBox(width: 12),
          Text('($h / ${h + m})', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _flagSwitch(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _metricCard(
    ThemeData theme, {
    required String title,
    required String value,
    String? subtitle,
    Widget? trailing,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _CacheItem {
  final String name;
  final int count;
  final String? bytesLabel;
  _CacheItem(this.name, this.count, this.bytesLabel);
}
