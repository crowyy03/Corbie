#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 path/to/Corbie.app" >&2
    exit 2
fi

APP="${1%/}"
bundles="$APP $(find "$APP/PlugIns" -maxdepth 1 -name '*.appex' 2>/dev/null | sort | tr '\n' ' ')"
count=0
failed=0
for bundle in $bundles; do
    families="$(plutil -extract UIDeviceFamily json -o - "$bundle/Info.plist" 2>/dev/null || echo missing)"
    count=$((count + 1))
    if [ "$families" != "[1]" ]; then
        echo "error: check_iphone_only: ${bundle#"$APP"/} has UIDeviceFamily $families, App Store Connect would ask for iPad screenshots" >&2
        failed=1
    fi
done
[ "$failed" -eq 0 ] || exit 1
echo "check_iphone_only: ok, UIDeviceFamily is [1] in $count bundles"
