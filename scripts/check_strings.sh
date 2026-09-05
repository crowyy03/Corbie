#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

violations="$(mktemp)"
trap 'rm -f "$violations"' EXIT

find Corbie CorbieWidgets CorbieShare -name '*.swift' -type f -print0 |
    xargs -0 grep -nEo '(Text|Label|Button)\("[^"]*"' /dev/null |
    while IFS= read -r hit; do
        literal="${hit#*\"}"
        literal="${literal%\"}"
        if ! printf '%s' "$literal" | grep -qE '^[a-z][a-z0-9]*(\.[a-z0-9]+)+$'; then
            printf 'literal string in view: %s\n' "$hit" >>"$violations"
        fi
    done

find Corbie CorbieWidgets CorbieShare CorbieTests CorbieUITests Packages \
    -name '*.swift' -type f \
    ! -path '*/.build/*' \
    ! -path 'Packages/CorbieCore/Sources/CorbieCore/Design/*' -print0 |
    xargs -0 grep -nE '#[0-9A-Fa-f]{6}' /dev/null |
    sed 's/^/hex color outside the design tokens: /' >>"$violations" || true

if [ -s "$violations" ]; then
    echo "check_strings: failed" >&2
    cat "$violations" >&2
    exit 1
fi

echo "check_strings: ok"
