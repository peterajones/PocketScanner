#!/usr/bin/env python3
"""Verify App Store metadata files exist and fit ASC's character limits.

Usage:  python3 scripts/verify-metadata.py
Exit 0 = pass, 1 = failures found.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "marketing/app-store-metadata"
LOCALES = ["en", "es", "es-MX", "fr", "fr-CA", "de", "it"]
LIMITS = {
    "subtitle.txt": 30,
    "promotional_text.txt": 170,
    "keywords.txt": 100,
    "description.txt": 4000,
    "whats_new.txt": 4000,
}


def main():
    failures = []
    for locale in LOCALES:
        d = META / locale
        if not d.is_dir():
            failures.append(f"{locale}: directory missing")
            continue
        for name, limit in LIMITS.items():
            f = d / name
            if not f.exists():
                failures.append(f"{locale}/{name}: missing")
                continue
            # ASC counts the visible text; ignore one trailing newline.
            n = len(f.read_text().rstrip("\n"))
            if n == 0:
                failures.append(f"{locale}/{name}: empty")
            elif n > limit:
                failures.append(
                    f"{locale}/{name}: {n} chars, limit {limit} "
                    f"(over by {n - limit})")
            else:
                print(f"  ok  {locale}/{name}: {n}/{limit}")
    if failures:
        print(f"\nFAIL — {len(failures)} problem(s):")
        for f in failures:
            print("  " + f)
        return 1
    print(f"\nPASS — {len(LOCALES)} locales within ASC limits")
    return 0


if __name__ == "__main__":
    sys.exit(main())
