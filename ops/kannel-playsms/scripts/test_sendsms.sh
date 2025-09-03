#!/usr/bin/env bash
# Helper to exercise routes via Kannel's sendsms on localhost
# Usage: adjust MSISDNs below to valid test numbers you are authorized to message.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1090
source "$ROOT_DIR/.env" 2>/dev/null || { echo "Load .env in $ROOT_DIR first"; exit 1; }

host="127.0.0.1"
port="13001"
user="${KANNEL_SENDSMS_USER:-playsms}"
pass="${KANNEL_SENDSMS_PASS:-}"

send() {
  local to="$1"; shift
  local text="$*"
  curl -s "http://${host}:${port}/cgi-bin/sendsms" \
    --data-urlencode "username=${user}" \
    --data-urlencode "password=${pass}" \
    --data-urlencode "to=${to}" \
    --data-urlencode "text=${text}" \
    --data-urlencode "dlr-mask=31" || true
  echo
}

echo "Test Almadar (+21891)"; send "+21891XXXXXXXXX" "Test Almadar +21891"
echo "Test Almadar (091 local)"; send "091XXXXXXXXX" "Test Almadar 091"
echo "Test Libyana (+21892)"; send "+21892XXXXXXXXX" "Test Libyana +21892"
echo "Test Libyana (0021894)"; send "0021894XXXXXXX" "Test Libyana 00218"
echo "Test non-Libyan (should fail)"; send "+2010XXXXXXX" "NoRoute"

