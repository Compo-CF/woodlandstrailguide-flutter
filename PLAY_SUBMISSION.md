# Google Play — closed testing submission

Everything needed to get Woodlands Trail Guide onto a Play closed-testing
track and start the mandatory 14-day clock.

Every factual claim in the Data Safety and content-rating sections below was
read out of this repo (outbound hosts, declared permissions, absence of
auth/UGC), not recalled. If the code changes, re-verify before re-declaring —
Data Safety is a binding declaration to Google, not a description.

---

## 0a. Package name is locked to `com.compofelice.woodlandstrailguide_flutter`

**Do not "clean up" the `_flutter` suffix. It cannot be changed.**

The Play Console app was created 2026-07-14 as
`com.compofelice.woodlandstrailguide_flutter` (the Flutter scaffold default)
and took a v0.1.0+1 Internal Testing upload under that name. A package name
is permanent for the life of a Play Console app.

On 2026-08-13, commit `50dddd2` renamed the package to
`com.compofelice.woodlandstrailguide`, reasoning that applicationId is
permanent "after the first Play Store submission". That reasoning was right
but the deadline was wrong: the binding event was **creating the Console app
and uploading to Internal Testing in July**, not a future production
submission. The rename was already too late when it was made.

The symptom, months later, is an upload rejected with:

> Your APK or Android App Bundle needs to have the package name
> com.compofelice.woodlandstrailguide_flutter

Reverted 2026-10-20. `applicationId`, `namespace` and `MainActivity.kt`'s
package and directory are all back on the `_flutter` name, and that is the
name this app ships under permanently. The manifest refers to the activity
relatively (`.MainActivity`), so nothing else needed touching.

Verify before every upload:

```
unzip -o -q build/app/outputs/bundle/release/app-release.aab 'base/manifest/AndroidManifest.xml' -d /tmp/aabchk
grep -ao 'com\.compofelice\.woodlandstrailguide[a-z_]*' /tmp/aabchk/base/manifest/AndroidManifest.xml | sort -u
```

Also package-bound, and worth re-checking if this ever changes again: the
Google Maps Android API key's app restriction (package name + SHA-1, in
Google Cloud) and the AdMob app's Play link. Both appear unrestricted today —
the app ran on the tablet under `_flutter` in July and on the Pixel 7a under
the short name in September, and the map worked both times.

---

## 0. Signing

**Build this on Windows.** Android needs no Mac, and the Windows machine
already has both halves of the signing material in place —
`C:/Users/anthony.compofelice/woodlandstrailguide-upload.jks` and
`android/key.properties` pointing at it. From the repo root:

```
flutter build appbundle --release
```

The rest of this section applies only if you build on the Mac instead, where
the signing material is absent and the failure is silent.

### If you build on the Mac

`flutter build appbundle --release` on the Mac will **succeed and produce an
unusable bundle** unless this is fixed first.

`android/app/build.gradle.kts` falls back to `signingConfigs.getByName("debug")`
when `android/key.properties` is absent. That file is gitignored (correctly —
it holds passwords), so it does **not** exist on the Mac. Its `storeFile` on
Windows also points at `C:/Users/anthony.compofelice/woodlandstrailguide-upload.jks`,
a path that means nothing on macOS.

Play rejects debug-signed bundles with *"You uploaded an APK or Android App
Bundle that was signed in debug mode."*

**Fix, once, on the Mac:**

1. Copy `woodlandstrailguide-upload.jks` from the Windows home directory to the
   Mac home directory. Do not regenerate it.
2. Create `android/key.properties` on the Mac with a **macOS** path:

   ```
   storePassword=<real password>
   keyPassword=<real password>
   keyAlias=upload
   storeFile=/Users/<mac-user>/woodlandstrailguide-upload.jks
   ```

**Verify before uploading** — this is the check that catches the silent
failure:

```bash
unzip -p build/app/outputs/bundle/release/app-release.aab META-INF/*.RSA \
  | keytool -printcert | grep -i "owner"
```

`Owner: CN=Android Debug` means the keystore was not picked up. Stop and fix
`key.properties`; do not upload.

---

## 1. Build and publish — one command

From a **real PowerShell prompt** (not a sandboxed shell — see below):

```powershell
cd C:\Users\anthony.compofelice\woodlandstrailguide_flutter; .\scripts\release.ps1 -Track closed
```

`scripts/release.ps1` builds, runs `scripts/verify_aab.py`, then uploads via
`~/appstoreconnect/play_publish.py` (keyless — it impersonates the publisher
service account using your gcloud ADC, because the org blocks downloadable SA
keys). The iOS equivalent is `scripts/testflight.sh` in the
`woodlandstrailguide` repo; that one is bash because it runs on the Mac, this
one is PowerShell because Android needs no macOS and `bash` is not on PATH
here.

