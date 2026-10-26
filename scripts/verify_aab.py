"""Pre-upload checks for an Android App Bundle.

Every check here exists because Play rejected a real upload for it. Running
them takes a second; discovering them in the Play Console costs a rebuild and
a round trip through the release flow.

  1. Package name. Play binds the package when the Console app is created and
     accepts ANY upload -- Internal Testing counts -- not at first production
     submission. Trail Guide's is permanently
     com.compofelice.woodlandstrailguide_flutter, and a bundle built with the
     "clean" name is rejected at upload.
  2. Debug signing. android/app/build.gradle.kts falls back to the debug
     keystore when android/key.properties is absent (it is gitignored, so it
     does not exist on a fresh machine). The build SUCCEEDS and produces an
     unusable bundle -- the failure is silent until Play refuses it.
  3. READ_MEDIA_IMAGES. The app does not need it: photo attachment goes
     through the system photo picker, which returns a per-file URI grant. If a
     dependency starts merging it back in, Play's Photo and Video Permissions
     policy blocks the release behind a justification form.

Deliberately stdlib-only -- an .aab is a zip, the manifest inside is protobuf
but the strings we care about are plain ASCII in it, and a signing block is
PKCS#7 whose subject name is likewise readable. Parsing either format properly
would add dependencies for no extra certainty about these three questions.

  python scripts/verify_aab.py build/app/outputs/bundle/release/app-release.aab
  python scripts/verify_aab.py <aab> --package com.example.app --owner "Jane Dev"

Exit code 0 if every check passes, 1 otherwise.
"""
import argparse
import os
import sys
import zipfile

DEFAULT_PACKAGE = "com.compofelice.woodlandstrailguide_flutter"
DEFAULT_OWNER = "Anthony Compofelice"
MANIFEST = "base/manifest/AndroidManifest.xml"
FORBIDDEN_PERMISSIONS = ("READ_MEDIA_IMAGES",)

OK = "  PASS  "
BAD = "  FAIL  "


def check_package(manifest_bytes, expected):
    """The applicationId must match. Sub-identifiers such as
    <package>.MainActivity also appear, so the shortest com.compofelice.*
    match is the applicationId itself."""
    found = set()
    needle = b"com.compofelice."
    start = 0
    while True:
        i = manifest_bytes.find(needle, start)
        if i == -1:
            break
        j = i + len(needle)
        while j < len(manifest_bytes):
            ch = manifest_bytes[j : j + 1]
            if ch.isalnum() or ch in (b"_", b"."):
                j += 1
            else:
                break
        found.add(manifest_bytes[i:j].decode("ascii", "replace").rstrip("."))
        start = i + 1

    roots = sorted(found, key=len)
    actual = roots[0] if roots else "(none found)"
    if actual == expected:
        return True, "package {0}".format(actual)
    return False, "package is {0}, expected {1}".format(actual, expected)


def check_permissions(bundle):
    """No forbidden permission anywhere in the bundle, not just the base
    manifest -- a feature split could carry its own."""
    hits = []
    for name in bundle.namelist():
        try:
            blob = bundle.read(name)
        except Exception:
            continue
        for perm in FORBIDDEN_PERMISSIONS:
            if perm.encode("ascii") in blob:
                hits.append("{0} in {1}".format(perm, name))
    if hits:
        return False, "; ".join(hits)
    return True, "no forbidden permissions ({0} entries scanned)".format(
        len(bundle.namelist())
    )


def check_signing(bundle, owner):
    blocks = [
        n
        for n in bundle.namelist()
        if n.upper().startswith("META-INF/")
        and n.upper().endswith((".RSA", ".DSA", ".EC"))
    ]
    if not blocks:
        return False, "no signature block -- bundle is unsigned"

    for name in blocks:
        blob = bundle.read(name)
        if b"Android Debug" in blob:
            return False, "DEBUG SIGNED ({0}) -- android/key.properties is missing".format(
                name
            )
        if owner.encode("ascii") in blob:
            return True, "signed by {0} ({1})".format(owner, name)
    return False, "signed, but not by {0} -- check android/key.properties".format(owner)


def main():
    ap = argparse.ArgumentParser(description="Pre-upload checks for an .aab")
    ap.add_argument("aab", help="path to the app bundle")
    ap.add_argument("--package", default=DEFAULT_PACKAGE)
    ap.add_argument(
        "--owner",
        default=DEFAULT_OWNER,
        help="expected signing certificate owner (CN)",
    )
    args = ap.parse_args()

    if not os.path.isfile(args.aab):
        print("{0}bundle not found: {1}".format(BAD, args.aab))
        return 1

    size_mb = os.path.getsize(args.aab) / (1024.0 * 1024.0)
    print("checking {0} ({1:.1f} MB)".format(args.aab, size_mb))

    with zipfile.ZipFile(args.aab) as bundle:
        try:
            manifest = bundle.read(MANIFEST)
        except KeyError:
            print("{0}{1} missing -- is this really an app bundle?".format(BAD, MANIFEST))
            return 1

        results = [
            check_package(manifest, args.package),
            check_signing(bundle, args.owner),
            check_permissions(bundle),
        ]

    for passed, message in results:
        print("{0}{1}".format(OK if passed else BAD, message))

    if all(passed for passed, _ in results):
        print("")
        print("ready to upload")
        return 0
    print("")
    print("DO NOT UPLOAD -- see PLAY_SUBMISSION.md")
    return 1


if __name__ == "__main__":
    sys.exit(main())
