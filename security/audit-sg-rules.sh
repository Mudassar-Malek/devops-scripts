#!/usr/bin/env bash
# Audits AWS Security Groups for overly permissive inbound rules (0.0.0.0/0 or ::/0).
# Usage: ./audit-sg-rules.sh [--region us-east-1] [--profile default] [--ports 22,3306,5432]
#
# Flags risky open-to-world rules, especially on sensitive ports.
# Requirements: aws-cli v2, jq

set -euo pipefail

REGION="us-east-1"
PROFILE="default"
RISKY_PORTS=(22 3306 5432 6379 27017 9200 8080)

while [[ $# -gt 0 ]]; do
  case $1 in
    --region) REGION="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --ports) IFS=',' read -ra RISKY_PORTS <<< "$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

echo "[*] Auditing Security Groups in $REGION for 0.0.0.0/0 or ::/0 rules..."
echo ""

FINDINGS=0

aws ec2 describe-security-groups \
  --region "$REGION" \
  --profile "$PROFILE" \
  --output json | \
  jq -r '.SecurityGroups[] | {id: .GroupId, name: .GroupName, rules: .IpPermissions[]} |
    {id, name, from: .rules.FromPort, to: .rules.ToPort, proto: .rules.IpProtocol,
     cidrs: [.rules.IpRanges[].CidrIp, .rules.Ipv6Ranges[].CidrIpv6] | flatten} |
    select(.cidrs[] | . == "0.0.0.0/0" or . == "::/0") |
    "\(.id)|\(.name)|\(.proto)|\(.from // "all")|\(.to // "all")"' | \
  while IFS='|' read -r sgid sgname proto from to; do
    RISK="INFO"
    for port in "${RISKY_PORTS[@]}"; do
      if [[ "$from" == "all" ]] || [[ "$from" -le "$port" && "$to" -ge "$port" ]] 2>/dev/null; then
        RISK="HIGH"
        break
      fi
    done
    printf "%-20s %-30s %-6s %-6s %-6s %s\n" "$sgid" "${sgname:0:29}" "$proto" "$from" "$to" "[$RISK] open to world"
    FINDINGS=$((FINDINGS + 1))
  done

echo ""
echo "[*] Scan complete. Review HIGH findings for unauthorized internet exposure."
echo "     Sensitive ports flagged: ${RISKY_PORTS[*]}"
