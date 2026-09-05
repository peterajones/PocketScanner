#!/usr/bin/env python3
"""Verify String Catalog completeness for every shipped language.

Checks, for both Localizable.xcstrings and InfoPlist.xcstrings:
  1. every key has a localization for every required language
  2. plural keys carry BOTH 'one' and 'other' variations per language
  3. no localized value is empty or whitespace-only
  4. no localized value is byte-identical to the English key unless it is
     explicitly allowlisted (catches copy-paste and untranslated leakage)
  5. every String(localized:) key in the Swift sources EXISTS in the catalog

Check 5 was added 2026-09-04 after "Purple" shipped untranslated in five
languages. Checks 1-4 all walk keys that are IN the catalog and verify their
languages -- none of them asks the reverse question, so a key the code requests
but the catalog lacks was invisible. The string simply falls back to its English
source at runtime, silently, in every language.

Usage:  python3 scripts/verify-localization.py [lang ...]
        (no args = check every language in REQUIRED)
Exit 0 = pass, 1 = failures found.
"""
import json
import re
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
    # "Graphite" is the same word in French (le graphite), and Apple uses it
    # untranslated for the Mac finish of that name.
    "fr": {" ", "%lld", "%@  %@", "Date", "Format", "OK", "Photo",
           "Signature", "Signatures", "Version", "Graphite"} | PAPER_SIZES,
    # German: "Filter" (der Filter), "Format" (das Format), "Name" (der Name)
    # and "Version" are the same word in German — "Version" is confirmed by
    # Apple's own UIKitCore de.lproj. "in %@" is the preposition "in", also
    # identical. "System" (das System) likewise, and it is what Apple uses in the
    # German Settings app for the follow-the-system appearance option. None of
    # these are untranslated oversights.
    "de": {" ", "%lld", "%@  %@", "OK", "Filter", "Format", "Name", "Version",
           "in %@", "System"} | PAPER_SIZES,
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


SWIFT_ROOT = ROOT / "DocumentScanner/DocumentScanner"

# `String(localized: "...")` with a literal. Interpolated keys are skipped: they resolve to
# a format string in the catalog (e.g. "\(n) pages" -> "%lld pages") that cannot be
# recovered from the source text.
LOCALIZED_CALL = re.compile(r'String\(localized:\s*"((?:[^"\\]|\\.)*)"')


def check_swift_keys_exist():
    """Every String(localized:) key in Swift must exist in Localizable.xcstrings.

    The other checks all start from the catalog and verify its contents. This one starts
    from the CODE, which is the only way to catch a key that was never added -- the case
    that let "Purple" ship as English in five languages.
    """
    catalog_path = ROOT / "DocumentScanner/DocumentScanner/Localizable.xcstrings"
    if not catalog_path.exists():
        return [f"missing catalog {catalog_path}"]
    keys = set(json.loads(catalog_path.read_text())["strings"])

    failures = []
    for swift in sorted(SWIFT_ROOT.rglob("*.swift")):
        for key in LOCALIZED_CALL.findall(swift.read_text()):
            if "\\(" in key:      # interpolated -- see LOCALIZED_CALL
                continue
            if key not in keys:
                failures.append(
                    f"{swift.name}: NOT IN CATALOG (falls back to English "
                    f"in every language)  {key!r}")
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
    all_failures += check_swift_keys_exist()
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
