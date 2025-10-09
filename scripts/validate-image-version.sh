#!/bin/bash
set -euo pipefail

# Script to validate that the image version in deployment.yaml is a released stable version
# Usage: ./scripts/validate-image-version.sh
#
# Exit codes:
#   0 - Version is valid and exists in registry
#   1 - Version is invalid or does not exist

DEPLOYMENT_FILE="base/deployment.yaml"
EXIT_CODE=0

echo "==> Validating synq-scout image version" >&2

# Get current version from deployment.yaml
CURRENT_VERSION=$(grep 'image: europe-docker.pkg.dev/synq-cicd-public/synq-public/synq-scout:' "$DEPLOYMENT_FILE" | sed 's/.*synq-scout://' | tr -d ' ')
echo "Current version in deployment: $CURRENT_VERSION" >&2

# Check if version follows stable semver format (vX.Y.Z)
if ! echo "$CURRENT_VERSION" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' > /dev/null; then
  echo "ERROR: Version '$CURRENT_VERSION' is not a stable semver version (expected vX.Y.Z format)" >&2
  echo "Pre-release versions (e.g., -rc, -beta, -test, -alpha) are not allowed" >&2
  EXIT_CODE=1
else
  echo "✓ Version format is valid (stable semver)" >&2
fi

# Query Google Container Registry to verify the version exists
echo "Checking if version exists in registry..." >&2
TAGS_JSON=$(curl -s "https://europe-docker.pkg.dev/v2/synq-cicd-public/synq-public/synq-scout/tags/list")

# Check if the current version exists in the list of tags
if echo "$TAGS_JSON" | jq -r '.tags[]' | grep -q "^${CURRENT_VERSION}$"; then
  echo "✓ Version $CURRENT_VERSION exists in registry" >&2
else
  echo "ERROR: Version $CURRENT_VERSION does not exist in registry" >&2
  echo "Available stable versions:" >&2
  echo "$TAGS_JSON" | jq -r '.tags[]' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -5 >&2
  EXIT_CODE=1
fi

if [ $EXIT_CODE -eq 0 ]; then
  echo "==> Validation passed ✓" >&2
else
  echo "==> Validation failed ✗" >&2
fi

exit $EXIT_CODE
