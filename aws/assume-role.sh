#!/usr/bin/env bash
# Assumes an IAM role and exports credentials into the current shell session.
# Usage: source ./assume-role.sh <role-arn> [session-name] [duration-seconds]
#
# Example:
#   source ./assume-role.sh arn:aws:iam::123456789012:role/DeployRole fintech-deploy 3600
#
# Requirements: aws-cli v2, jq

set -euo pipefail

ROLE_ARN="${1:-}"
SESSION_NAME="${2:-devops-session}"
DURATION="${3:-3600}"

if [[ -z "$ROLE_ARN" ]]; then
  echo "Usage: source $0 <role-arn> [session-name] [duration-seconds]" >&2
  return 1 2>/dev/null || exit 1
fi

echo "[*] Assuming role: $ROLE_ARN"
CREDS=$(aws sts assume-role \
  --role-arn "$ROLE_ARN" \
  --role-session-name "$SESSION_NAME" \
  --duration-seconds "$DURATION" \
  --output json)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')
EXPIRY=$(echo "$CREDS" | jq -r '.Credentials.Expiration')

echo "[OK] Role assumed. Credentials exported to environment."
echo "     Session: $SESSION_NAME"
echo "     Expires: $EXPIRY"
echo ""
echo "     Verify with: aws sts get-caller-identity"
