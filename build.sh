#!/bin/zsh
# Builds "Monsieur Pierre.app" into build/. Requires Xcode command line tools.
# Usage: ./build.sh [version]   (or VERSION=x.y.z ./build.sh; default 1.0)
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-${VERSION:-1.0}}"

APP="build/Monsieur Pierre.app"
EXE=MonsieurPierre
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Universal binary, deployment target matching LSMinimumSystemVersion.
for arch in arm64 x86_64; do
    swiftc -O Sources/*.swift \
        -target "$arch-apple-macos11.0" \
        -o "build/$EXE-$arch" \
        -framework AppKit -framework ServiceManagement
done
lipo -create -output "$APP/Contents/MacOS/$EXE" "build/$EXE-arm64" "build/$EXE-x86_64"
rm "build/$EXE-arm64" "build/$EXE-x86_64"

cp Info.plist "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"
cp Resources/*.png Resources/icons/*.png Resources/icons/Oneko.icns "$APP/Contents/Resources/"

# Ad-hoc signature so SMAppService (launch at login, macOS 13+) works.
codesign --force -s - "$APP"

echo "Built $APP"
