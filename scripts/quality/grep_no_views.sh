#!/usr/bin/env bash
set -euo pipefail
# Fails if any import references package:.../views/ or any lib/views path exists
if grep -R -n -E "package:[^"]*/views/|lib/views/|import[[:space:]]+['\"]package:[^'\"]*/views/" -- lib test integration_test >/dev/null; then
  echo "ERROR: Found references to legacy views/. Please retarget to lib/features/**/presentation/**" >&2
  exit 1
fi
exit 0

