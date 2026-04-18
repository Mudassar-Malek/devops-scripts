#!/usr/bin/env bash
# Safely drains a Kubernetes node for maintenance.
# Usage: ./drain-node-safe.sh <node-name> [--context <kube-context>] [--dry-run]
#
# What it does:
#   1. Cordons the node (no new pods scheduled)
#   2. Shows pods that will be evicted
#   3. Prompts for confirmation
#   4. Drains with --ignore-daemonsets --delete-emptydir-data

set -euo pipefail

NODE="${1:-}"
CONTEXT=""
DRY_RUN=false

shift 1 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --context) CONTEXT="--context $2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$NODE" ]]; then
  echo "Usage: $0 <node-name> [--context <kube-context>] [--dry-run]" >&2
  exit 1
fi

echo "[*] Node: $NODE"
# shellcheck disable=SC2086
NODE_STATUS=$(kubectl get node "$NODE" $CONTEXT --no-headers 2>/dev/null | awk '{print $2}')
echo "[*] Current status: $NODE_STATUS"

echo ""
echo "[*] Pods that will be evicted:"
# shellcheck disable=SC2086
kubectl get pods --all-namespaces $CONTEXT \
  --field-selector "spec.nodeName=$NODE" \
  --no-headers \
  -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].kind' \
  2>/dev/null | grep -v DaemonSet || echo "  (none or all DaemonSets)"

echo ""
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY-RUN] Would cordon and drain $NODE. Exiting."
  exit 0
fi

read -rp "[?] Proceed with cordon + drain of $NODE? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "[!] Aborted."
  exit 1
fi

echo "[*] Cordoning $NODE..."
# shellcheck disable=SC2086
kubectl cordon "$NODE" $CONTEXT

echo "[*] Draining $NODE..."
# shellcheck disable=SC2086
kubectl drain "$NODE" $CONTEXT \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=60 \
  --timeout=300s

echo ""
echo "[OK] Node $NODE drained successfully."
echo "     After maintenance, uncordon with:"
echo "     kubectl uncordon $NODE${CONTEXT:+ $CONTEXT}"
