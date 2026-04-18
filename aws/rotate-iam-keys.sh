#!/usr/bin/env bash
# Rotates IAM access keys for a given IAM user.
# Usage: ./rotate-iam-keys.sh <iam-username> [--profile <aws-profile>]
#
# What it does:
#   1. Creates a new access key
#   2. Writes it to ~/.aws/credentials under [rotated-<username>]
#   3. Deactivates (does NOT delete) the old key — manual deletion after validation
#
# Requirements: aws-cli v2, jq

set -euo pipefail

USERNAME="${1:-}"
PROFILE="${3:-default}"

if [[ -z "$USERNAME" ]]; then
  echo "Usage: $0 <iam-username> [--profile <aws-profile>]" >&2
  exit 1
fi

echo "[*] Fetching existing keys for $USERNAME..."
OLD_KEY=$(aws iam list-access-keys --user-name "$USERNAME" --profile "$PROFILE" \
  --query 'AccessKeyMetadata[?Status==`Active`].AccessKeyId' \
  --output text | awk '{print $1}')

if [[ -z "$OLD_KEY" ]]; then
  echo "[!] No active key found for $USERNAME — nothing to rotate."
  exit 0
fi

echo "[*] Active key: $OLD_KEY"

echo "[*] Creating new access key..."
NEW_KEY_JSON=$(aws iam create-access-key --user-name "$USERNAME" --profile "$PROFILE")
NEW_ACCESS_KEY=$(echo "$NEW_KEY_JSON" | jq -r '.AccessKey.AccessKeyId')
NEW_SECRET_KEY=$(echo "$NEW_KEY_JSON" | jq -r '.AccessKey.SecretAccessKey')

echo "[*] New key created: $NEW_ACCESS_KEY"

CREDS_SECTION="rotated-${USERNAME}"
aws configure set aws_access_key_id "$NEW_ACCESS_KEY" --profile "$CREDS_SECTION"
aws configure set aws_secret_access_key "$NEW_SECRET_KEY" --profile "$CREDS_SECTION"
echo "[*] New credentials saved to ~/.aws/credentials under profile [$CREDS_SECTION]"

echo "[*] Deactivating old key $OLD_KEY (not deleting — validate new key first)..."
aws iam update-access-key \
  --user-name "$USERNAME" \
  --access-key-id "$OLD_KEY" \
  --status Inactive \
  --profile "$PROFILE"

echo ""
echo "[OK] Key rotation complete."
echo "     Old key $OLD_KEY → Inactive"
echo "     New key $NEW_ACCESS_KEY → Active (profile: $CREDS_SECTION)"
echo ""
echo "     After validating the new key, delete the old one with:"
echo "     aws iam delete-access-key --user-name $USERNAME --access-key-id $OLD_KEY --profile $PROFILE"