```
scripts\release.ps1                     build, check, upload to internal
scripts\release.ps1 -Track closed       upload to the closed testing track
scripts\release.ps1 -CheckOnly          build and check, upload nothing
scripts\release.ps1 -SkipBuild          check and upload an existing .aab
scripts\release.ps1 -Track production -Rollout 0.2 -Notes "Fixes."
```

The verification step is not skippable, and every check in it is there because
Play rejected a real upload for it — wrong package name (§0a), debug signing
(§0), `READ_MEDIA_IMAGES` (§5). Two of the three fail **silently** at build
time. Run `-CheckOnly` against any bundle you did not build yourself.

**Build on Windows.** An earlier version of this runbook claimed Windows could
not run Gradle at all. That is wrong, and it cost a detour to the Mac: Gradle
fails only from a *sandboxed* shell, where `Selector.open()` cannot create its
AF_UNIX pipe and Gradle reports the misleading "Unable to establish loopback
connection". An ordinary PowerShell prompt builds fine — 1.0.0+6 was built and
signed that way on 2026-10-20. A cold build is ~15 minutes;
`lintVitalRelease` is the long tail.

Output: `build/app/outputs/bundle/release/app-release.aab`

Version lives in `pubspec.yaml` as `version: 1.0.0+N`. **Every upload needs a
higher N**, and Play has already consumed 6. Bump before rebuilding.

Note on `--release`: it adds R8 minification, and both `google_mobile_ads` and
`in_app_purchase` have a history of needing ProGuard keep rules. If the app
crashes on launch where a debug build didn't, that's the first place to look.

---

## 2. Store listing

**App name** (≤30 chars) — 25 chars, fits.

```
The Woodlands Trail Guide
```

**Short description** (≤80 chars)

```
Trail maps, routes and walk planning for The Woodlands, Texas.
```

**Release notes / "What's new"** (≤500 chars per language, en-US)

First Play release, so these introduce the app rather than describe a delta —
closed testers have seen nothing before this.

```
First release of The Woodlands Trail Guide on Android.

Maps the Township's full pathway network and plans a walk, jog or run to the
distance or time you pick — loop or out-and-back, starting from your location,
an address, or any point you tap. Turn-by-turn directions written for pathways,
with automatic rerouting if you wander off. Restrooms, parking, playgrounds and
more appear as you zoom. Finished walks are logged, and you can share a card of
the route you took.
```

**Full description** (≤4000 chars)

```
The Woodlands Trail Guide maps the full pathway network of The Woodlands,
Texas —
over 200 miles of paved pathways and natural trails — and helps you actually
use it.

PLAN A WALK, JOG OR RUN
Tell the app how far you want to go, or how long you want to be out, and it
builds a route to match. Choose a loop that comes back a different way, or a
straight out-and-back. Prefer paved pathways, or stick to natural surface
trails. Start from where you are, from an address, or from any point you tap
on the map.

TURN-BY-TURN ON THE TRAIL
Follow your route step by step with directions written for pathways, not
streets. If you wander off, the app quietly finds you a new way. If you start
somewhere off the network, it walks you to the trail first.

KNOW WHAT'S AROUND YOU
Restrooms, parking, playgrounds, water fountains, pavilions, sports fields,
picnic areas, bridges and trolley stops — mapped and filtered as you zoom, so
you see what's useful at the scale you're looking at.

TRACK WHAT YOU'VE DONE
Every finished walk is logged with distance and time. Watch your total miles,
your longest walk and your day streak build up, and collect achievements along
the way. Finish a route and you can share a card showing the path you took.

BUILT ON REAL DATA
Pathways, trails and points of interest come from The Woodlands Township's own
published GIS data, refreshed over the air — so the map reflects the network as
it actually is, not a hand-drawn approximation.

ALSO INCLUDED
• Featured walks — curated routes worth doing, with directions
• Elevation profile for any route you build
• Live weather at the trailhead
• Save favourite trails
• Share a route with someone as a link
• Photos you attach to a place stay on your device

Woodlands Trail Guide is free. An optional one-time purchase removes ads, and a
tip jar supports continued development.

Not affiliated with The Woodlands Township.
```

The final line is deliberate. The app is built on Township open data and named
after the place; saying plainly that it is not an official Township product
heads off an impersonation complaint.

---

## 3. Graphics

