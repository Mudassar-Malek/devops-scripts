#!/usr/bin/env bash
# Triggers an ArgoCD app sync and waits for it to reach Healthy/Synced.
# Usage: ./argocd-sync-wait.sh <app-name> [--server <argocd-url>] [--timeout 300]
#
# Requirements: argocd CLI, or uses ARGOCD_SERVER + ARGOCD_AUTH_TOKEN env vars

set -euo pipefail

APP="${1:-}"
SERVER="${ARGOCD_SERVER:-}"
TIMEOUT=300

shift 1 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --server) SERVER="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$APP" ]]; then
  echo "Usage: $0 <app-name> [--server <argocd-url>] [--timeout <seconds>]" >&2
  exit 1
fi

SERVER_FLAG=""
[[ -n "$SERVER" ]] && SERVER_FLAG="--server $SERVER --insecure"

echo "[*] Syncing ArgoCD app: $APP"
# shellcheck disable=SC2086
argocd app sync "$APP" $SERVER_FLAG --prune

echo "[*] Waiting for $APP to reach Healthy/Synced (timeout: ${TIMEOUT}s)..."
ELAPSED=0
INTERVAL=10

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  # shellcheck disable=SC2086
  STATUS=$(argocd app get "$APP" $SERVER_FLAG \
    --output json 2>/dev/null | \
    jq -r '"health=\(.status.health.status) sync=\(.status.sync.status)"')

  echo "  [${ELAPSED}s] $STATUS"

  if echo "$STATUS" | grep -q "health=Healthy" && echo "$STATUS" | grep -q "sync=Synced"; then
    echo ""
    echo "[OK] $APP is Healthy and Synced after ${ELAPSED}s."
    exit 0
  fi

  if echo "$STATUS" | grep -q "health=Degraded"; then
    echo ""
    echo "[!] $APP is Degraded. Check ArgoCD for details." >&2
    # shellcheck disable=SC2086
    argocd app get "$APP" $SERVER_FLAG
    exit 1
  fi

  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo ""
echo "[!] Timeout after ${TIMEOUT}s. $APP did not reach Healthy/Synced." >&2
exit 1
