#!/usr/bin/env bash
# Creates an Alertmanager silence for a given label matcher.
# Usage: ./alert-silence.sh --alertmanager <url> --matcher <label=value> --duration <Xh|Xm> --comment "reason"
#
# Example:
#   ./alert-silence.sh \
#     --alertmanager http://alertmanager:9093 \
#     --matcher "service=payments" \
#     --duration 2h \
#     --comment "Planned maintenance window"
#
# Requirements: curl, jq

set -euo pipefail

AM_URL=""
MATCHER=""
DURATION="1h"
COMMENT=""
CREATED_BY="${USER:-devops}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --alertmanager) AM_URL="$2"; shift 2 ;;
    --matcher) MATCHER="$2"; shift 2 ;;
    --duration) DURATION="$2"; shift 2 ;;
    --comment) COMMENT="$2"; shift 2 ;;
    --created-by) CREATED_BY="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$AM_URL" || -z "$MATCHER" || -z "$COMMENT" ]]; then
  echo "Usage: $0 --alertmanager <url> --matcher <label=value> --duration <Xh|Xm> --comment <reason>" >&2
  exit 1
fi

# Parse "key=value" matcher
LABEL_NAME="${MATCHER%%=*}"
LABEL_VALUE="${MATCHER#*=}"

# Convert duration string to end time
parse_duration_to_seconds() {
  local dur="$1"
  local unit="${dur: -1}"
  local num="${dur:0:-1}"
  case "$unit" in
    h) echo $((num * 3600)) ;;
    m) echo $((num * 60)) ;;
    d) echo $((num * 86400)) ;;
    *) echo "Invalid duration unit: $unit" >&2; exit 1 ;;
  esac
}

SECONDS_TO_ADD=$(parse_duration_to_seconds "$DURATION")
START=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
END=$(date -u -d "+${SECONDS_TO_ADD} seconds" +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null \
  || date -u -v "+${SECONDS_TO_ADD}S" +"%Y-%m-%dT%H:%M:%S.000Z")  # macOS fallback

PAYLOAD=$(jq -n \
  --arg name "$LABEL_NAME" \
  --arg value "$LABEL_VALUE" \
  --arg start "$START" \
  --arg end "$END" \
  --arg comment "$COMMENT" \
  --arg createdBy "$CREATED_BY" \
  '{
    matchers: [{ name: $name, value: $value, isRegex: false }],
    startsAt: $start,
    endsAt: $end,
    comment: $comment,
    createdBy: $createdBy
  }')

echo "[*] Creating silence: $MATCHER for $DURATION"
echo "[*] Reason: $COMMENT"

RESPONSE=$(curl -s -X POST \
  "${AM_URL}/api/v2/silences" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

SILENCE_ID=$(echo "$RESPONSE" | jq -r '.silenceID // empty')
if [[ -z "$SILENCE_ID" ]]; then
  echo "[!] Failed to create silence. Response:" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

echo "[OK] Silence created: $SILENCE_ID"
echo "     Active until: $END"
echo ""
echo "     View at: ${AM_URL}/#/silences"
echo "     Delete with: curl -X DELETE ${AM_URL}/api/v2/silence/$SILENCE_ID"
