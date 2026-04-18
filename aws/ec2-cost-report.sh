#!/usr/bin/env bash
# Generates a quick EC2 cost/usage report grouped by environment tag.
# Usage: ./ec2-cost-report.sh [--region us-east-1] [--profile default]
#
# Output: table of instance-id, type, state, env tag, and monthly on-demand cost estimate
# Requirements: aws-cli v2, jq

set -euo pipefail

REGION="us-east-1"
PROFILE="default"

while [[ $# -gt 0 ]]; do
  case $1 in
    --region) REGION="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# On-demand hourly prices (USD) — update as needed for your region
declare -A PRICES=(
  [t3.micro]=0.0104
  [t3.small]=0.0208
  [t3.medium]=0.0416
  [t3.large]=0.0832
  [m5.large]=0.096
  [m5.xlarge]=0.192
  [m5.2xlarge]=0.384
  [c5.large]=0.085
  [c5.xlarge]=0.17
  [r5.large]=0.126
  [r5.xlarge]=0.252
)

echo "[*] Fetching EC2 instances in $REGION..."
INSTANCES=$(aws ec2 describe-instances \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,Tags[?Key==`Environment`]|[0].Value,Tags[?Key==`Name`]|[0].Value]' \
  --output json)

printf "\n%-22s %-14s %-10s %-14s %-30s %s\n" \
  "INSTANCE-ID" "TYPE" "STATE" "ENV" "NAME" "EST. MONTHLY (USD)"
printf '%s\n' "$(printf '%.0s-' {1..100})"

echo "$INSTANCES" | jq -r '.[] | @tsv' | while IFS=$'\t' read -r id type state env name; do
  env="${env:-untagged}"
  name="${name:-unnamed}"
  price="${PRICES[$type]:-?}"

  if [[ "$price" == "?" ]]; then
    monthly="N/A"
  else
    monthly=$(awk "BEGIN {printf \"%.2f\", $price * 730}")
  fi

  printf "%-22s %-14s %-10s %-14s %-30s \$%s\n" \
    "$id" "$type" "$state" "$env" "${name:0:29}" "$monthly"
done

echo ""
echo "[*] Prices are on-demand estimates only. Check AWS Cost Explorer for actual spend."
