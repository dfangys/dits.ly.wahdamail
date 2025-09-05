Summary
• Retargets imports to feature-scoped presentation screens where equivalents exist.
• Keeps lib/views/** allowed for existing files; adds a new-work-only ban to prevent new files under lib/views/**.
• Maintains presentation cleanliness (no presentation → services/mail_service.dart) and continues hard-fail on new Colors.* in presentation/views (DS/theme excluded).
• No behavior/UI changes.

Validation
• flutter pub get → OK
• build_runner (codegen) → OK
• dart run tool/import_enforcer.dart → OK (new-work-only lib/views/** ban active)
• dart analyze → 0 errors (warnings OK)
• flutter test --no-pub test → PASS
• flutter test --no-pub integration_test → Executed (device-dependent; see CI)

Note
• Full lib/views/** deletion will occur in P31.3b after remaining screens are migrated.

Tiny JSON (tracking)

{
  "phase": "P31.3-partial",
  "title": "Retarget imports to feature screens + new-work path ban",
  "branch": "feat/ddd-p31-3-remove-shims-retarget-imports",
  "goal": "Point existing code to feature/presentation screens and prevent new code under lib/views/**. No behavior change.",
  "changes": [
    "Retarget compose/search/mailbox/message-detail imports to feature paths",
    "Import enforcer: ban lib/views/** on added/modified lines only"
  ],
  "validation": [
    "Import enforcer OK",
    "Analyze 0 errors (warnings OK)",
    "Unit + integration tests PASS"
  ],
  "acceptance": [
    "No new references to lib/views/**",
    "All retargeted files build and tests pass"
  ]
}

