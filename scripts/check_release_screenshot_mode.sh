#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

DERIVED="${CORBIE_RELEASE_CHECK_DERIVED_DATA:-/tmp/corbie-dd-release-check}"
APP="$DERIVED/Build/Products/Release-iphonesimulator/Corbie.app"
LOG="$DERIVED/release-build.log"

mkdir -p "$DERIVED"
echo "building Release for the generic iOS Simulator into $DERIVED"
if ! xcodebuild -project Corbie.xcodeproj -scheme Corbie -configuration Release \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DERIVED" build >"$LOG" 2>&1; then
    tail -n 40 "$LOG" >&2
    echo "check_release_screenshot_mode: the Release build failed, full log in $LOG" >&2
    exit 1
fi

python3 -c 'import json;p="Corbie/Resources/Localizable.xcstrings";d=json.load(open(p,encoding="utf-8"));open(p,"w",encoding="utf-8").write(json.dumps(d,ensure_ascii=False,indent=2)+"\n")'

if ! grep -q 'scan_screenshot_mode_markers: ok' "$LOG"; then
    echo "check_release_screenshot_mode: the Release build did not run the marker scan phase, full log in $LOG" >&2
    exit 1
fi

scripts/scan_screenshot_mode_markers.sh "$APP"
