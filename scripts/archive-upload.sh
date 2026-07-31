#!/bin/bash

# Backward-compatible entry point. The release script keeps verification,
# archiving, and upload policy in one place.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/release.sh" upload "$@"
