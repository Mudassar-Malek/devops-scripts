#!/usr/bin/env bash
# HTTP health check poller — monitors an endpoint and alerts on failure.
# Usage: ./health-check.sh <url> [--interval 30] [--threshold 3] [--slack-webhook <url>]
#
# Sends a Slack alert after <threshold> consecutive failures.
# Requirements: curl

set -euo pipefail

URL="${1:-}"
INTERVAL=30
THRESHOLD=3
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
EXPECTED_CODE=200

shift 1 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --interval) INTERVAL="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --slack-webhook) SLACK_WEBHOOK="$2"; shift 2 ;;
    --expected-code) EXPECTED_CODE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$URL" ]]; then
  echo "Usage: $0 <url> [--interval <s>] [--threshold <n>] [--slack-webhook <url>]" >&2
  exit 1
fi

send_slack() {
  local message="$1"
  [[ -z "$SLACK_WEBHOOK" ]] && return
  curl -s -X POST "$SLACK_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"$message\"}" > /dev/null
}

FAILURES=0
ALERTED=false

echo "[*] Monitoring $URL (interval=${INTERVAL}s, threshold=${THRESHOLD})"
echo "    Press Ctrl+C to stop."
echo ""

while true; do
  TIMESTAMP=$(date +"%H:%M:%S")
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL" 2>/dev/null || echo "000")
  LATENCY=$(curl -s -o /dev/null -w "%{time_total}" --max-time 10 "$URL" 2>/dev/null || echo "N/A")

  if [[ "$HTTP_CODE" == "$EXPECTED_CODE" ]]; then
    printf "[%s] OK  HTTP %s  latency=%ss\n" "$TIMESTAMP" "$HTTP_CODE" "$LATENCY"
    if [[ "$ALERTED" == "true" ]]; then
      send_slack ":white_check_mark: *RECOVERED* | $URL is back up (HTTP $HTTP_CODE)"
      ALERTED=false
    fi
    FAILURES=0
  else
    FAILURES=$((FAILURES + 1))
    printf "[%s] FAIL  HTTP %s  consecutive_failures=%d\n" "$TIMESTAMP" "$HTTP_CODE" "$FAILURES"

    if [[ $FAILURES -ge $THRESHOLD && "$ALERTED" == "false" ]]; then
      MSG=":red_circle: *ALERT* | $URL returned HTTP $HTTP_CODE for $FAILURES consecutive checks"
      echo "[!] $MSG"
      send_slack "$MSG"
      ALERTED=true
    fi
  fi

  sleep "$INTERVAL"
done
