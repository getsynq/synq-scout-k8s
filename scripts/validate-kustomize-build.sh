#!/bin/bash
set -euo pipefail

# Script to validate that kustomize builds successfully for all overlays
# Usage: ./scripts/validate-kustomize-build.sh [overlay1 overlay2 ...]
#        If no overlays specified, defaults to 'example'
#
# Exit codes:
#   0 - All kustomize builds successful
#   1 - One or more builds failed

OVERLAYS="${@:-example}"
EXIT_CODE=0

for overlay in $OVERLAYS; do
  echo "==> Building kustomize overlay: $overlay" >&2

  if ! kubectl kustomize "overlays/$overlay" > /tmp/output.yaml; then
    echo "ERROR: Kustomize build failed for overlay: $overlay" >&2
    EXIT_CODE=1
    continue
  fi

  echo "==> Validating output is not empty" >&2
  if [ ! -s /tmp/output.yaml ]; then
    echo "ERROR: Kustomize build produced empty output for overlay: $overlay" >&2
    EXIT_CODE=1
    continue
  fi

  echo "==> Build successful ✓" >&2
  echo "Generated $(wc -l </tmp/output.yaml) lines of Kubernetes manifests" >&2
  echo "" >&2
done

if [ $EXIT_CODE -eq 0 ]; then
  echo "==> All kustomize validations passed ✓" >&2
else
  echo "==> Kustomize validation failed ✗" >&2
fi

exit $EXIT_CODE
