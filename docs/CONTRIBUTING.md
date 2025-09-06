# Contributing Guide (UI & Presentation)

This project follows a feature-first DDD + Clean Architecture layout. Please observe these rules when contributing UI:

Presentation locations
- All UI and ViewModels live under lib/features/**/presentation/**
- There is no lib/views/**. Any new files under lib/views/** will be rejected in CI.

Imports & layering
- Presentation must use use-cases/facades via DI (get_it/injectable)
- DO NOT import services/ or infrastructure/ from presentation
- Prefer feature ViewModels as the primary orchestrators

Design System
- Use Design System tokens/components (see docs/design_system/README.md)
- Avoid raw Colors.*. New usages in presentation/views will fail CI (DS/theme excluded)

Quality gates (run locally before pushing)
- flutter pub get
- dart run build_runner build --delete-conflicting-outputs
- dart run tool/import_enforcer.dart
- flutter analyze
- flutter test --no-pub test

Pull Requests
- Include a brief summary and confirm the quality gates above
- For UI-only changes: confirm no behavior change and visual parity (unless otherwise specified)

