// ignore_for_file: unnecessary_library_name, constant_identifier_names
/// Centralized application-wide constants for timeouts, batch sizes, and tuning knobs.
/// Keep values conservative; adjust carefully with performance tests.
library app_constants;

class AppConstants {
  // Timeouts (seconds)
  static const int CONNECTION_TIMEOUT_SECONDS =
      10; // general network connection timeout
  static const int SHORT_CONNECTION_TIMEOUT_SECONDS =
      8; // short operations (e.g., quick selects)
  static const int CONNECT_RETRY_TIMEOUT_SECONDS = 12; // initial connect retry
  static const int MAILBOX_SELECTION_TIMEOUT_SECONDS = 10; // select mailbox
  static const int DB_INIT_TIMEOUT_SECONDS = 10; // local DB init
  static const int FETCH_NETWORK_TIMEOUT_SECONDS = 30; // fetch batches
  static const int FETCH_ENVELOPE_TIMEOUT_SECONDS = 25; // envelope fetch
  static const int FETCH_FULL_TIMEOUT_SECONDS = 25; // full message fetch

  // Mailbox load & paging
  static const int INITIAL_MAILBOX_LOAD_LIMIT =
      200; // first visible window size
  static const int MAILBOX_FETCH_BATCH_SIZE = 50; // network batch size
  static const int PAGE_SIZE = 50; // pagination page size

  // Prefetch / backfill
  static const int PREVIEW_BACKFILL_MAX_JOBS_PAGINATION =
      20; // backfill jobs for paged items
  static const int PREVIEW_BACKFILL_MAX_JOBS_CACHE =
      40; // backfill jobs when hydrating from cache

  // Background/monitor intervals (seconds)
  static const int AUTO_REFRESH_PERIOD_SECONDS =
      12; // auto background refresh cadence
  static const int SPECIAL_MONITOR_PERIOD_SECONDS =
      45; // special mailboxes monitor cadence
  static const int FOREGROUND_POLL_MIN_INTERVAL_SECONDS =
      15; // minimum foreground poll spacing

  // Reconcile windows (messages)
  static const int AUTO_REFRESH_RECONCILE_WINDOW =
      150; // small window for auto background reconcile
  static const int RECONCILE_WINDOW_LIGHT =
      100; // light reconcile window (e.g., after delete)
  static const int RECONCILE_WINDOW_DEFAULT = 300; // default reconcile window
}
