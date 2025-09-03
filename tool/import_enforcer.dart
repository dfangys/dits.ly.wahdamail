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
        if (content.contains("import 'package:wahda_bank/services/mail_service.dart'") ||
            content.contains('import "package:wahda_bank/services/mail_service.dart"')) {
          violations.add('Presentation cannot import legacy MailService → ${entity.path}');
        }
      }
    }
  }
  if (violations.isNotEmpty) {
    stderr.writeln('Import enforcer violations:\n${violations.join('\n')}');
    exit(1);
  } else {
    print('Import enforcer: OK');
  }
}
