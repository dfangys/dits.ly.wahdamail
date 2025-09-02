# Settings (P9)

SettingsRepository exposes typed getters/setters:
- quiet_hours_start (default 22), quiet_hours_end (default 7)
- notif_sound_enabled (default true)
- notif_vibrate_enabled (default true)
- notif_group_by_thread (default true)
- notif_max (default 5)
- allow_remote_images (default false)

Infrastructure store wraps GetStorage; FakeStorageSettings used in tests.
Migration notes: legacy keys are mapped to typed accessors, but behavior unchanged in P9.

# settings

