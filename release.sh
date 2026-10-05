#!/bin/zsh
# Builds a versioned, zipped release: ./release.sh 1.1.0
# Produces build/MonsieurPierre-<version>.zip and prints its sha256.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:?usage: ./release.sh <version>}"
./build.sh "$VERSION"

ZIP="build/MonsieurPierre-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "build/Monsieur Pierre.app" "$ZIP"

echo "Built $ZIP"
echo "sha256: $(shasum -a 256 "$ZIP" | awk '{print $1}')"
