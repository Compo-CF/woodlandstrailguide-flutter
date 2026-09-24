# Google Play — closed testing submission

Everything needed to get Woodlands Trail Guide onto a Play closed-testing
track and start the mandatory 14-day clock.

Every factual claim in the Data Safety and content-rating sections below was
read out of this repo (outbound hosts, declared permissions, absence of
auth/UGC), not recalled. If the code changes, re-verify before re-declaring —
Data Safety is a binding declaration to Google, not a description.

---

## 0. Blocker: signing (do this first)

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

## 1. Build

```bash
cd ~/woodlandstrailguide-flutter && git checkout -- pubspec.lock 2>/dev/null; \
  git pull && flutter clean && flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Current version: **1.0.0 (versionCode 3)** — set in `pubspec.yaml` as
`version: 1.0.0+3`. Every subsequent upload needs a higher versionCode.

Note: every Android build to date has been `--debug`. `--release` adds R8
minification, and both `google_mobile_ads` and `in_app_purchase` have a history
of needing ProGuard keep rules. If the build fails, or the app crashes on
launch where the debug build didn't, that's the first place to look.

---

## 2. Store listing

**App name** (≤30 chars)

```
Woodlands Trail Guide
```

**Short description** (≤80 chars)

```
Trail maps, routes and walk planning for The Woodlands, Texas.
```

**Full description** (≤4000 chars)

```
Woodlands Trail Guide maps the full pathway network of The Woodlands, Texas —
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

## 5. Data Safety

Verified against the code: outbound hosts are `api.open-meteo.com`,
`api.open-elevation.com` and `compo-cf.github.io`; declared permissions are
`INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`,
`READ_MEDIA_IMAGES`, `com.android.vending.BILLING`; there is no sign-in SDK and
no user-generated content.

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
days** before a personal developer account can apply for production access.

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
