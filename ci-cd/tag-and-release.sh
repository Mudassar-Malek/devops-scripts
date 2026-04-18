#!/usr/bin/env bash
# Tags a git commit and creates a GitHub release with auto-generated changelog.
# Usage: ./tag-and-release.sh <version> [--repo owner/repo] [--draft]
#
# Example: ./tag-and-release.sh v1.4.2 --repo myorg/payments-service
#
# Requirements: git, gh (GitHub CLI)

set -euo pipefail

VERSION="${1:-}"
REPO=""
DRAFT_FLAG=""

shift 1 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --repo) REPO="--repo $2"; shift 2 ;;
    --draft) DRAFT_FLAG="--draft"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version> [--repo owner/repo] [--draft]" >&2
  exit 1
fi

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "[!] Version must be in format vX.Y.Z (e.g. v1.4.2)" >&2
  exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
COMMIT=$(git rev-parse --short HEAD)

echo "[*] Creating release $VERSION from $BRANCH ($COMMIT)"

# Build changelog from commits since last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [[ -n "$LAST_TAG" ]]; then
  CHANGELOG=$(git log "${LAST_TAG}..HEAD" --pretty=format:"- %s (%h)" --no-merges)
  echo "[*] Changes since $LAST_TAG:"
else
  CHANGELOG=$(git log --pretty=format:"- %s (%h)" --no-merges -20)
  echo "[*] No previous tag found. Using last 20 commits:"
fi

echo "$CHANGELOG"
echo ""

read -rp "[?] Tag and release $VERSION? (yes/no): " CONFIRM
[[ "$CONFIRM" != "yes" ]] && { echo "[!] Aborted."; exit 1; }

echo "[*] Creating git tag $VERSION..."
git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"

NOTES="## What's Changed

$CHANGELOG

---
**Full diff:** $(git config --get remote.origin.url | sed 's/\.git$//')/compare/${LAST_TAG}...${VERSION}"

echo "[*] Creating GitHub release..."
# shellcheck disable=SC2086
gh release create "$VERSION" \
  $REPO \
  $DRAFT_FLAG \
  --title "Release $VERSION" \
  --notes "$NOTES"

echo "[OK] Release $VERSION created."
