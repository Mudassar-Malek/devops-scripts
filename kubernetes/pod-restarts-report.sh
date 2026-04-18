#!/usr/bin/env bash
# Reports pods with high restart counts across all namespaces (or a specific one).
# Usage: ./pod-restarts-report.sh [--namespace <ns>] [--threshold <n>] [--context <kube-context>]
#
# Flags:
#   --namespace   Kubernetes namespace (default: all namespaces)
#   --threshold   Minimum restart count to report (default: 5)
#   --context     kubectl context to use

set -euo pipefail

NAMESPACE="--all-namespaces"
THRESHOLD=5
CONTEXT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace) NAMESPACE="-n $2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --context) CONTEXT="--context $2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

echo "[*] Pods with ≥ $THRESHOLD restarts:"
printf "\n%-50s %-20s %-10s %s\n" "POD" "NAMESPACE" "RESTARTS" "STATUS"
printf '%s\n' "$(printf '%.0s-' {1..95})"

# shellcheck disable=SC2086
kubectl get pods $NAMESPACE $CONTEXT \
  --no-headers \
  -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount,STATUS:.status.phase' \
  2>/dev/null | \
  awk -v threshold="$THRESHOLD" '
    $3 ~ /^[0-9]+$/ && $3 >= threshold {
      printf "%-50s %-20s %-10s %s\n", $2, $1, $3, $4
    }
  ' | sort -t' ' -k3 -rn

echo ""
echo "[*] To see logs for a crashing pod:"
echo "     kubectl logs <pod> -n <namespace> --previous"
