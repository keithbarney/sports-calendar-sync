#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
PROJECT="$ROOT_DIR/SportsCalendarSync.xcodeproj"
SCHEME="SportsCalendarSync"
BUILD_ROOT="$ROOT_DIR/build/release"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
ARCHIVE_PATH="$BUILD_ROOT/SportsCalendarSync.xcarchive"
EXPORT_PATH="$BUILD_ROOT/export"
EXPORT_OPTIONS="$ROOT_DIR/config/ExportOptions.plist"
MINIMUM_XCODE_MAJOR=26

COMMAND="${1:-}"
shift || true

BUILD_NUMBER="${RELEASE_BUILD_NUMBER:-}"
BUILD_NUMBER_ARGUMENT=0
CONFIRM_UPLOAD=0

usage() {
    cat <<'USAGE'
Usage:
  ./scripts/release.sh verify
  ./scripts/release.sh archive [--build-number NUMBER]
  ./scripts/release.sh upload [--build-number NUMBER] [--confirm-upload]

Commands:
  verify   Regenerate the Xcode project and run an unsigned iOS device build.
  archive  Run verification, then create a signed App Store archive.
  upload   Run verification and archive, then upload to App Store Connect.
           Upload does not submit the app version to App Review.

Options:
  --build-number NUMBER  Override the automatic UTC epoch build number.
  --confirm-upload       Required when stdin is non-interactive.

Environment:
  APPSTORE_ENV_FILE      Credentials file path. Defaults to:
                         ~/.config/sports-calendar-sync/appstore.env
  RELEASE_BUILD_NUMBER   Alternative build-number override.
  DEVELOPER_DIR          Xcode selection override.
USAGE
}

log() {
    printf '→ %s\n' "$*"
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

check_xcode_version() {
    local version
    local major
    local sdk_version
    local sdk_major
    local developer_path
    version="$(xcodebuild -version | awk 'NR == 1 { print $2 }')"
    major="${version%%.*}"

    case "$major" in
        ''|*[!0-9]*)
            fail "Could not determine the selected Xcode version."
            ;;
    esac

    if [ "$major" -lt "$MINIMUM_XCODE_MAJOR" ]; then
        fail "Xcode $MINIMUM_XCODE_MAJOR or newer is required; selected version is $version."
    fi

    sdk_version="$(xcrun --sdk iphoneos --show-sdk-version 2>/dev/null)" ||
        fail "The selected Xcode does not have an iOS device SDK installed."
    sdk_major="${sdk_version%%.*}"
    case "$sdk_major" in
        ''|*[!0-9]*)
            fail "Could not determine the selected iOS SDK version."
            ;;
    esac
    if [ "$sdk_major" -lt "$MINIMUM_XCODE_MAJOR" ]; then
        fail "iOS SDK $MINIMUM_XCODE_MAJOR or newer is required; selected SDK is $sdk_version."
    fi

    developer_path="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null || printf 'unknown')}"
    log "Using Xcode $version with iOS SDK $sdk_version from $developer_path"
}

check_tools() {
    require_command git
    require_command plutil
    require_command realpath
    require_command xcodebuild
    require_command xcodegen
    require_command xcrun
    check_xcode_version
}

preflight() {
    local sensitive_files

    log "Checking release configuration"
    [ -f "$EXPORT_OPTIONS" ] || fail "Missing export settings at $EXPORT_OPTIONS."
    plutil -lint \
        "$EXPORT_OPTIONS" \
        "$ROOT_DIR/SportsCalendarSync/Info.plist" \
        "$ROOT_DIR/SportsCalendarSyncWidget/Info.plist" \
        "$ROOT_DIR/SportsCalendarSync/PrivacyInfo.xcprivacy" \
        >/dev/null

    sensitive_files="$(git -C "$ROOT_DIR" ls-files -- \
        '*.p8' '*.p12' '*.mobileprovision' '.env.appstore')"
    if [ -n "$sensitive_files" ]; then
        printf '%s\n' "$sensitive_files" >&2
        fail "App Store credentials or signing files must not be tracked by Git."
    fi
}

generate_project() {
    log "Generating Xcode project"
    (
        cd "$ROOT_DIR"
        xcodegen generate
    )
}

run_xcodebuild() {
    if command -v xcpretty >/dev/null 2>&1; then
        "$@" | xcpretty
    else
        "$@"
    fi
}

verify() {
    check_tools
    preflight
    generate_project

    log "Building unsigned iOS app"
    run_xcodebuild xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -derivedDataPath "$DERIVED_DATA" \
        CODE_SIGNING_ALLOWED=NO \
        build

    log "Verification passed"
}

check_release_worktree() {
    local status
    status="$(git -C "$ROOT_DIR" status --porcelain --untracked-files=normal)"
    if [ -n "$status" ]; then
        printf '%s\n' "$status" >&2
        fail "Release archives require a clean Git worktree."
    fi
}

resolve_build_number() {
    if [ -z "$BUILD_NUMBER" ]; then
        BUILD_NUMBER="$(date -u +%s)"
    fi

    case "$BUILD_NUMBER" in
        ''|*[!0-9.]*|.*|*.|*..*)
            fail "Build number must contain one to three period-separated integers."
            ;;
    esac

    local components
    components="$(printf '%s' "$BUILD_NUMBER" | awk -F. '{ print NF }')"
    if [ "$components" -gt 3 ]; then
        fail "Build number must contain no more than three integers."
    fi
}

