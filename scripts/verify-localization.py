#!/usr/bin/env python3
"""Verify String Catalog completeness for every shipped language.

Checks, for both Localizable.xcstrings and InfoPlist.xcstrings:
  1. every key has a localization for every required language
  2. plural keys carry BOTH 'one' and 'other' variations per language
  3. no localized value is empty or whitespace-only
  4. no localized value is byte-identical to the English key unless it is
     explicitly allowlisted (catches copy-paste and untranslated leakage)

Usage:  python3 scripts/verify-localization.py [lang ...]
        (no args = check every language in REQUIRED)
Exit 0 = pass, 1 = failures found.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOGS = [
    ROOT / "DocumentScanner/DocumentScanner/Localizable.xcstrings",
    ROOT / "DocumentScanner/DocumentScanner/InfoPlist.xcstrings",
]
REQUIRED = ["es", "fr", "de", "it"]

# Keys exempt from the whole check: source-language-only bundle metadata.
EXEMPT_KEYS = {"CFBundleDisplayName", "CFBundleName"}

# Values that are legitimately identical to English, per language. Anything
# identical and NOT listed here fails — that forces a conscious decision
# rather than letting an untranslated string slip through.
# "US Letter" and "A4" are international paper-size names, not words: they are
# written identically in every language this app ships, and Apple leaves them
# untranslated too. Listed for all four rather than per-language because the
# reason is the same everywhere.
PAPER_SIZES = {"US Letter", "A4"}

IDENTICAL_OK = {
    "es": {" ", "%lld", "%@  %@", "Color", "OK"} | PAPER_SIZES,
    "fr": {" ", "%lld", "%@  %@", "Date", "Format", "OK", "Photo",
           "Signature", "Version"} | PAPER_SIZES,
    # German: "Filter" (der Filter), "Format" (das Format), "Name" (der Name)
    # and "Version" are the same word in German — "Version" is confirmed by
    # Apple's own UIKitCore de.lproj. "in %@" is the preposition "in", also
    # identical. None of these are untranslated oversights.
    "de": {" ", "%lld", "%@  %@", "OK", "Filter", "Format", "Name", "Version",
           "in %@"} | PAPER_SIZES,
    # Italian: "Privacy" is the word Apple uses in Italian too, and "in %@"
    # is the preposition "in" — identical, not untranslated.
    "it": {" ", "%lld", "%@  %@", "OK", "Privacy", "in %@"} | PAPER_SIZES,
}


def check_catalog(path, languages):
    failures = []
    data = json.loads(path.read_text())
    name = path.name
    for key, entry in data["strings"].items():
        if key in EXEMPT_KEYS:
            continue
        locs = entry.get("localizations", {})
        is_plural = "variations" in json.dumps(entry)
        for lang in languages:
            loc = locs.get(lang)
            if loc is None:
                failures.append(f"{name}: [{lang}] MISSING  {key!r}")
                continue
            if is_plural:
                plural = loc.get("variations", {}).get("plural", {})
                for form in ("one", "other"):
                    unit = plural.get(form, {}).get("stringUnit", {})
                    if not unit.get("value", "").strip():
                        failures.append(
                            f"{name}: [{lang}] plural '{form}' empty  {key!r}")
                continue
            value = loc.get("stringUnit", {}).get("value", "")
            if not value.strip() and key.strip():
                failures.append(f"{name}: [{lang}] EMPTY    {key!r}")
            elif value == key and value not in IDENTICAL_OK.get(lang, set()):
                failures.append(
                    f"{name}: [{lang}] UNTRANSLATED (identical to source, not "
                    f"allowlisted)  {key!r}")
    return failures


def main():
    languages = sys.argv[1:] or REQUIRED
    unknown = [l for l in languages if l not in IDENTICAL_OK]
    if unknown:
        print(f"warning: no allowlist entry for {unknown} — identical-value "
              f"check will be strict for those languages")
    all_failures = []
    for path in CATALOGS:
        if not path.exists():
            print(f"error: missing catalog {path}")
            return 1
        all_failures += check_catalog(path, languages)
    if all_failures:
        print(f"FAIL — {len(all_failures)} problem(s):")
        for f in all_failures:
            print("  " + f)
        return 1
    print(f"PASS — {', '.join(languages)} complete across "
          f"{len(CATALOGS)} catalog(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
