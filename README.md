# Atomic Habits — Native iPhone App (v0 Foundation)

**Version: v0 foundation.** This is a solid, functional starting build — not the
final design. The plan is: (1) finish iterating the design in the web
Atomic Habits app, then (2) port that final design into this native project in
a later pass, re-skinning the screens here. The data model, seeds, and flows
in this v0 already match the web app exactly, so nothing you track here has
to be thrown away.

A standalone iPhone app based on *Atomic Habits* (James Clear): build habits
and quit habits, tracked one day at a time. **Fully offline. No server, no
account, no external dependency, no third-party packages.** All of your data
lives only on your iPhone, in the app's own storage.

- Build habits: 10,000 steps · Workout · Healthy protein meal · Read 10 pages
- Quit habit: Alcohol outside cheat days
- ("Today's Votes" tally, streaks, last-14-days strip, identity statement,
  habit stack, 2-minute version, Four Laws checklists — and for quit habits:
  inverted Four Laws, real cost list, replacement habit, urge log, and a
  10-minute urge timer. Add / edit / delete habits on both sides.)

---

## How to install it on your iPhone (from your Mac)

You build and install it yourself with Xcode — Apple requires apps to be
signed with your own Apple ID before an iPhone will run them.

### You need
- Your Mac
- Your iPhone + a USB cable
- Your Apple ID (free is fine — see "Signing — please read" below)

### Steps

1. **Get this project onto your Mac.**
   Unzip `atomic-habits-ios.zip`, then open the folder `atomic-habits-ios`.

2. **Install Xcode** (skip if you already have it).
   Open the **App Store** on your Mac, search **Xcode**, install it. It's a
   large download — give it time. Open Xcode once and let it finish installing
   its components.

3. **Open the project.**
   Double-click **`AtomicHabits.xcodeproj`** inside the `atomic-habits-ios`
   folder (or in Xcode: File → Open).

4. **Sign in with your Apple ID in Xcode.**
   Xcode → **Settings… → Accounts** → click **+** → **Apple ID** → sign in.

5. **Pick your signing team.**
   In the left sidebar click the blue **AtomicHabits** project icon → select
   the **AtomicHabits** target → **Signing & Capabilities** tab → tick
   **Automatically manage signing** → under **Team**, choose your name with
   **(Personal Team)** next to it.
   *(The bundle ID is `com.parthey.atomichabits`. If Xcode ever complains that
   ID is taken, just change the last part slightly, e.g.
   `com.parthey.atomichabits2`.)*

6. **Connect your iPhone.**
   Plug the iPhone into the Mac with the USB cable. If the phone asks
   **"Trust This Computer?"**, tap **Trust** and enter your passcode.

7. **Turn on Developer Mode on the iPhone.**
   On the phone: **Settings → Privacy & Security → Developer Mode → On**.
   The phone will restart — let it, then confirm when it asks again.

8. **Choose your iPhone as the run destination.**
   At the top of the Xcode window, next to the ▶ Run button, click the device
   menu and select **your iPhone** (not a simulator).

9. **Run it.**
   Click **▶ Run** (or press **Cmd–R**). Xcode builds the app, signs it with
   your Apple ID, installs it on the phone, and launches it.

10. **Trust the developer certificate (first time only).**
    If the phone says "Untrusted Developer": on the phone go to
    **Settings → General → VPN & Device Management**, tap your Apple ID under
    **Developer App**, tap **Trust**, then open the app again.

That's it — the **Atomic Habits** icon is now on your iPhone and works fully
offline, with no connection to any server.

---

## Signing — please read (the 7-day rule)

- **Free Apple ID (Personal Team):** Apple lets you run your own apps for
  **7 days**. After 7 days the app will stop opening. The fix takes a minute:
  plug the phone into the Mac again, open this project in Xcode, and press
  **Run** again. Your data is still on the phone and comes right back —
  re-running does **not** erase it (as long as you don't delete the app).
- **Paid Apple Developer Program ($99/year):** signing lasts **1 year**
  instead, so you'd only need to re-run about once a year.

## Your data

- All habits, check-ins, checklists, and urge logs are stored **only on the
  iPhone**, in the app's private storage (`Application Support/AtomicHabits/habits.json`).
- Nothing is sent anywhere. There is no cloud copy and no backup inside this
  project.
- **Deleting the app deletes its data permanently.** Re-installing over the
  top (pressing Run again in Xcode) keeps it.

## If something goes wrong

- **"Developer Mode required"** — do Step 7, including the restart.
- **"Untrusted Developer"** — do Step 10.
- **App stopped opening after a week** — that's the free-signing expiry; do
  Step 9 again.
- **Xcode can't see the phone** — unlock the phone, keep it plugged in, tap
  Trust, and check it appears in Xcode → Window → Devices and Simulators.

## Project notes (for the later design port)

- SwiftUI, iOS 17+, iPhone only, bundle ID `com.parthey.atomichabits`,
  automatic signing, zero external dependencies.
- Data layer is a simple Codable JSON store (`Store.swift`) rather than
  SwiftData — deliberately chosen so the hand-authored project stays simple
  and reliable to open and run. Model types are in `Models.swift`
  (`Habit`, `UrgeLogEntry`, `AppData`), matching the web app's concepts:
  habits / check-ins by date (`yyyy-MM-dd`) / law checks / urge logs, with
  the same 5 seed habits on first launch only.

## Widgets & App Group (hooks branch)

Four widgets ship with the app (small Today's Votes ring, medium interactive
check-ins, Lock Screen clean streak, large week chain). They read — and the
medium widget writes — the shared `habits.json` in the App Group container
`group.com.parthey.atomichabits`.

**Signing caveat:** App Groups must be provisioned for both the app and the
widget target. Under free Personal Team signing the group may not be
granted: the app then falls back to its private store (all features work),
the interactive widget's writes no-op, and widgets may show an empty state.
With a paid developer team, select the same App Group for both targets in
Signing & Capabilities and everything syncs.
