#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

SCHEME="${CORBIE_SCHEME:-Corbie}"
DESTINATION="${CORBIE_DESTINATION:-platform=iOS Simulator,name=iPhone 15}"

if ! xcodebuild -version >/dev/null 2>&1; then
    echo "xcodebuild is not usable. Install Xcode, then run: sudo xcode-select -s /Applications/Xcode.app" >&2
    exit 1
fi

if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate
fi

if [ "$#" -eq 0 ]; then
    set -- build
fi

xcodebuild -project Corbie.xcodeproj -scheme "$SCHEME" -destination "$DESTINATION" "$@"
