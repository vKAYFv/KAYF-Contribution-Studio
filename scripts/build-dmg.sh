#!/bin/bash

set -euo pipefail

VERSION="${1:-1.0.0}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version must look like 1.0.0" >&2
  exit 2
fi

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIRECTORY="$REPOSITORY_ROOT/dist"
WORK_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/kayf-release.XXXXXX")"
DERIVED_DATA="$WORK_DIRECTORY/DerivedData"
STAGING_DIRECTORY="$WORK_DIRECTORY/dmg"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/KAYFContributionStudio.app"
STAGED_APP="$STAGING_DIRECTORY/KAYF Contribution Studio.app"
DMG_PATH="$DIST_DIRECTORY/KAYF-Contribution-Studio-$VERSION.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"

cleanup() {
  if [[ "$WORK_DIRECTORY" == *"/kayf-release."* ]]; then
    rm -rf "$WORK_DIRECTORY"
  fi
}
trap cleanup EXIT

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

mkdir -p "$DIST_DIRECTORY" "$STAGING_DIRECTORY"

echo "Building KAYF Contribution Studio ${VERSION}…"
xcodebuild build \
  -project "$REPOSITORY_ROOT/KAYFContributionStudio.xcodeproj" \
  -scheme KAYFContributionStudio \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" \
  CODE_SIGNING_ALLOWED=NO

test -d "$BUILT_APP"
ditto "$BUILT_APP" "$STAGED_APP"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  echo "Signing with Developer ID: $SIGN_IDENTITY"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$STAGED_APP"
else
  echo "warning: no SIGN_IDENTITY supplied; creating an ad-hoc signed development build" >&2
  codesign --force --deep --sign - "$STAGED_APP"
fi
codesign --verify --deep --strict --verbose=2 "$STAGED_APP"

ln -s /Applications "$STAGING_DIRECTORY/Applications"
hdiutil create \
  -volname "KAYF Contribution Studio" \
  -srcfolder "$STAGING_DIRECTORY" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov "$DMG_PATH"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
  codesign --verify --verbose=2 "$DMG_PATH"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  if [[ -z "${SIGN_IDENTITY:-}" ]]; then
    echo "error: NOTARY_PROFILE requires SIGN_IDENTITY" >&2
    exit 3
  fi
  echo "Submitting DMG for Apple notarization…"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
fi

(
  cd "$DIST_DIRECTORY"
  shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

echo "Created: $DMG_PATH"
echo "Checksum: $CHECKSUM_PATH"
