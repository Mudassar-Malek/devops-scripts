#!/usr/bin/env bash
# Rolls back a Kubernetes deployment to a previous revision with audit trail.
# Usage: ./rollback-deployment.sh <deployment> -n <namespace> [--to-revision <n>] [--context <ctx>]
#
# With no --to-revision, rolls back to the previous revision (undo).

set -euo pipefail

DEPLOYMENT="${1:-}"
NAMESPACE="default"
REVISION=""
CONTEXT=""

shift 1 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--namespace) NAMESPACE="$2"; shift 2 ;;
    --to-revision) REVISION="$2"; shift 2 ;;
    --context) CONTEXT="--context $2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$DEPLOYMENT" ]]; then
  echo "Usage: $0 <deployment> -n <namespace> [--to-revision <n>] [--context <ctx>]" >&2
  exit 1
fi

# shellcheck disable=SC2086
BASE="kubectl -n $NAMESPACE $CONTEXT"

echo "[*] Rollout history for $DEPLOYMENT:"
# shellcheck disable=SC2086
$BASE rollout history deployment/"$DEPLOYMENT"

echo ""
CURRENT_IMAGE=$($BASE get deployment "$DEPLOYMENT" \
  -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "[*] Current image: $CURRENT_IMAGE"

echo ""
REVISION_FLAG=""
[[ -n "$REVISION" ]] && REVISION_FLAG="--to-revision=$REVISION"

read -rp "[?] Rollback $DEPLOYMENT to ${REVISION:-previous revision}? (yes/no): " CONFIRM
[[ "$CONFIRM" != "yes" ]] && { echo "[!] Aborted."; exit 1; }

echo "[*] Initiating rollback..."
# shellcheck disable=SC2086
$BASE rollout undo deployment/"$DEPLOYMENT" $REVISION_FLAG

echo "[*] Waiting for rollout to complete..."
# shellcheck disable=SC2086
$BASE rollout status deployment/"$DEPLOYMENT" --timeout=120s

NEW_IMAGE=$($BASE get deployment "$DEPLOYMENT" \
  -o jsonpath='{.spec.template.spec.containers[0].image}')
echo ""
echo "[OK] Rollback complete."
echo "     Before: $CURRENT_IMAGE"
echo "     After:  $NEW_IMAGE"
