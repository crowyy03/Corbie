#!/bin/sh
set -eu

DEVICE="${CORBIE_SIMULATOR_UDID:-ED45E015-BB47-42D1-86A4-015394273953}"
BUNDLE_ID="app.corbie"
ARGUMENT="-corbie-screenshot-mode"

usage() {
    echo "usage: $0 on|off" >&2
    echo "  on   9:41 status bar, full battery and signal, app relaunched into screenshot mode" >&2
    echo "  off  status bar back to normal, app relaunched on your real space" >&2
    exit 2
}

[ "$#" -eq 1 ] || usage
mode="$1"
case "$mode" in
    on | off) ;;
    *) usage ;;
esac

xcrun simctl bootstatus "$DEVICE" -b

if [ "$mode" = "on" ]; then
    xcrun simctl status_bar "$DEVICE" override \
        --time "9:41" \
        --batteryState discharging \
        --batteryLevel 100 \
        --wifiMode active \
        --wifiBars 3 \
        --cellularMode active \
        --cellularBars 4 \
        --dataNetwork wifi
    echo "status bar: 9:41, battery 100 not charging, wifi 3 bars, cellular 4 bars"
else
    xcrun simctl status_bar "$DEVICE" clear
    echo "status bar: cleared"
fi

if ! xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1; then
    echo "$BUNDLE_ID is not installed on $DEVICE; build and run it from Xcode first" >&2
    exit 1
fi

xcrun simctl launch --terminate-running-process "$DEVICE" "$BUNDLE_ID" "$ARGUMENT" "$mode"
echo "screenshot mode: $mode"
