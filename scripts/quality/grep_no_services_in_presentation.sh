#!/usr/bin/env bash
set -euo pipefail
# Fails if any presentation file imports services/ or infrastructure/
if grep -R -n -E "^import[[:space:]]+['\"]package:wahda_bank/(services|infrastructure)/|/infrastructure/" -- lib/features/*/presentation >/dev/null; then
  echo "ERROR: Presentation importing services/ or infrastructure/. Use DI + use-cases/facades." >&2
  exit 1
fi
exit 0

