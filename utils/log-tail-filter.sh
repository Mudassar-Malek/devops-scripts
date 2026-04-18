#!/usr/bin/env bash
# Tails pod logs across multiple replicas and filters by pattern.
# Usage: ./log-tail-filter.sh -l <label-selector> -n <namespace> [--filter <regex>] [--since 5m]
#
# Example:
#   ./log-tail-filter.sh -l app=payments -n prod --filter "ERROR|WARN" --since 10m
#
# Requirements: kubectl, GNU parallel (optional — falls back to background jobs)

set -euo pipefail

SELECTOR=""
NAMESPACE="default"
FILTER="."
SINCE="5m"
CONTEXT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -l|--selector) SELECTOR="$2"; shift 2 ;;
    -n|--namespace) NAMESPACE="$2"; shift 2 ;;
    --filter) FILTER="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --context) CONTEXT="--context $2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$SELECTOR" ]]; then
  echo "Usage: $0 -l <label-selector> -n <namespace> [--filter <regex>] [--since <duration>]" >&2
  exit 1
fi

# shellcheck disable=SC2086
PODS=$(kubectl get pods -n "$NAMESPACE" $CONTEXT -l "$SELECTOR" --no-headers -o custom-columns=':.metadata.name' 2>/dev/null)

if [[ -z "$PODS" ]]; then
  echo "[!] No pods found matching label '$SELECTOR' in namespace '$NAMESPACE'" >&2
  exit 1
fi

POD_COUNT=$(echo "$PODS" | wc -l | tr -d ' ')
echo "[*] Tailing $POD_COUNT pod(s) matching '$SELECTOR' in '$NAMESPACE'"
echo "[*] Filter: '$FILTER' | Since: $SINCE"
echo ""

# Tail each pod in background, prefix output with pod name
PIDS=()
while IFS= read -r POD; do
  # shellcheck disable=SC2086
  kubectl logs -n "$NAMESPACE" $CONTEXT -f --since="$SINCE" "$POD" 2>/dev/null | \
    grep -E "$FILTER" | \
    sed "s/^/[$POD] /" &
  PIDS+=($!)
done <<< "$PODS"

cleanup() {
  echo ""
  echo "[*] Stopping log tails..."
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

wait
