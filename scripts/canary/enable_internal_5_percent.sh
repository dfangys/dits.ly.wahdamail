#!/usr/bin/env bash
# scripts/canary/enable_internal_5_percent.sh
# Purpose: Enable 5% internal canary cohorts via remote flags (no app default changes).
# Usage: export REMOTE_FLAGS_ENDPOINT={{your_endpoint}} and AUTH={{token}} or adapt the curl calls below.
# NOTE: This script is illustrative; adapt to your remote flag service.

set -euo pipefail

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SEARCH_PERCENT=5
MESSAGING_PREFETCH_PERCENT=5
SEND_PERCENT=0
KILL_SWITCH_KEY="ddd.kill_switch.enabled"

# Deterministic cohort helper (djb2) in awk for quick targeting if your service accepts server-side rules
# Example condition (pseudocode): djb2(email) % 100 < PERCENT and email in internal domain

# Replace the following with your remote flag update API calls.
# Here we just echo the intended ops for auditing.
echo "[$NOW] Plan: set ddd.search.enabled to ${SEARCH_PERCENT}% internal cohort"
echo "[$NOW] Plan: set ddd.messaging.enabled (prefetch only) to ${MESSAGING_PREFETCH_PERCENT}% internal cohort"
echo "[$NOW] Plan: keep ddd.send.enabled at ${SEND_PERCENT}% (OFF)"
echo "[$NOW] Kill-switch key: ${KILL_SWITCH_KEY} (one-flip rollback)"

echo "[$NOW] Example ops (replace with real API):"
echo "curl -X POST $REMOTE_FLAGS_ENDPOINT/flags/ddd.search.enabled -H 'Authorization: Bearer $AUTH' -H 'Content-Type: application/json' \
  -d '{\"rule\": \"internal && (djb2(email)%100 < ${SEARCH_PERCENT})\"}'"

echo "curl -X POST $REMOTE_FLAGS_ENDPOINT/flags/ddd.messaging.enabled -H 'Authorization: Bearer $AUTH' -H 'Content-Type: application/json' \
  -d '{\"rule\": \"internal && (djb2(email)%100 < ${MESSAGING_PREFETCH_PERCENT})\"}'"

echo "curl -X POST $REMOTE_FLAGS_ENDPOINT/flags/ddd.send.enabled -H 'Authorization: Bearer $AUTH' -H 'Content-Type: application/json' \
  -d '{\"fixed\": false}'"

echo "[$NOW] To rollback immediately: set ${KILL_SWITCH_KEY}=true"

