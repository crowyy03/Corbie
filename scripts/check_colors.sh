#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

violations="$(mktemp)"
trap 'rm -f "$violations"' EXIT

palette="Packages/CorbieCore/Sources/CorbieCore/Design/Palettes.swift"

find Corbie CorbieWidgets CorbieShare CorbieTests CorbieUITests Packages/CorbieCore/Sources \
    -name '*.swift' -type f \
    ! -path '*/.build/*' \
    ! -path "$palette" -print0 |
    xargs -0 grep -nE '#[0-9A-Fa-f]{6}' /dev/null |
    sed 's/^/hex literal outside Palettes.swift: /' >>"$violations" || true

find Corbie CorbieWidgets CorbieShare Packages/CorbieCore/Sources \
    -name '*.swift' -type f \
    ! -path '*/.build/*' \
    ! -path "$palette" -print0 |
    xargs -0 grep -nE 'Color\(red:|Color\(\.sRGB|#colorLiteral|UIColor\(red:|\.accentColor' /dev/null |
    sed 's/^/raw color outside Palettes.swift: /' >>"$violations" || true

find Corbie CorbieWidgets CorbieShare Packages/CorbieCore/Sources \
    -name '*.swift' -type f \
    ! -path '*/.build/*' \
    ! -path 'CorbieWidgets/Lock/*' \
    ! -path "$palette" -print0 |
    xargs -0 grep -nE '(foregroundStyle|foregroundColor|fill|background|tint|strokeBorder|stroke|\.fill)\((Color)?\.(black|white|blue|brown|cyan|gray|green|indigo|mint|orange|pink|purple|red|teal|yellow|primary|secondary|accentColor)\b|\bColor\.(black|white|blue|brown|cyan|gray|green|indigo|mint|orange|pink|purple|red|teal|yellow|primary|secondary)\b' /dev/null |
    sed 's/^/system color in a view: /' >>"$violations" || true

if [ -s "$violations" ]; then
    echo "check_colors: failed" >&2
    cat "$violations" >&2
    exit 1
fi

echo "check_colors: ok"
