"""Upload an AAB to a Google Play testing track from GitHub Actions (keyless, never expires).

Canonical copy lives in Compo-CF/store-ops; each app repo carries scripts/play_upload.py (same file).
Auth: google-github-actions/auth with Workload Identity leaves ADC that impersonates
play-publisher@restaurantsfeed.iam.gserviceaccount.com. No key, no gcloud login.

  python scripts/play_upload.py --package com.compofelice.neatly --aab build/android/x.aab \
      --track internal [--notes "What's new"]

Exit 0 (with a clear message) when there is nothing to do: the versionCode is already on Play, or the
package has no Play app yet. Refuses production and the first release on a track (Console-only by
Play's own rules; see playbooks/android-ports.md and store-ops.md).
"""
import argparse
import glob
import socket
import sys

import google.auth
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

socket.setdefaulttimeout(900)  # Google processes the bundle before answering the last chunk


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--package", required=True)
    ap.add_argument("--aab", required=True, help="path or glob; must match exactly one file")
    ap.add_argument("--track", default="internal", choices=["internal", "alpha", "beta"])
    ap.add_argument("--notes", default="")
    a = ap.parse_args()

    files = glob.glob(a.aab)
    if len(files) != 1:
        sys.exit(f"--aab must match exactly one file, matched {files}")
    creds, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/androidpublisher"])
    edits = build("androidpublisher", "v3", credentials=creds, cache_discovery=False).edits()

    try:
        edit = edits.insert(packageName=a.package, body={}).execute()["id"]
    except HttpError as e:
        if e.resp.status == 404:
            print(f"::notice::{a.package} has no Play app yet; create it and do the first upload in the Console.")
            return
        raise
    committed = False
    try:
        cur = edits.tracks().get(packageName=a.package, editId=edit, track=a.track).execute()
        if not any(r.get("status") == "completed" for r in cur.get("releases", [])):
            sys.exit(f"refused: {a.track} has no completed release yet; its first release is Console-only")
        try:
            vc = edits.bundles().upload(
                packageName=a.package, editId=edit,
                media_body=MediaFileUpload(files[0], mimetype="application/octet-stream", resumable=True),
            ).execute()["versionCode"]
        except HttpError as e:
            if e.resp.status == 403 and "already been used" in str(e):
                print(f"::notice::versionCode in {files[0]} is already on Play; nothing to upload.")
                return
            raise
        rel = {"versionCodes": [str(vc)], "status": "completed"}
        if a.notes.strip():
            rel["releaseNotes"] = [{"language": "en-US", "text": a.notes.strip()[:500]}]
        edits.tracks().update(packageName=a.package, editId=edit, track=a.track,
                              body={"track": a.track, "releases": [rel]}).execute()
        edits.commit(packageName=a.package, editId=edit).execute()
        committed = True
        print(f"::notice::{a.package} versionCode {vc} -> {a.track} (completed)")
    finally:
        if not committed:
            try:
                edits.delete(packageName=a.package, editId=edit).execute()
            except HttpError:
                pass


if __name__ == "__main__":
    main()
