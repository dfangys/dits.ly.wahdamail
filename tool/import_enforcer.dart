import 'dart:io';

final domainBans = [
  'package:flutter/',
  'dart:ui',
  'package:enough_mail',
  'package:enough_mail_flutter',
];
final applicationBans = ['package:enough_mail', 'package:enough_mail_flutter'];
final infraPath = RegExp(r'lib/features/.+/infrastructure/');
final presentationPath = RegExp(r'lib/features/.+/presentation/');
final viewsPath = RegExp(r'lib/views/');
final domainPath = RegExp(r'lib/features/.+/domain/');
final applicationPath = RegExp(r'lib/features/.+/application/');
final dsThemePath = RegExp(r'lib/design_system/theme/');

// Soft warnings (do not fail)
final softWarnings = <String>[];

// Tracks newly added files in current working tree diff vs HEAD
Map<String, bool> _newFiles = <String, bool>{};

// Allowlist removed: all violations are hard-fail now
final warnOnlyImports = <String, List<String>>{};

void main() {
  final violations = <String>[];

  // Determine changed lines for this branch (to gate stricter checks)
  final addedLinesByFile = <String, List<String>>{};
  try {
    // Ensure we're inside a git work tree
    final isGit = Process.runSync('git', [
      'rev-parse',
      '--is-inside-work-tree',
    ]);
    if ((isGit.stdout as String).trim() == 'true') {
      // Determine a suitable base ref
      String base = 'origin/main';
      bool hasBase(String ref) {
        final res = Process.runSync('git', ['rev-parse', '--verify', ref]);
        return (res.exitCode == 0);
      }

      if (!hasBase(base)) {
        if (hasBase('main')) {
          base = 'main';
        } else if (hasBase('master')) {
          base = 'master';
        } else {
          // Fallback to previous commit
          base = 'HEAD~1';
        }
      }
      // New-work gating: only consider current working tree changes vs HEAD
      final diff = Process.runSync('git', [
        'diff',
        '--unified=0',
        '--no-color',
        '--',
        'lib/views',
        'lib/features',
      ]);
      if (diff.exitCode == 0) {
        final lines = (diff.stdout as String).split('\n');
        String currentFile = '';
        bool pendingNewFile = false;
        final newFiles = <String, bool>{};
        for (final line in lines) {
          if (line.startsWith('diff --git')) {
            currentFile = '';
            pendingNewFile = false;
          } else if (line.startsWith('new file mode')) {
            pendingNewFile = true;
          } else if (line.startsWith('+++ b/')) {
            currentFile = line.substring(6).trim();
            addedLinesByFile.putIfAbsent(currentFile, () => <String>[]);
            newFiles[currentFile] = pendingNewFile;
            pendingNewFile = false;
          } else if (line.startsWith('+') && !line.startsWith('+++')) {
            if (currentFile.isNotEmpty) {
              addedLinesByFile[currentFile]!.add(line.substring(1));
            }
          }
        }
        // Capture newly added files set for new-work gating under lib/views/**
        _newFiles = newFiles;
      }
    }
  } catch (_) {
    // If git parsing fails, proceed without gating
  }

  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = entity.readAsStringSync();

      // Global hard ban: any file path under lib/views/** is forbidden
      if (viewsPath.hasMatch(entity.path)) {
        violations.add(
          'Legacy path forbidden: lib/views/** → ${entity.path}',
        );
      }

      // Global ban: retired shim must not be referenced anywhere
      if (content.contains(
            "import 'package:wahda_bank/shared/ddd_ui_wiring.dart'",
          ) ||
          content.contains(
            'import "package:wahda_bank/shared/ddd_ui_wiring.dart"',
          )) {
        violations.add(
          'Global ban: ddd_ui_wiring.dart is retired → ${entity.path}',
        );
      }

      if (domainPath.hasMatch(entity.path)) {
        for (final ban in domainBans) {
          if (content.contains("import '$ban") ||
              content.contains('import "$ban')) {
            violations.add(
              'Domain import violation: ${entity.path} imports $ban',
            );
          }
        }
      }
      if (applicationPath.hasMatch(entity.path)) {
        for (final ban in applicationBans) {
          if (content.contains("import '$ban") ||
              content.contains('import "$ban')) {
            violations.add(
              'Application import violation: ${entity.path} imports $ban',
            );
          }
        }
      }

      // Presentation may not depend directly on infrastructure or legacy MailService
      if (presentationPath.hasMatch(entity.path)) {
        if (content.contains('import ') &&
            content.contains('/infrastructure/')) {
          violations.add(
            'Presentation->Infrastructure import violation: ${entity.path}',
          );
        }
        final mailSvcImportSingle =
            "import 'package:wahda_bank/services/mail_service.dart'";
        final mailSvcImportDouble =
            'import "package:wahda_bank/services/mail_service.dart"';
        final usesMailSvc =
            content.contains(mailSvcImportSingle) ||
            content.contains(mailSvcImportDouble);
        if (usesMailSvc) {
          // Allowlist by exact path or endsWith fallback (platform differences)
          final allowlistKey = warnOnlyImports.keys.firstWhere(
            (k) => entity.path == k || entity.path.endsWith(k),
            orElse: () => '',
          );
          final warningsForFile =
              warnOnlyImports[allowlistKey] ?? const <String>[];
          if (warningsForFile.contains(
            'package:wahda_bank/services/mail_service.dart',
          )) {
            softWarnings.add(
              'Soft warn: transitional import (MailService) in ${entity.path}',
            );
          } else {
            violations.add(
              'Presentation cannot import legacy MailService → ${entity.path}',
            );
          }
        }

        // Hardened rule: discourage raw Colors.* in feature UIs in favor of tokens/theme
        // Now treated as violation ONLY for newly added lines in this branch.
        final added = addedLinesByFile[entity.path] ?? const <String>[];
        final hasNewRawColors = added.any(
          (l) => l.contains('Colors.') && !l.contains('Colors.transparent'),
        );
        if (hasNewRawColors && !dsThemePath.hasMatch(entity.path)) {
          violations.add(
            'Presentation: raw Colors.* introduced in ${entity.path} — prefer tokens/theme.',
          );
        } else if (content.contains('Colors.') &&
            !dsThemePath.hasMatch(entity.path)) {
          // Keep as soft warn for existing lines
          softWarnings.add(
            'Soft warn: raw Colors.* usage in ${entity.path} — prefer tokens/theme.',
          );
        }
      }

      // Apply the same Colors.* rule to lib/views/* files
      if (viewsPath.hasMatch(entity.path) &&
          !dsThemePath.hasMatch(entity.path)) {
        final added = addedLinesByFile[entity.path] ?? const <String>[];
        final hasNewRawColors = added.any(
          (l) => l.contains('Colors.') && !l.contains('Colors.transparent'),
        );
        if (hasNewRawColors) {
          violations.add(
            'Views: raw Colors.* introduced in ${entity.path} — prefer tokens/theme.',
          );
        } else if (content.contains('Colors.')) {
          softWarnings.add(
            'Soft warn: raw Colors.* usage in ${entity.path} — prefer tokens/theme.',
          );
        }
      }
    }
  }
  if (violations.isNotEmpty) {
    stderr.writeln('Import enforcer violations:\n${violations.join('\n')}');
    if (softWarnings.isNotEmpty) {
      stderr.writeln(
        '\nSoft warnings (non-fatal):\n${softWarnings.join('\n')}',
      );
    }
    exit(1);
  } else {
    if (softWarnings.isNotEmpty) {
      stdout.writeln(
        'Import enforcer soft warnings:\n${softWarnings.join('\n')}',
      );
    }
    print('Import enforcer: OK');
  }
}
