import 'dart:io';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wahda_bank/services/cache_manager.dart';
import 'package:wahda_bank/services/memory_budget.dart';
import 'package:wahda_bank/services/feature_flags.dart';
import 'package:wahda_bank/views/settings/pages/performance_flags_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Acceptance: Feature flags UI + Budget enforcement gating', () {
    setUpAll(() async {
      await GetStorage.init();
      await _ensureTestServices();
    });

    testWidgets(
      'Feature flags toggles persist via GetStorage',
      (tester) async {
        // Ensure required services are registered
        await _ensureTestServices();
        // Start with the page
        await tester.pumpWidget(
          const MaterialApp(home: PerformanceFlagsPage()),
        );
        await tester.pumpAndSettle();

        // Bring flags section into view in case it's below the fold
        await tester.scrollUntilVisible(find.text('Feature Flags'), 300);
        await tester.pumpAndSettle();

        // Toggle virtualization tuning
        final virtText = find.text('Virtualization tuning');
        expect(virtText, findsOneWidget);

        final virtBefore = FeatureFlags.instance.virtualizationTuningEnabled;
        await tester.tap(virtText);
        await tester.pumpAndSettle();
        final virtAfter = FeatureFlags.instance.virtualizationTuningEnabled;
        expect(virtAfter, isNot(virtBefore));

        // Toggle fixed extent inbox rows
        final fixedText = find.text('Fixed extent inbox rows');
        expect(fixedText, findsOneWidget);

        final fixedBefore = FeatureFlags.instance.fixedExtentListEnabled;
        await tester.tap(fixedText);
        await tester.pumpAndSettle();
        final fixedAfter = FeatureFlags.instance.fixedExtentListEnabled;
        expect(fixedAfter, isNot(fixedBefore));

        // Rebuild page and confirm state reflects persisted values
        await tester.pumpWidget(
          const MaterialApp(home: PerformanceFlagsPage()),
        );
        await tester.pumpAndSettle();

        // Scroll again to ensure tiles are visible in the new build
        await tester.scrollUntilVisible(find.text('Feature Flags'), 300);
        await tester.pumpAndSettle();

        final virtTile2 = find.text('Virtualization tuning');
        final fixedTile2 = find.text('Fixed extent inbox rows');
        expect(virtTile2, findsOneWidget);
        expect(fixedTile2, findsOneWidget);
        // Validate the underlying storage values reflect toggles
        expect(
          FeatureFlags.instance.virtualizationTuningEnabled,
          equals(virtAfter),
        );
        expect(
          FeatureFlags.instance.fixedExtentListEnabled,
          equals(fixedAfter),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets(
      'Cache budget enforcement evicts to soft max (gated)',
      (tester) async {
        // No file writes needed; we'll override via testing hook.
        final cfgFile = File('perf/perf_config.json');
        final existed = cfgFile.existsSync();
        final original = existed ? await cfgFile.readAsString() : null;
        try {
          // Reset Get to ensure services re-read config
          Get.reset();
          // Re-register required services so the page and tests can resolve them
          await _ensureTestServices();

          // Initialize services
          final budget =
              MemoryBudgetService.instance; // onInit reads perf config
          // Override budgets for testing to avoid file system writes
          budget.overrideForTesting(steadyStateMaxMb: 5, cacheFraction: 0.5);
          final cache = CacheManager.instance;

          // Create a dummy message to key caches consistently
          final msg = MimeMessage();
          msg.uid = 1;
          msg.sequenceId = 1;

          // Fill content cache with large entries to exceed soft max
          final bigChunk = 'A' * 100000; // ~100 KB as UTF-16 estimate
          for (int i = 0; i < 100; i++) {
            final m = MimeMessage();
            m.uid = i + 2;
            m.sequenceId = i + 2;
            cache.cacheMessageContent(m, bigChunk);
          }

          // Sanity: should be over soft max
          final preBytes = cache.estimatedMemoryUsage;
          expect(preBytes > budget.cacheSoftMaxBytes, true);

          // Enforce now and re-sample
          cache.enforceBudgetNow();
          await tester.pump(const Duration(milliseconds: 50));

          final postBytes = cache.estimatedMemoryUsage;
          final softMax = budget.cacheSoftMaxBytes;

          // Gating: after enforcement, cache usage should be at or under soft max (allow tiny wiggle)
          const wiggle = 64 * 1024; // 64 KB tolerance
          expect(
            postBytes <= softMax + wiggle,
            true,
            reason:
                'Cache should be trimmed to soft max. post=$postBytes, softMax=$softMax',
          );
        } finally {
          // Restore original config to avoid side effects on repo
          if (original != null) {
            await cfgFile.writeAsString(original);
          } else {
            if (await cfgFile.exists()) {
              await cfgFile.delete();
            }
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}

Future<void> _ensureTestServices() async {
  if (!Get.isRegistered<MemoryBudgetService>()) {
    Get.put(MemoryBudgetService(), permanent: true);
  }
  if (!Get.isRegistered<CacheManager>()) {
    Get.put(CacheManager(), permanent: true);
  }
}
