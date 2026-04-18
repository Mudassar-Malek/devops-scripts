#!/usr/bin/env bash
# Scans a CIDR range for unexpectedly open ports using nmap.
# Usage: ./scan-exposed-ports.sh <cidr> [--ports <port-list>] [--output <file>]
#
# Example:
#   ./scan-exposed-ports.sh 10.0.1.0/24 --ports 22,3306,5432,6379,27017 --output report.txt
#
# IMPORTANT: Only run against infrastructure you own or have explicit authorization to scan.
# Requirements: nmap

set -euo pipefail

CIDR="${1:-}"
PORTS="22,3306,5432,6379,27017,9200,2181,8080,8443"  # common risky ports
OUTPUT=""

shift 1 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --ports) PORTS="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$CIDR" ]]; then
  echo "Usage: $0 <cidr> [--ports <port-list>] [--output <file>]" >&2
  exit 1
fi

if ! command -v nmap &>/dev/null; then
  echo "[!] nmap not found. Install with: brew install nmap / apt install nmap" >&2
  exit 1
fi

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "[$TIMESTAMP] Scanning $CIDR for ports: $PORTS"
echo "NOTE: Only scan infrastructure you are authorized to test."
echo ""

run_scan() {
  nmap -p "$PORTS" --open -T4 -oG - "$CIDR" 2>/dev/null | \
    awk '/Host:/{host=$2} /Ports:/{
      split($0, parts, "Ports: ");
      printf "%-18s %s\n", host, parts[2]
    }'
}

if [[ -n "$OUTPUT" ]]; then
  run_scan | tee "$OUTPUT"
  echo ""
  echo "[OK] Results saved to $OUTPUT"
else
  run_scan
fi
