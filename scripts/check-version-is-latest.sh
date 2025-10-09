#!/bin/bash
set -euo pipefail

# Script to check if the image version in deployment.yaml is the latest stable release
# Usage: ./scripts/check-version-is-latest.sh
#
# Outputs key=value pairs to stdout:
#   - is_latest: true/false
#   - current_version: vX.Y.Z
#   - latest_version: vX.Y.Z
#
# Exit codes:
#   0 - Version is the latest stable release
#   1 - Version is not the latest or error occurred

DEPLOYMENT_FILE="base/deployment.yaml"

echo "==> Checking if synq-scout version is latest" >&2

# Get current version from deployment.yaml
CURRENT_VERSION=$(grep 'image: europe-docker.pkg.dev/synq-cicd-public/synq-public/synq-scout:' "$DEPLOYMENT_FILE" | sed 's/.*synq-scout://' | tr -d ' ')
echo "Current version: $CURRENT_VERSION" >&2

# Query Google Container Registry for available tags
TAGS_JSON=$(curl -s "https://europe-docker.pkg.dev/v2/synq-cicd-public/synq-public/synq-scout/tags/list")

# Extract tags and find the latest stable semver version
# Only match vX.Y.Z format, excluding pre-release versions like -rc, -beta, -test, -alpha, etc.
LATEST_VERSION=$(echo "$TAGS_JSON" | jq -r '.tags[]' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)

if [ -z "$LATEST_VERSION" ]; then
  echo "ERROR: Could not determine latest version" >&2
  exit 1
fi

echo "Latest version: $LATEST_VERSION" >&2

# Output results as key=value pairs
echo "current_version=$CURRENT_VERSION"
echo "latest_version=$LATEST_VERSION"

# Compare versions
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
  echo "is_latest=true"
  echo "==> Version is up to date ✓" >&2
  exit 0
else
  echo "is_latest=false"
  echo "==> Version is outdated (update available: $CURRENT_VERSION -> $LATEST_VERSION)" >&2
  exit 1
fi
