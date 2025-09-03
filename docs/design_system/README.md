# Design System (P18.0)

Goal: introduce shared theme tokens and presentation components with zero UI/behavior changes.

What’s included
- Tokens: spacing, radii, durations, colors mapped 1:1 to existing visuals.
- Typography: mirrors legacy sizes/weights, keeps locale-based font family.
- Theme: AppThemeDS.light/dark backed by legacy AppTheme for perfect parity.
- Components: AppScaffold, AppListTile, EmptyState, ErrorState, LoadingSkeleton.
- Feature widgets: mailbox_list_item, section_header, message_meta_row, attachment_chip, preview_stub.

Usage
- Wrap MaterialApp/GetMaterialApp with AppThemeDS.light and AppThemeDS.dark.
- Use Theme.of(context).colorScheme and textTheme instead of raw Colors.*.
- Prefer Tokens for spacing/radii where reasonable.

Guardrails (soft nudge)
- Import enforcer emits a soft warning for raw Colors.* usage in feature/presentation files. Not a build failure in P18.0.

No flags changed; kill-switch precedence remains intact. No dependency or pin changes.

