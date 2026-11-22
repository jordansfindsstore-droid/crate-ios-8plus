#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Fetch the frameworks the app builds with (libslirp and GLib, and the GPU
# stack) from the pinned release, checked against
# its SHA-256, instead of building them. Scripts/release-frameworks.sh made it
# from the build scripts' output; building them yourself gives the same files.
#
#     ./Scripts/fetch-frameworks.sh
#
# VERIFY_ATTESTATION=1 also checks, with gh, that this repository's frameworks
# workflow built the zip (the ipa workflow sets it). Override the default
# upstream repository after publishing a frameworks release from this fork.
set -euo pipefail

VERSION=frameworks-2026.11.14
SHA256=0c7d5d9527cb8b25b9a2800333e5588b61410cd3c342264037deafbdd8ecb3e7
REPOSITORY="${FRAMEWORKS_REPOSITORY:-oneamendez/crate-ios}"

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$REPO/Frameworks"
if [ "$(cat "$DEST/Frameworks.version" 2>/dev/null)" = "$VERSION" ] && [ -d "$DEST/GPU" ]; then
    echo "frameworks $VERSION already in Frameworks/"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
curl --fail --location --silent --show-error --output "$WORK/Frameworks.zip" \
    "https://github.com/$REPOSITORY/releases/download/$VERSION/Frameworks.zip"
echo "$SHA256  $WORK/Frameworks.zip" | shasum -a 256 --check --quiet
if [ "${VERIFY_ATTESTATION:-}" = 1 ]; then
    gh attestation verify "$WORK/Frameworks.zip" --repo "$REPOSITORY" \
        --signer-workflow "$REPOSITORY/.github/workflows/frameworks.yml" >/dev/null
    echo "frameworks $VERSION: attested by the frameworks workflow"
fi
ditto -x -k "$WORK/Frameworks.zip" "$WORK/out"
mkdir -p "$DEST"
for item in Slirp.xcframework GLib.xcframework Slirp.version GPU; do
    rm -rf "$DEST/$item"
    mv "$WORK/out/Frameworks/$item" "$DEST/"
done
echo "$VERSION" > "$DEST/Frameworks.version"
echo "frameworks $VERSION in Frameworks/"
