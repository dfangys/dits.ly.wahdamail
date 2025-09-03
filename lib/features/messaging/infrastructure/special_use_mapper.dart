import 'package:wahda_bank/shared/logging/telemetry.dart';

enum SpecialUse { inbox, sent, drafts, trash, junk, archive, other }

/// Maps server special-use flags (RFC 6154) and allows tenant overrides.
class SpecialUseMapper {
  final Map<String, SpecialUse> tenantOverrides; // key: folderId or server name
  SpecialUseMapper({Map<String, SpecialUse>? tenantOverrides}) : tenantOverrides = tenantOverrides ?? const {};

  SpecialUse mapFor({required String folderId, List<String> serverFlags = const [], String? serverName}) {
    // Tenant override wins
    final override = tenantOverrides[folderId] ?? (serverName != null ? tenantOverrides[serverName] : null);
    if (override != null) {
      _emit(folderId, override);
      return override;
    }
    final lower = serverFlags.map((e) => e.toLowerCase()).toSet();
    SpecialUse use = SpecialUse.other;
    if (lower.contains('\\inbox')) {
      use = SpecialUse.inbox;
    } else if (lower.contains('\\sent')) {
      use = SpecialUse.sent;
    } else if (lower.contains('\\drafts')) {
      use = SpecialUse.drafts;
    } else if (lower.contains('\\trash')) {
      use = SpecialUse.trash;
    } else if (lower.contains('\\junk') || lower.contains('\\spam')) {
      use = SpecialUse.junk;
    } else if (lower.contains('\\archive')) {
      use = SpecialUse.archive;
    }
    _emit(folderId, use);
    return use;
  }

  void _emit(String folderId, SpecialUse use) {
    // Lightweight telemetry
    try {
      Telemetry.event('operation', props: {
        'op': 'SpecialUseMap',
        'folder_id': folderId,
        'lat_ms': 0,
      });
    } catch (_) {}
  }
}

