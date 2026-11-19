# Publishing Atomic Habits — App Store checklist

Owner steps are Parthey's (Apple requires the account holder); everything
else is built and ready in this repo. Pipeline follows the house standard
(`app-store-pipeline/STANDARD.md`), proven live on My Work Spots
2026-11-18: merge to `main` → **unsigned** archive on a **macos-26**
runner → distribution signing at export via the API key → TestFlight.
Final Submit for Review stays Parthey's tap.

Status (2026-11-18): Apple Developer account ENABLED (since 2026-11-13).
Release prep DONE in this repo: app icon set, `PrivacyInfo.xcprivacy`,
local-notifications re-arm on launch, `.github/workflows/ios-build.yml`
(macos-26 compile check) and `.github/workflows/release.yml` (dry-run
unsigned build until the ASC secrets land, then automatic TestFlight
upload). **Not yet done: GitHub repo, bundle-ID registration, App Store
Connect record, repo secrets — the owner gates below.**

## 1. GitHub repo (Parthey creates, ~2 minutes)

- Create a **private** repo: `beastmodepk/atomic-habits-ios` (empty — no
  README, no .gitignore; history is pushed from here).
- Repo → Settings → Deploy keys → Add deploy key: paste the
  **Atomic Habits deploy key** (public key handed over in chat 2026-11-18),
  title it `atomic-habits-vm`, tick **Allow write access**.
- Then the full history is pushed from the VM and CI runs for the first
  time (first real compile — expect a possible fix round).

## 2. Register the bundle IDs (Parthey, developer.apple.com)

Certificates, Identifiers & Profiles → Identifiers:

1. **App Group** first: `group.com.parthey.atomichabits`.
2. **App ID** `com.parthey.atomichabits` — description "Habit Builder",
   capability: **App Groups** (assign the group above).
3. **App ID** `com.parthey.atomichabits.widgets` — description
   "Habit Builder Widgets", capability: **App Groups** (same group).

The App Group is what lets the widgets read/write the same on-device
habits file as the app; without it the app still works fully and the
widgets show an empty state.

## 3. App Store Connect record (Parthey, ~2 minutes)

App Store Connect → Apps → "+" → New App:

- Platform: iOS
- Name: **Habit Builder** (Parthey's decision 2026-11-18, replacing the
  book-title name). Checked 2026-11-18: no app with the exact name
  "Habit Builder" on the US App Store — the closest are suffixed variants
  ("Habit Builder: Daily Tracker", "Habit Builder - Streakly"). App Store
  Connect is the definitive test: if it rejects the name as taken, use
  **Habit Builder — Daily Votes**; the bundle ID does not change either way.
- Primary language: English (U.S.)
- Bundle ID: **com.parthey.atomichabits**
- SKU: `habitbuilder-ios-001`
- User Access: Full Access

## 4. GitHub repo secrets (Parthey adds — same values as Work Spots)

Repo → Settings → Secrets and variables → Actions:

- `ASC_KEY_ID` — the existing Release CI key (Key ID C9RGC978UF)
- `ASC_ISSUER_ID` — same issuer as Work Spots
- `ASC_KEY_P8` — full contents of the same .p8 file
- `ASC_TEAM_ID` — same Team ID as Work Spots

One API key serves every app; the values are identical to the ones
already in the Work Spots / SaySplit repos.

## 5. First upload

1. Merge the release-prep branch to `main` (or push `main`) → `release.yml`
   archives and uploads to TestFlight once the secrets exist; without
   them it runs the unsigned build only and says so.
2. In App Store Connect → TestFlight: clear **Missing Compliance** →
   Manage → **None** (no encryption beyond iOS standard, local-first app).
3. Create/confirm the internal tester group and add yourself; the build
   appears after Apple processing (~15–30 min) and expires in 90 days.

## 6. Going public (later, Parthey's call)

Distribution (public / unlisted / TestFlight-only), pricing, listing copy,
screenshots and categories are **not decided yet** for Atomic Habits.
Fill the listing via the API key once decided; Submit for Review stays
Parthey's tap. Versioning rules: `docs/VERSIONING.md`. Privacy:
`docs/PRIVACY.md` — label is **Data Not Collected**.
