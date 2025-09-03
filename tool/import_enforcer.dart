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
final domainPath = RegExp(r'lib/features/.+/domain/');
final applicationPath = RegExp(r'lib/features/.+/application/');

// Soft warnings (do not fail)
final softWarnings = <String>[];

// Allowlist for known transitional imports (warn only)
final warnOnlyImports = <String, List<String>>{
  'lib/features/search/presentation/search_view_model.dart': [
    "package:wahda_bank/services/mail_service.dart",
  ],
};

void main() {
  final violations = <String>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = entity.readAsStringSync();

      // Global ban: retired shim must not be referenced anywhere
      if (content.contains("import 'package:wahda_bank/shared/ddd_ui_wiring.dart'") ||
          content.contains('import "package:wahda_bank/shared/ddd_ui_wiring.dart"')) {
        violations.add('Global ban: ddd_ui_wiring.dart is retired → ${entity.path}');
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
        if (content.contains('import ') && content.contains('/infrastructure/')) {
          violations.add(
            'Presentation->Infrastructure import violation: ${entity.path}',
          );
        }
        final mailSvcImportSingle = "import 'package:wahda_bank/services/mail_service.dart'";
        final mailSvcImportDouble = 'import "package:wahda_bank/services/mail_service.dart"';
        final usesMailSvc = content.contains(mailSvcImportSingle) || content.contains(mailSvcImportDouble);
        if (usesMailSvc) {
          // Allowlist by exact path or endsWith fallback (platform differences)
          final allowlistKey = warnOnlyImports.keys.firstWhere(
            (k) => entity.path == k || entity.path.endsWith(k),
            orElse: () => '',
          );
          final warningsForFile = warnOnlyImports[allowlistKey] ?? const <String>[];
          if (warningsForFile.contains('package:wahda_bank/services/mail_service.dart')) {
            softWarnings.add('Soft warn: transitional import (MailService) in ${entity.path}');
          } else {
            violations.add('Presentation cannot import legacy MailService → ${entity.path}');
          }
        }

        // Soft nudge: discourage raw Colors.* in feature UIs in favor of tokens
        if (content.contains('Colors.')) {
          softWarnings.add('Soft warn: raw Colors.* usage in ${entity.path} — prefer tokens/theme.');
        }
      }
    }
  }
  if (violations.isNotEmpty) {
    stderr.writeln('Import enforcer violations:\n${violations.join('\n')}');
    if (softWarnings.isNotEmpty) {
      stderr.writeln('\nSoft warnings (non-fatal):\n${softWarnings.join('\n')}');
    }
    exit(1);
  } else {
    if (softWarnings.isNotEmpty) {
      stdout.writeln('Import enforcer soft warnings:\n${softWarnings.join('\n')}');
    }
    print('Import enforcer: OK');
  }
}
