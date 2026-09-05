#!/bin/bash

set -euo pipefail

TAG="${1:-}"
if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: scripts/publish-release.sh v1.0.0" >&2
  exit 2
fi

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${TAG#v}"
DMG_PATH="$REPOSITORY_ROOT/dist/KAYF-Contribution-Studio-$VERSION.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"

cd "$REPOSITORY_ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: commit all changes before publishing a release" >&2
  exit 3
fi

gh auth status --hostname github.com >/dev/null

UNSIGNED_RELEASE=0
if [[ -z "${SIGN_IDENTITY:-}" || -z "${NOTARY_PROFILE:-}" ]]; then
  if [[ "${ALLOW_UNSIGNED_RELEASE:-0}" != "1" ]]; then
    echo "error: public releases require SIGN_IDENTITY and NOTARY_PROFILE" >&2
    echo "Set ALLOW_UNSIGNED_RELEASE=1 only for an explicitly unnotarized prerelease." >&2
    exit 4
  fi
  UNSIGNED_RELEASE=1
fi

"$REPOSITORY_ROOT/scripts/build-dmg.sh" "$VERSION"

if git rev-parse --verify --quiet "refs/tags/$TAG" >/dev/null; then
  if [[ "$(git rev-list -n 1 "$TAG")" != "$(git rev-parse HEAD)" ]]; then
    echo "error: $TAG exists but does not point to HEAD" >&2
    exit 5
  fi
else
  git tag -a "$TAG" -m "KAYF Contribution Studio $VERSION"
fi

git push origin HEAD
git push origin "$TAG"

release_options=(
  --verify-tag
  --generate-notes
  --title "KAYF Contribution Studio $VERSION"
)
if [[ "$UNSIGNED_RELEASE" == "1" ]]; then
  release_options+=(--prerelease)
else
  release_options+=(--latest)
fi

gh release create "$TAG" \
  "$DMG_PATH#KAYF Contribution Studio $VERSION" \
  "$CHECKSUM_PATH#SHA-256 checksum" \
  "${release_options[@]}"

echo "Published: https://github.com/vKAYFv/KAYF-Contribution-Studio/releases/tag/$TAG"
