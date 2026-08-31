#!/usr/bin/env python3
"""Composite localized captions onto the base captures for a language.

Reads uncaptioned captures from v<VERSION>/Base/<lang>/<shot>.png, overlays the
text in captions/<lang>.tsv, and writes the finished set to
v<VERSION>/Stills/<lang>/<shot>.png (flat — no `captioned/` subdirectory).

The scan shot has no simulator camera, so every language reuses the shared framed
2a frame; it carries almost no app text, only the caption differs. It was shot #4
through v3.2 and is slot #1 from v3.4 — see SHARED_FRAME_SHOT.

Which shots get rendered comes from the manifest, not a fixed range: a shot that is
copied forward from a previous release rather than re-rendered simply has no row.

Manifest columns: shot, line1, line2, top, fs1, fs2, band, color
  band  optional CSS background (e.g. the black scan-shot banner); empty = none
  color optional text color; empty = default navy

Run from the repo root:
    python3 marketing/app-preview/render-captions.py de it
    python3 marketing/app-preview/render-captions.py --version 3.4 en es fr de it
"""
import argparse
import csv
import os
import subprocess
import sys

APP = "marketing/app-preview"
SCAN2A = f"{APP}/v2.8/Stills/2a. Scanning a Document.png"
CAPTION = f"{APP}/caption.sh"
# Apple's iPhone bezel with a transparent screen cutout. caption.sh drops the raw
# capture into the cutout and composites this over it, which is what
# marketing/templates/README.md previously described as a manual Krita step.
CHROME = "marketing/templates/PocketScannerAppPreviewChrome1290x2796.png"

# Retired after v3.1, restored for v3.2. Two things changed with the v3.1 asset
# restructure and are baked in here:
#   * output is FLAT at v<ver>/Stills/<lang>/ — the old `captioned/` subdir is gone
#   * bases live in their own v<ver>/Base/<lang>/ tree as plain <shot>.png, rather
#     than sharing the Stills dir under a "<lang><shot> Name.png" naming scheme
# The old BASE_LANG map (es-MX->es, fr-CA->fr) is also gone: those were
# metadata-only regional variants riding their parent's captures. v3.2 adds two
# FULL languages, each with its own forced-locale screenshots.


# The scan shot has no per-language capture — there is no simulator camera, so every
# language shares the one framed 2a frame. It was shot 4 through v3.2; the v3.4 reorder
# moves it to slot 1. Keep this as a constant: it is also the shot that must NOT be
# re-framed, and the two facts have to stay in step.
SHARED_FRAME_SHOT = 1


def base_for(bases_dir, lang, shot):
    """Path to the uncaptioned capture for one shot, or None if missing."""
    if shot == SHARED_FRAME_SHOT:
        return SCAN2A
    path = f"{bases_dir}/{lang}/{shot}.png"
    return path if os.path.exists(path) else None


def manifest(lang):
    with open(f"{APP}/captions/{lang}.tsv") as f:
        # restval="" so rows that omit the trailing band/color columns yield ""
        # rather than None, which caption.sh cannot accept as an argument.
        return {int(r["shot"]): r for r in csv.DictReader(f, delimiter="\t", restval="")}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("langs", nargs="+", help="language codes, e.g. de it")
    ap.add_argument("--version", default="3.2",
                    help="release folder under marketing/app-preview (default 3.2)")
    args = ap.parse_args()

    bases_dir = f"{APP}/v{args.version}/Base"
    stills_dir = f"{APP}/v{args.version}/Stills"
    missing = 0

    for lang in args.langs:
        caps = manifest(lang)
        outdir = f"{stills_dir}/{lang}"
        os.makedirs(outdir, exist_ok=True)
        print(f"== {lang} -> {outdir} ==")
        # Driven by the manifest, not a hardcoded range: the shot count changed with the
        # v3.4 reorder (8 -> 7), and shots that are copied forward rather than rendered
        # simply have no row. Adding or dropping a shot is a TSV edit, nothing more.
        for shot in sorted(caps):
            base = base_for(bases_dir, lang, shot)
            if not base:
                print(f"  #{shot}: NO BASE at {bases_dir}/{lang}/{shot}.png (skipped)")
                missing += 1
                continue
            c = caps[shot]
            # The shared frame is ALREADY framed — passing the bezel again would
            # double-frame it. Every other shot is a raw simulator capture and needs
            # the chrome.
            chrome = "" if shot == SHARED_FRAME_SHOT else CHROME
            subprocess.run(
                [CAPTION, base, f"{outdir}/{shot}.png", c["line1"], c["line2"],
                 c["top"], c["fs1"], c["fs2"], c.get("band", ""), c.get("color", ""),
                 chrome],
                check=True, stdout=subprocess.DEVNULL)
            print(f"  #{shot}: {os.path.basename(base)}{'' if shot == SHARED_FRAME_SHOT else '  [framed]'}")

    if missing:
        print(f"\n{missing} shot(s) had no base capture — the set is INCOMPLETE.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
