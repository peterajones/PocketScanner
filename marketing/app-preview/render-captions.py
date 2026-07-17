#!/usr/bin/env python3
"""Composite localized captions onto the base captures for a language.

Maps the base filenames (en: "N. Name.png"; es/fr: "<lang>N[.] Name.png") to
captions/<lang>.tsv and writes v3.0/Stills/<lang>/captioned/<shot>.png. The scan
shot (#4) reuses the uncaptioned 2a frame for every non-en language.

Manifest columns: shot, line1, line2, top, fs1, fs2, band, color
  band  optional CSS background (e.g. the black scan-shot banner); empty = none
  color optional text color; empty = default navy

Run from the repo root:  python3 marketing/app-preview/render-captions.py es fr
"""
import subprocess, glob, os, csv, sys

APP = "marketing/app-preview"
V3 = f"{APP}/v3.0/Stills"
SCAN2A = f"{APP}/v2.8/Stills/2a. Scanning a Document.png"
CAPTION = f"{APP}/caption.sh"

def base_for(lang, shot):
    if shot == 4 and lang != "en":
        return SCAN2A
    pat = f"{V3}/en/{shot}. *.png" if lang == "en" else f"{V3}/{lang}/{lang}{shot}*.png"
    hits = sorted(glob.glob(pat))
    return hits[0] if hits else None

def manifest(lang):
    with open(f"{APP}/captions/{lang}.tsv") as f:
        return {int(r["shot"]): r for r in csv.DictReader(f, delimiter="\t")}

for lang in (sys.argv[1:] or ["es"]):
    caps = manifest(lang)
    outdir = f"{V3}/{lang}/captioned"
    os.makedirs(outdir, exist_ok=True)
    print(f"== {lang} ==")
    for shot in range(1, 9):
        base = base_for(lang, shot)
        if not base or not os.path.exists(base):
            print(f"  #{shot}: NO BASE (skipped)")
            continue
        c = caps[shot]
        subprocess.run(
            [CAPTION, base, f"{outdir}/{shot}.png", c["line1"], c["line2"],
             c["top"], c["fs1"], c["fs2"], c.get("band", ""), c.get("color", "")],
            check=True, stdout=subprocess.DEVNULL)
        print(f"  #{shot}: {os.path.basename(base)}")