load_appstore_credentials() {
    local env_file
    local env_file_resolved
    local key_path_resolved
    local external_env_file
    external_env_file="$HOME/.config/sports-calendar-sync/appstore.env"
    env_file="${APPSTORE_ENV_FILE:-$external_env_file}"

    if [ -f "$ROOT_DIR/.env.appstore" ]; then
        fail "Move the legacy .env.appstore to $external_env_file before archiving."
    fi

    if [ ! -f "$env_file" ]; then
        fail "Credentials file not found at $env_file. See config/appstore.env.example."
    fi

    env_file_resolved="$(realpath "$env_file")"
    case "$env_file_resolved" in
        "$ROOT_DIR"|"$ROOT_DIR"/*)
            fail "The App Store credentials file must be stored outside the repository."
            ;;
    esac

    # The credentials file is user-owned shell syntax and must never be committed.
    set -o allexport
    # shellcheck disable=SC1090
    source "$env_file"
    set +o allexport

    : "${ASC_KEY_ID:?ASC_KEY_ID is required in the credentials file}"
    : "${ASC_ISSUER_ID:?ASC_ISSUER_ID is required in the credentials file}"
    : "${ASC_KEY_PATH:?ASC_KEY_PATH is required in the credentials file}"

    ASC_KEY_PATH_EXPANDED="${ASC_KEY_PATH/#\$HOME/$HOME}"
    ASC_KEY_PATH_EXPANDED="${ASC_KEY_PATH_EXPANDED/#\~/$HOME}"
    if [ ! -f "$ASC_KEY_PATH_EXPANDED" ]; then
        fail "App Store Connect key file not found at $ASC_KEY_PATH_EXPANDED."
    fi
    key_path_resolved="$(realpath "$ASC_KEY_PATH_EXPANDED")"
    case "$key_path_resolved" in
        "$ROOT_DIR"|"$ROOT_DIR"/*)
            fail "The App Store Connect key must be stored outside the repository."
            ;;
    esac
    ASC_KEY_PATH_EXPANDED="$key_path_resolved"
}

archive() {
    check_release_worktree
    resolve_build_number
    load_appstore_credentials

    ARCHIVE_PATH="$BUILD_ROOT/SportsCalendarSync-$BUILD_NUMBER.xcarchive"
    EXPORT_PATH="$BUILD_ROOT/export-$BUILD_NUMBER"

    log "Archiving build $BUILD_NUMBER"
    mkdir -p "$BUILD_ROOT"
    rm -rf -- "$ARCHIVE_PATH" "$EXPORT_PATH"
    run_xcodebuild xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -archivePath "$ARCHIVE_PATH" \
        -derivedDataPath "$DERIVED_DATA" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$ASC_KEY_PATH_EXPANDED" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
        CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

    [ -d "$ARCHIVE_PATH" ] || fail "Archive was not created at $ARCHIVE_PATH."
    printf '%s\n' "$BUILD_NUMBER" > "$BUILD_ROOT/build-number.txt"
    log "Archive created at $ARCHIVE_PATH"
}

confirm_upload() {
    if [ "$CONFIRM_UPLOAD" -eq 1 ]; then
        return
    fi

    if [ ! -t 0 ]; then
        fail "Upload requires --confirm-upload when stdin is non-interactive."
    fi

    printf '%s\n' "Before uploading, confirm the version, privacy answers, screenshots,"
    printf '%s\n' "release notes, export compliance, and App Store metadata are current."
    printf 'Upload build %s to App Store Connect? [y/N] ' "$BUILD_NUMBER"
    read -r answer
    case "$answer" in
        y|Y|yes|YES)
            ;;
        *)
            fail "Upload cancelled."
            ;;
    esac
}

upload() {
    confirm_upload

    log "Exporting and uploading build $BUILD_NUMBER"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS" \
        -exportPath "$EXPORT_PATH" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$ASC_KEY_PATH_EXPANDED" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID"

    log "Upload complete; App Store Connect processing happens asynchronously"
    printf '%s\n' "No App Review submission was performed."
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --build-number)
            [ "$#" -ge 2 ] || fail "--build-number requires a value."
            BUILD_NUMBER="$2"
            BUILD_NUMBER_ARGUMENT=1
            shift 2
            ;;
        --confirm-upload)
            CONFIRM_UPLOAD=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "Unknown option: $1"
            ;;
    esac
done

case "$COMMAND" in
    verify)
        [ "$BUILD_NUMBER_ARGUMENT" -eq 0 ] ||
            fail "--build-number is only valid with archive or upload."
        [ "$CONFIRM_UPLOAD" -eq 0 ] ||
            fail "--confirm-upload is only valid with upload."
        ;;
    archive)
        [ "$CONFIRM_UPLOAD" -eq 0 ] ||
            fail "--confirm-upload is only valid with upload."
        ;;
esac

case "$COMMAND" in
    verify)
        verify
        ;;
    archive)
        verify
        archive
        ;;
    upload)
        verify
        archive
        upload
        ;;
    -h|--help|help|'')
        usage
        ;;
    *)
        usage >&2
        fail "Unknown command: $COMMAND"
        ;;
esac
