#!/bin/bash
set -euo pipefail

# Script to check for latest synq-scout Docker image version and update deployment.yaml
# Usage: ./scripts/check-and-update-version.sh
#
# Outputs key=value pairs to stdout:
#   - should_update: true/false
#   - current_version: vX.Y.Z
#   - new_version: vX.Y.Z (if update available)

# Image repository
IMAGE_REPO="europe-docker.pkg.dev/synq-cicd-public/synq-public/synq-scout"
DEPLOYMENT_FILE="base/deployment.yaml"

echo "==> Checking for latest synq-scout image version" >&2

# Get current version from deployment.yaml
CURRENT_VERSION=$(grep 'image: europe-docker.pkg.dev/synq-cicd-public/synq-public/synq-scout:' "$DEPLOYMENT_FILE" | sed 's/.*synq-scout://' | tr -d ' ')
echo "Current version: $CURRENT_VERSION" >&2

# Query Google Container Registry for available tags
# Using Docker Registry HTTP API v2 (public registry)
TAGS_JSON=$(curl -s "https://europe-docker.pkg.dev/v2/synq-cicd-public/synq-public/synq-scout/tags/list")

# Extract tags and find the latest stable semver version
# Only match vX.Y.Z format, excluding pre-release versions like -rc, -beta, -test, -alpha, etc.
LATEST_VERSION=$(echo "$TAGS_JSON" | jq -r '.tags[]' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)

if [ -z "$LATEST_VERSION" ]; then
  echo "ERROR: Could not determine latest version" >&2
  exit 1
fi

echo "Latest version: $LATEST_VERSION" >&2

# Compare versions
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
  echo "Already on latest version" >&2
  echo "should_update=false"
  echo "current_version=$CURRENT_VERSION"
  exit 0
fi

echo "Update available: $CURRENT_VERSION -> $LATEST_VERSION" >&2

# Update the image version in deployment.yaml
sed -i.bak "s|image: europe-docker.pkg.dev/synq-cicd-public/synq-public/synq-scout:.*|image: europe-docker.pkg.dev/synq-cicd-public/synq-public/synq-scout:${LATEST_VERSION}|" "$DEPLOYMENT_FILE"
rm -f "${DEPLOYMENT_FILE}.bak"

echo "Updated $DEPLOYMENT_FILE to version $LATEST_VERSION" >&2

# Verify the change
echo "Verification:" >&2
grep "image: europe-docker.pkg.dev" "$DEPLOYMENT_FILE" >&2

# Output results as key=value pairs
echo "should_update=true"
echo "current_version=$CURRENT_VERSION"
echo "new_version=$LATEST_VERSION"

echo "==> Done" >&2
