# Notifications (P9)

Scope
- Domain events: NewMessageArrived, MessageFlagChanged, SyncFailed
- Port: NotificationPort (showInboxSummary, showNewMessage, cancelByThread)
- Application: OnNewMessage maps events to NotificationPayload (thread/group keys, deeplink). Quiet hours -> silent.
- Infrastructure: NoopNotificationAdapter writes to in-memory log (tests). NotificationsCoordinator subscribes to event bus (disabled until flag). Dedupe by thread.

Notes
- No platform APIs in P9.
- No UI or controller wiring.
- Flags remain OFF.

# notifications

