#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 path/to/Corbie.app" >&2
    exit 2
fi

APP="${1%/}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cat >"$work/markers" <<'MARKERS'
ScreenshotMode
screenshotMode
screenshot-mode
DemoAssets
Alex
Nora
Book the vet
Pick up the parcel
Change the light bulbs
Call about the boiler
Renew the car insurance
Return the library books
Wool coat
Ceramics class
Noise-cancelling headphones
Linen bedding set
Japan, October
New sofa
Rainy day
wool-coat
ceramics-class
noise-cancelling-headphones
linen-bedding-set
For February 14
For our anniversary
chops the onions
nobody asks me anything
DebugMenuView
DebugMenuEntitlementRow
DebugRefundRequest
DebugNotificationsSections
DebugLaunch
DebugEntitlementOverride
DebugMonetizationOverride
-corbie-reset-store
-corbie-entitlement
-corbie-monetization
corbie.debug.entitlement
corbie.debug.monetization
intro_offer_used
debug.simulator.user
Follow the real subscription
Clear the entitlement cache
monetization follows the server
storage not probed yet
no verified subscription transaction
Forget the joint action flag
Delete this space's share on the server
settings.developer
onboarding.debug.signin
continue without Apple ID
MARKERS

if printf '%s\n' "$APP" "$ROOT" | grep -qF -f "$work/markers"; then
    echo "error: scan_debug_markers: $APP or $ROOT contains a marker, and build paths end up in the binary" >&2
    exit 2
fi

if [ ! -d "$APP" ]; then
    echo "error: scan_debug_markers: no app at $APP" >&2
    exit 1
fi

find "$APP" -type f | sort >"$work/files"
: >"$work/binaries"
while IFS= read -r file; do
    if file -b "$file" | grep -q 'Mach-O'; then
        printf '%s\n' "$file" >>"$work/binaries"
    fi
done <"$work/files"

binary_count="$(wc -l <"$work/binaries" | tr -d ' ')"
file_count="$(wc -l <"$work/files" | tr -d ' ')"
marker_count="$(wc -l <"$work/markers" | tr -d ' ')"
if [ "$binary_count" -eq 0 ]; then
    echo "error: scan_debug_markers: no Mach-O file found in $APP" >&2
    exit 1
fi

: >"$work/found"
while IFS= read -r binary; do
    strings -a "$binary" >"$work/text" 2>/dev/null || true
    nm -a "$binary" >>"$work/text" 2>/dev/null || true
    while IFS= read -r marker; do
        hits="$(grep -cF -- "$marker" "$work/text" || true)"
        if [ "$hits" -gt 0 ]; then
            printf '  %s: "%s" x%s\n' "${binary#"$APP"/}" "$marker" "$hits" >>"$work/found"
            grep -F -- "$marker" "$work/text" | head -n 3 | sed 's/^/      /' >>"$work/found"
        fi
    done <"$work/markers"
done <"$work/binaries"

python3 - "$APP" "$work/markers" "$work/files" >>"$work/found" <<'PY'
import sys

app, markers_path, files_path = sys.argv[1:4]
markers = [line for line in open(markers_path, encoding="utf-8").read().splitlines() if line]
encodings = ("utf-8", "utf-16-le", "utf-16-be")
needles = [(marker, encoding, marker.encode(encoding)) for marker in markers for encoding in encodings]
for path in open(files_path, encoding="utf-8").read().splitlines():
    with open(path, "rb") as handle:
        content = handle.read()
    for marker, encoding, needle in needles:
        if needle in content:
            print(f'  content: {path[len(app) + 1:]}: "{marker}" in {encoding}')
PY

sed "s|^$APP/||" "$work/files" | grep -F -f "$work/markers" | sed 's/^/  file name: /' >>"$work/found" || true

if [ -s "$work/found" ]; then
    echo "error: scan_debug_markers: $APP carries debug-only code, developer tools or demo data:" >&2
    cat "$work/found" >&2
    exit 1
fi

echo "scan_debug_markers: ok, none of $marker_count markers in $binary_count binaries (strings, nm), in the bytes of $file_count files (UTF-8, UTF-16) or in their names"
