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
    ! -path 'Packages/CorbieCore/Sources/CorbieCore/Design/*' \
    ! -path 'Packages/CorbieCore/Tests/CorbieCoreTests/Design*' -print0 |
    xargs -0 grep -nE '#[0-9A-Fa-f]{6}' /dev/null |
    sed 's/^/hex color outside the design tokens: /' >>"$violations" || true

python3 - "$violations" <<'PY' || printf 'localizable catalog could not be read\n' >>"$violations"
import json
import os
import re
import sys

LANGUAGES = ("de", "en", "es", "fr", "it")
REQUIRE_TRANSLATIONS = os.environ.get("CORBIE_CHECK_TRANSLATIONS") == "1"
SPECIFIER = re.compile(r"%(?:\d+\$)?(?:lld|@|%)")
BANNED = re.compile("[!—→←⇒]")

with open("Corbie/Resources/Localizable.xcstrings", encoding="utf-8") as handle:
    catalog = json.load(handle)

report = open(sys.argv[1], "a", encoding="utf-8")


def units(localization):
    if "stringUnit" in localization:
        yield "", localization["stringUnit"]
    for category, unit in localization.get("variations", {}).get("plural", {}).items():
        yield category, unit["stringUnit"]


for key, entry in sorted(catalog["strings"].items()):
    localizations = entry.get("localizations", {})
    english = localizations.get("en")
    if english is None:
        report.write(f"catalog key without english: {key}\n")
        continue
    reference = {category: sorted(SPECIFIER.findall(unit["value"])) for category, unit in units(english)}
    for language in LANGUAGES:
        localization = localizations.get(language)
        if localization is None:
            if REQUIRE_TRANSLATIONS:
                report.write(f"catalog key not translated: {key} [{language}]\n")
            continue
        found = dict(units(localization))
        if "one" in reference and not {"one", "other"} <= set(found):
            report.write(f"catalog plural needs one and other: {key} [{language}]\n")
        for category, unit in found.items():
            value = unit["value"]
            if unit.get("state") != "translated" or not value:
                if REQUIRE_TRANSLATIONS:
                    report.write(f"catalog value not translated: {key} [{language}]\n")
                continue
            if BANNED.search(value):
                report.write(f"catalog value with a banned glyph: {key} [{language}]: {value}\n")
            expected = reference.get(category, reference.get("other", reference.get("")))
            if sorted(SPECIFIER.findall(value)) != expected:
                report.write(f"catalog specifiers differ from english: {key} [{language}]: {value}\n")

report.close()
PY

if [ -s "$violations" ]; then
    echo "check_strings: failed" >&2
    cat "$violations" >&2
    exit 1
fi

echo "check_strings: ok"