| Asset | Requirement | Status |
|---|---|---|
| App icon | 512×512 PNG, 32-bit | Have it (same source as the launcher icon) |
| Feature graphic | 1024×500 PNG/JPG, no alpha | **Needed — does not exist yet** |
| Phone screenshots | 2–8, min 320px, max 3840px, 16:9 or 9:16 | **Needed** |
| Tablet screenshots | Optional | Skip |

**Do not reuse the Pixel screenshots from device testing** — they came from
debug builds and show a "Test Ad" placeholder banner across the bottom. Take
fresh ones from the release build, or from a build where the ad banner is out
of frame.

Suggested five, in this order:
1. Map with the trail network and POI pins — the core value, instantly legible
2. Route planner sheet — the differentiator; distance/time, surface, shape
3. A generated route with elevation profile and segment list
4. Turn-by-turn navigation banner mid-walk
5. Achievements grid or trip-log stats

---

## 4. App content declarations

**Privacy policy URL** (required)

```
https://compo-cf.github.io/woodlandstrailguide/privacy.html
```

Live and returning 200. It was written for the iOS app — skim it for Android
accuracy before submitting, particularly that it covers AdMob and Google Play
Billing.

**Ads:** Yes, the app contains ads (AdMob banner).

**Target audience:** 18+ (or 13+). Any age band that includes children pulls
the app into Play's Families policy, which adds requirements this app does not
currently meet. The content is general-audience; the audience declaration
should not be.

**Government app:** No.
**Financial features:** None.
**Data safety:** see below.

---

## 4a. Advertising ID declaration

Required for anything targeting Android 13+, and it blocks "send for review"
until answered. Verified against the bundle: `google_mobile_ads` merges
`com.google.android.gms.permission.AD_ID` into the manifest even though the
app never declares it, so the answer is unambiguous.

- **Does your app use advertising ID?** → **Yes**
- **Why?** → tick **Advertising or marketing** only.

Every other box is a no against its own on-screen description:

| Option | Why not |
|---|---|
| App functionality | The ad ID enables no feature. Routing, search and the trip log never touch it. |
| Analytics | That means *app* analytics — "how users use your app, or how your app performs". There is no analytics SDK. Measuring **ad** performance is listed under Advertising or marketing, so AdMob is covered there. |
| Developer communications | No push, no messaging. |
| Fraud prevention, security, compliance | The example is monitoring your own app's failed logins. AdMob's invalid-traffic detection is Google's processing, not ours, and there are no accounts. |
| Personalization | Nothing in the app is customised from it; ad personalisation falls under Advertising. |
| Account management | No accounts, no sign-in. |

⚠️ **Open gap: no UMP consent flow on Android.** `main.dart` sets
`maxAdContentRating: g` and nothing else — there is no
`ConsentInformation`/`ConsentForm` call. Google requires a consent mechanism
to serve personalised ads to EEA/UK users, so either add UMP (Cosmica has a
working implementation to copy) or restrict distribution to the US. Not a
blocker for a US-only closed test, but it is a blocker for worldwide
production release.

---

## 5. Data Safety

Verified against the code: outbound hosts are `api.open-meteo.com`,
`api.open-elevation.com` and `compo-cf.github.io`; declared permissions are
`INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`,
`com.android.vending.BILLING`; there is no sign-in SDK and no user-generated
content.

Re-verified 2026-10-20 after the iOS-parity pass. Nothing in that pass changes
these answers:

- `PolygonStore` fetches `Polygons.json` from `compo-cf.github.io`, a host
  already declared.
- `in_app_review` talks to Play Services on-device and collects nothing the
  app declares.
- `WalkSummarySheet` writes a PNG to the app's own cache directory and hands
  it to the system share sheet. Nothing is uploaded; where the user sends it
  afterwards is the user's action in another app, not collection by this one.

**`READ_MEDIA_IMAGES` was removed 2026-10-20 — do not add it back.** Play's
release review flagged it under the Photo and Video Permissions policy and
asked us to justify broad media access:

> Describe why the Android photo picker or other system pickers do not fully
> support your app's core functionality.

They do fully support it, so there was nothing honest to write in that box.
The permission had been declared once "for clarity" alongside the POI photo
feature and was never needed: `pickImage(source: ImageSource.gallery)` goes
through a system picker that returns a per-file URI grant. `image_picker_android`
does not declare the permission either, so deleting our line removed it from
the merged manifest outright — no `tools:node="remove"` required.

At the same time `main.dart` now sets `useAndroidPhotoPicker = true`. That
flag still defaults to **false** in `image_picker_android` 0.8.13, which
leaves the plugin on the older `ACTION_GET_CONTENT` path — permission-free
too, but not the picker the policy is written around. Opting in requires
direct dependencies on `image_picker_android` and
`image_picker_platform_interface`, which is the documented approach.

