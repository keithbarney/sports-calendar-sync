#!/bin/bash
# Build + archive + upload to App Store Connect via API key.
# Requires .env.appstore with ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH.

set -euo pipefail

cd "$(dirname "$0")/.."

# Load credentials
if [ ! -f .env.appstore ]; then
    echo "ERROR: .env.appstore missing. Create it with ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH."
    exit 1
fi
set -o allexport
# shellcheck disable=SC1091
source .env.appstore
set +o allexport

# Expand $HOME in path
ASC_KEY_PATH_EXPANDED="${ASC_KEY_PATH/#\$HOME/$HOME}"
if [ ! -f "$ASC_KEY_PATH_EXPANDED" ]; then
    echo "ERROR: Key file not found at $ASC_KEY_PATH_EXPANDED"
    exit 1
fi

SCHEME="SportsCalendarSync"
PROJECT="SportsCalendarSync.xcodeproj"
ARCHIVE_PATH="build/SportsCalendarSync.xcarchive"
EXPORT_DIR="build/export"
EXPORT_OPTIONS="ExportOptions.plist"

echo "→ xcodegen"
xcodegen generate

echo "→ archive"
rm -rf build
mkdir -p build
if command -v xcpretty > /dev/null; then
    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "generic/platform=iOS" \
        -archivePath "$ARCHIVE_PATH" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$ASC_KEY_PATH_EXPANDED" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
        | xcpretty
else
    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "generic/platform=iOS" \
        -archivePath "$ARCHIVE_PATH" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$ASC_KEY_PATH_EXPANDED" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID"
fi

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "ERROR: archive did not produce $ARCHIVE_PATH — check xcodebuild output above."
    exit 1
fi

echo "→ export + upload"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_PATH_EXPANDED" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"

echo "✓ Uploaded. Processing takes ~15–60 min. You'll get an email when the build is ready to select in App Store Connect."
