#!/usr/bin/env python3
"""Generate (and optionally install) a demo `signatures.dat`.

SignatureStore persists signatures as one binary property list of the Codable
`SignatureArchive` struct:

    struct SignatureArchive: Codable { var entries: [Entry] }
    struct Entry: Codable { let id: String; let pngData: Data
                            var name: String?; let createdAt: Date }

That's a plain binary plist, so we build it here from the demo PNGs — no scanning,
no per-run setup. The file lives at `<iCloud container>/Signatures/signatures.dat`
(the hidden sibling of the Documents scope the app shows in iCloud Drive).

Usage (run from the repo root):
    python3 marketing/app-preview/make-demo-signatures.py            # just generate
    python3 marketing/app-preview/make-demo-signatures.py --install  # generate + copy into iCloud

--install finds the app's iCloud container under
~/Library/Mobile Documents/, creates Signatures/ if needed, and copies the file in.
"""
import plistlib, uuid, datetime, os, sys, glob, shutil

SIG_DIR = "marketing/templates/sample-docs/signatures"
OUT_DIR = "marketing/app-preview/demo-signatures"
OUT = os.path.join(OUT_DIR, "signatures.dat")

# (display name, png filename) — the three fictional demo signatures, oldest first
# (createdAt increases, so "newest first" in the app shows Morgan Ellis on top).
DEMO = [
    ("Jordan Avery",  "sig-JordanAvery.png"),
    ("Taylor Morgan", "sig-TaylorMorgan.png"),
    ("Morgan Ellis",  "sig-MorganEllis.png"),
]

def build():
    base = datetime.datetime(2026, 1, 1, 12, 0, 0)
    entries = []
    for i, (name, fn) in enumerate(DEMO):
        with open(os.path.join(SIG_DIR, fn), "rb") as f:
            png = f.read()
        entries.append({
            "id": str(uuid.uuid4()),
            "pngData": png,                                   # -> plist <data>  (Swift Data)
            "name": name,                                     # -> <string>      (Swift String?)
            "createdAt": base + datetime.timedelta(days=i),   # -> <date>        (Swift Date)
        })
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT, "wb") as f:
        plistlib.dump({"entries": entries}, f, fmt=plistlib.FMT_BINARY)
    # Round-trip to confirm it's a valid binary plist with the expected shape.
    with open(OUT, "rb") as f:
        rt = plistlib.load(f)
    print(f"wrote {OUT} ({os.path.getsize(OUT)} bytes)")
    for e in rt["entries"]:
        print(f"  - {e['name']:14} id={e['id'][:8]}…  png={len(e['pngData'])}B  {e['createdAt'].date()}")

def install():
    expected = os.path.expanduser(
        "~/Library/Mobile Documents/iCloud~ca~peter-jones~DocumentScanner")
    matches = sorted(glob.glob(os.path.expanduser(
        "~/Library/Mobile Documents/*DocumentScanner*")))
    if not matches:
        sys.exit(
            "!! Can't reach the iCloud container. `~/Library/Mobile Documents/` is\n"
            "   TCC-protected, so the terminal gets 'Operation not permitted' and sees\n"
            "   nothing (the container almost certainly DOES exist).\n\n"
            "   Fix ONE of:\n"
            "   A) Finder route: Go > Go to Folder (Cmd-Shift-G), paste\n"
            f"        {expected}/\n"
            "      create a 'Signatures' folder if missing, and drag in\n"
            "        marketing/app-preview/demo-signatures/signatures.dat\n"
            "   B) Grant your terminal app Full Disk Access (System Settings > Privacy &\n"
            "      Security > Full Disk Access), then re-run this with --install.")
    container = matches[0]
    sig_dir = os.path.join(container, "Signatures")
    os.makedirs(sig_dir, exist_ok=True)          # create Signatures/ if it doesn't exist
    dest = os.path.join(sig_dir, "signatures.dat")
    shutil.copyfile(OUT, dest)
    print(f"installed -> {dest}")
    if len(matches) > 1:
        print("   (note: multiple containers matched; used the first — check if wrong:)")
        for m in matches:
            print("     " + m)

if __name__ == "__main__":
    build()
    if "--install" in sys.argv:
        install()
    else:
        print("\nNot installed. Re-run with --install to copy into your iCloud container,\n"
              "or copy the file yourself to <container>/Signatures/signatures.dat")
