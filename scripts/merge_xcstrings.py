#!/usr/bin/env python3
import json
import sys


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def merge_strings(base, ours, theirs):
    result = dict(ours)
    for key, entry in theirs.items():
        if key not in result:
            result[key] = entry
            continue
        if key in base and base[key] == result[key] and base[key] != entry:
            result[key] = entry
            continue
        merged = dict(result[key])
        merged_locs = dict(merged.get("localizations", {}))
        for lang, loc in entry.get("localizations", {}).items():
            if lang not in merged_locs:
                merged_locs[lang] = loc
        if merged_locs:
            merged["localizations"] = merged_locs
        result[key] = merged
    return dict(sorted(result.items()))


def main():
    base_path, ours_path, theirs_path = sys.argv[1:4]
    base = load(base_path) if base_path else {"strings": {}}
    ours = load(ours_path)
    theirs = load(theirs_path)
    merged = dict(ours)
    merged["strings"] = merge_strings(base.get("strings", {}), ours.get("strings", {}), theirs.get("strings", {}))
    with open(ours_path, "w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False, indent=2, sort_keys=False)
        f.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
