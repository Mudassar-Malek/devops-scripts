#!/usr/bin/env bash
# Checks current SLO error budget burn rate against Prometheus.
# Usage: ./slo-burn-check.sh --prometheus <url> --service <name> --slo <0.999>
#
# Queries the 1h error rate and computes burn rate relative to the SLO target.
# A burn rate > 14.4 means the budget will be exhausted in < 5 days.
#
# Requirements: curl, jq, bc

set -euo pipefail

PROMETHEUS_URL=""
SERVICE=""
SLO_TARGET="0.999"   # 99.9% availability

while [[ $# -gt 0 ]]; do
  case $1 in
    --prometheus) PROMETHEUS_URL="$2"; shift 2 ;;
    --service) SERVICE="$2"; shift 2 ;;
    --slo) SLO_TARGET="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$PROMETHEUS_URL" || -z "$SERVICE" ]]; then
  echo "Usage: $0 --prometheus <url> --service <name> [--slo <0.999>]" >&2
  exit 1
fi

prom_query() {
  local query="$1"
  curl -sG "${PROMETHEUS_URL}/api/v1/query" \
    --data-urlencode "query=${query}" \
    | jq -r '.data.result[0].value[1] // "NaN"'
}

ERROR_BUDGET=$(echo "1 - $SLO_TARGET" | bc -l)

echo "[*] Service: $SERVICE"
echo "[*] SLO target: $(echo "$SLO_TARGET * 100" | bc -l | xargs printf "%.3f")%"
echo "[*] Error budget: $(echo "$ERROR_BUDGET * 100" | bc -l | xargs printf "%.4f")%"
echo ""

for WINDOW in "1h" "6h" "24h"; do
  QUERY="sum(rate(http_requests_total{service=\"${SERVICE}\",status=~\"5..\"}[${WINDOW}])) / sum(rate(http_requests_total{service=\"${SERVICE}\"}[${WINDOW}]))"
  ERROR_RATE=$(prom_query "$QUERY")

  if [[ "$ERROR_RATE" == "NaN" ]]; then
    echo "  [${WINDOW}] No data"
    continue
  fi

  BURN_RATE=$(echo "$ERROR_RATE / $ERROR_BUDGET" | bc -l | xargs printf "%.2f")
  HOURS_UNTIL_EXHAUSTED=$(echo "1 / ($BURN_RATE * ($ERROR_BUDGET / (30 * 24)))" | bc -l 2>/dev/null | xargs printf "%.1f" || echo "∞")

  STATUS="OK"
  [[ $(echo "$BURN_RATE > 6" | bc -l) -eq 1 ]] && STATUS="WARNING"
  [[ $(echo "$BURN_RATE > 14.4" | bc -l) -eq 1 ]] && STATUS="CRITICAL"

  printf "  [%s] error_rate=%.5f  burn_rate=%-6s  budget_exhausted_in=%-8s  %s\n" \
    "$WINDOW" "$ERROR_RATE" "${BURN_RATE}x" "${HOURS_UNTIL_EXHAUSTED}h" "$STATUS"
done

echo ""
echo "  Thresholds: CRITICAL = 14.4x (budget gone in < 2h at 1h window)"
echo "              WARNING  = 6x    (budget gone in < 5 days)"
