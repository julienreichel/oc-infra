#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <namespace> <project>"
  echo "Example: $0 oc-provider backend"
  exit 1
fi

NS="$1"
DEPLOY="$2"

echo "Starting ${NS}-${DEPLOY} in ${NS}..."
kubectl scale deployment "${NS}-${DEPLOY}" -n "${NS}" --replicas=1