Verify on any future bundle:

```
unzip -o -q build/app/outputs/bundle/release/app-release.aab 'base/manifest/AndroidManifest.xml' -d /tmp/aabchk
grep -ac 'READ_MEDIA_IMAGES' /tmp/aabchk/base/manifest/AndroidManifest.xml
```

`0` is correct. Anything else means a dependency started merging it in and
the Photo and Video Permissions form will come back.

Check the **compiled** manifest from inside the .aab, as above, not Gradle's
text one under `build/app/intermediates/merged_manifest*/`. The merger
preserves XML comments, so the comment in `AndroidManifest.xml` explaining
why the permission is absent makes a bare string grep there report a hit.
If you do check the text version, match the declaration rather than the name:

```
grep -c 'uses-permission[^>]*READ_MEDIA_IMAGES' <merged manifest>
```

**If Play still shows the form after uploading a clean bundle**, the bundle is
probably not the problem. A Play release keeps every bundle uploaded to it —
a replacement is *added*, not swapped in — and the form is evaluated across
all of them. Use the form's own "View app bundles and APKs" link to see which
version code triggers it; if it is an older one, remove that bundle from the
release, or discard the draft and create a fresh release containing only the
clean build.

| Data type | Collected | Shared | Purpose | Notes |
|---|---|---|---|---|
| **Precise location** | Yes | No | App functionality | Routing, navigation, "near me". Stays on device. |
| **Approximate location** | Yes | **Yes** | App functionality | Coordinates go to Open-Meteo for weather and Open-Elevation for route elevation. Both third parties, so declare as shared. |
| **Device or other IDs** | Yes | **Yes** | Advertising | AdMob. Standard for any app serving Google ads. |
| **App interactions** | Yes | Yes | Advertising, Analytics | AdMob. |
| **Photos** | No | No | — | `image_picker` reads a chosen photo; `poi_photo_store` keeps it on device. Nothing is uploaded — the only POST in the app is the elevation lookup. |
| **Purchase history** | No | No | — | Handled entirely by Google Play Billing, not collected by the app. |
| **Personal info / email / name** | No | No | — | No accounts, no sign-in. |
| **Files, contacts, messages, health** | No | No | — | Not touched. |

**Security practices:**
- Encrypted in transit: **Yes** (every host above is HTTPS)
- Users can request data deletion: **No account to delete.** All app data
  (favourites, trip log, photos) is local; uninstalling removes it.

The approximate-location "shared" answer is the conservative reading. Google
permits treating a pure service provider as non-sharing, but weather and
elevation lookups do transmit coordinates off the device to companies we don't
control, and under-declaring is what gets apps pulled.

---

## 6. Content rating (IARC questionnaire)

Category: **Utility / Reference**. Expect **Everyone / PEGI 3**.

- Violence, sexuality, profanity, controlled substances, gambling: **No** to all
- Users can interact or communicate with each other: **No**
- User-generated content: **No** — verified; the Android build has no condition
  reports or wildlife sightings (those exist only in the iOS app, via CloudKit)
- Shares user location with other users: **No** — route sharing produces a link
  describing a *route*, not the user's live position
- Digital purchases: **Yes** (remove-ads + tip jar)

---

## 7. Closed testing

Play requires a closed test with **12+ testers opted in for 14 continuous
days** before applying for production access.

**This is PER APP, not per account — verified 2026-09-26 against Google's
own documentation.** Having cleared the gate for another app on the same
account (Good Shepherd, S-Tier Eats) does NOT exempt Trail Guide. Google's
wording is "run a closed test for *their app*", and nothing in the policy
grants an account-wide exemption. Do not skip this on the assumption that
production access carries over; it does not.
https://support.google.com/googleplay/android-developer/answer/14151465

1. Play Console → Testing → Closed testing → create a track
2. Upload `app-release.aab`
3. Add testers by email list, or create a Google Group and add the group
   address — the group route is easier to change later
4. Share the opt-in URL; **each tester must actually accept and install**

Things that reliably go wrong:
- **The 14 days are continuous.** Dropping below 12 opted-in testers restarts
  the clock. Recruit more than 12.
- Testers must **opt in via the link**, not merely be listed.
- The count is opt-ins, but Google also wants real activity — ask testers to
  actually open the app.
- Start the clock as early as possible. Listing polish can continue afterwards;
  the 14 days cannot be compressed.

Given the app is hyper-local, WAFWA (~15.7K local members) and The Woodlands
Dispatch list are the obvious places to find 12+ genuinely interested testers
quickly.
