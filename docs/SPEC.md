# Atomic Habits — Full Project Specification

Version: 2026-10-24 · Status: design iteration in progress (not yet promoted)
Owner: Parthey · Built with: Muse (Alfred)

---

## 1. Product summary

Atomic Habits is a habit app based on James Clear's *Atomic Habits*, for
**building good habits and quitting bad ones** in one place. Its premise:
habits are not tracked as bare checkboxes — each habit is **designed** using
the book's system (identity, habit stacking, the Four Laws) and then tracked
as **votes** for the person the user wants to become.

Two surfaces implement the same product:

| Surface | Role | Tech |
|---|---|---|
| Muse app prototype (`atomic-habits`, plus the comparison clone `atomic-habits-hooks`) | Design source of truth. Iterated first; every accepted design lands here before it is ported. | Hosted full-stack web app, server-side persistence |
| Native iOS app | The shipping product. Standalone, offline, data on the phone only. | SwiftUI, iOS 17+, Xcode project, Codable JSON store |

The original Muse app (`atomic-habits`) is the plain MVP baseline and is kept
untouched for comparison. All current design work happens in the clone
(`atomic-habits-hooks`).

## 2. Principles

1. **Systems over goals** — the app designs habits, it doesn't just count them.
2. **Identity first** — every check-in is a vote for an identity statement.
3. **The hook is the whole loop** — Cue → Craving → Response → Reward. Build
   features strengthen each stage; quit features invert each stage.
4. **Make it easy** — the 2-minute version of a habit always exists and counts.
5. **Never miss twice** — a missed day triggers rescue, not guilt.
6. **Local-first (native)** — no account, no server, no network. Deleting the
   app deletes its data.
7. **Nothing is pre-filled** — the app starts empty; everything in it was
   written by the user (decided 2026-10-23, Hooks clone).

## 3. Development workflow (standing rule)

- Every change is built **on a separate git branch and in a separate clone of
  the app**; `main` and the current app stay untouched for comparison.
- Only after **Parthey confirms** is the branch merged to `main` and the clone
  promoted into the main app.
- One feature = one commit, Conventional Commits (`feat/fix/bug/test/docs/
  chore/refactor/style`), every commit carries the trailer
  `Assisted-by: Muse Wonder`.
- Every addition is recorded as the next numbered entry in
  `docs/ADDITIONS-LOG.md`, in the same commit. Never renumbered.
- Files/zips are **not** sent to Parthey on updates; he asks when ready.
- Releases are annotated tags (`v0.1.0` = MVP).

## 4. Users & scope

- Primary user: Parthey (single-user app; no accounts, no social layer in v1).
- In scope: build habits, quit habits, daily check-ins, streaks, urge
  management, weekly review, iPhone widgets (native), local notifications
  (native).
- Out of scope (v1): sharing/social, cloud sync, Android, web app, AI coaching.

## 5. Information architecture

Five areas, reached by a segmented/tab control (Today / Build / Quit /
Review / Widgets in the prototype; tabs in native):

### 5.1 Today
- **Empty state (no habits):** the *Create your first habit* card is the
  first element on the screen. No statistics, rings, tallies, or placeholder
  boards are shown — there is nothing to measure yet.
- **With habits, in order:** Next Cue card → Rescue card (only when a habit
  missed yesterday) → Identity Board → Prime Tomorrow (evening prep) →
  Build list → Quit list → SOS entry (quit) → **stats card at the very
  bottom** (Today's Votes ring, today %, this-week %, all-time votes).
- Stack-chain strip: the day rendered as linked stacks ("After I brush my
  teeth → read 10 pages → …").

### 5.2 Build / Quit lists
Habit cards: name, streak, last-14-days strip, today's state (done / 2-minute
done / pending / rescue), quick actions (check in, 2-Minute Mode, open
detail, SOS on quit cards).

### 5.3 Habit detail
Everything the creation form generated (see §7): identity, stack sentence,
2-minute version, Four Laws panel, prep checklist, bundle, reward, month
chain heatmap, Goldilocks shrink suggestion when struggling, edit + delete.

### 5.4 Review
Weekly Review: votes this week vs last, 8-week compounding bar chart,
plateau note ("this is where most people quit"), saved reflection prompts.
Full statistics live here and at the bottom of Today — never as a top hero
(decided 2026-10-24).

### 5.5 Widgets (preview in prototype; real in native)
Previews render the four native widgets with live data (§10).

### 5.6 Settings / data
Remove-everything reset (with confirmation): deletes all habits, check-ins,
urge logs, reviews, and returns to the empty state.

## 6. Core concepts & data model

Entities (identical concepts on both surfaces):

- **Habit** — `kind` (build | quit), name, identity statement, stack
  (anchor, time, place), 2-minute version, law fields (below), prep items,
  bundle, reward, daily cost (quit), replacement (quit), contract (quit:
  consequence, witness, signed date), shrunk-until date, created date.
- **Check-in** — habit, date (`yyyy-MM-dd`), kind (`full` | `two-minute`).
  Two-minute check-ins count toward tally and streak and are shown in
  champagne in chains/heatmaps.
- **Law checks** — 4-element booleans per habit; **derived**: a law counts as
  "designed" when its form blank was filled (see §7). Manually editable later.
- **Urge log entry** — habit, timestamp, cue, craving note, what-I-did-instead,
  intensity before (1–10), intensity after (1–10).
- **Weekly review** — week key, reflection answers.
- **Meta** — schema/purge flags (e.g. the one-time purge of legacy seed data).

Derived values: streak (a single missed yesterday is bridged when today is
completed and history exists before the gap — the missed day is not a vote),
today/week/all-time vote counts and %, saved total (clean days × daily cost),
urge insights (top cue, top hour, urges this week), Next Cue (earliest
not-yet-done habit with a cue time).

## 7. Habit creation — fill-in-the-blanks form (core flow)

There is **no blank "add habit" record**. Creation is a guided form of
sentence blanks with a live *"Your habit, generated"* preview and law chips
that light up as blanks are filled. On submit, the app **generates** the
habit card, detail panel, checklists, cue, and counters from the answers.

### Build form
1. "I want to build the habit of ______"
2. "I am a person who ______" → Identity Board entry
3. "After I ______ (anchor), I will do it at ______ (time) in/at ______"
   → habit-stack sentence, Next Cue, anchor reminder
4. "My 2-minute version is ______" → 2-Minute Mode + **Easy** law
5. "To make it obvious, I will ______" → environment/prep checklist + **Obvious** law
6. "While/after it, I get to ______" → temptation bundle + **Attractive** law
7. "My reward when I finish is ______" → instant reward + **Satisfying** law

### Quit form
1. "I want to quit ______"
2. "It costs me ______" and "about $______ a day" → cost list, saved counter, **Unattractive**
3. "I usually crave it when ______ at ______" → cue for insights + SOS context
4. "To make it invisible, I will ______" → **Invisible** law + prep items
5. "To make it hard, I will ______" → **Hard** law (friction step)
6. "When I crave it, instead I will ______" → replacement, used by SOS
7. Contract: "If I break this, ______. Witness: ______" → contract card, signed date, **Unsatisfying**

## 8. The 18 hook features (all implemented in the Hooks clone)

**Cue:** (1) anchor reminders + stack chain · (2) Next Cue card ·
(3) environment checklists / Prime Tomorrow.
**Craving:** (4) temptation bundling · (5) Identity Board (votes per
identity) · (6) habit contract (quit).
**Response:** (7) 2-Minute Mode · (8) Goldilocks shrink suggestions
(missed 2+ of last 3 days → suggest the 2-minute version, one-tap "shrunk"
state).
**Reward:** (9) instant reward celebration + month chain heatmap ·
(10) Never-Miss-Twice Rescue Mode (rescue card, shrunk version, streak
protected on completion) · (11) Weekly Review + compounding chart + plateau
note + reflections.
**Quit inversions:** (12) urge pattern insights · (13) saved counter ·
(14) Urge SOS flow (intensity before → 10-minute timer → replacement →
intensity after → saved as urge log).
**Widgets:** (15) small · (16) medium interactive · (17) Lock Screen ·
(18) large — see §10.

## 9. Design system — "Apple luxury"

Modelled on Apple's Health / Fitness / Weather apps.

- Fitness-style activity ring for votes (in stats placements only, §5.1).
- iOS Large-Title hierarchy; strong headline / quiet secondary contrast.
- Large rounded cards (22–24pt radius), soft shadows, hairline separators,
  generous whitespace, one focal point per section.
- Palette: near-white light ground / true-black dark ground, graphite text,
  **deep green = Build**, **warm amber = Quit**, **champagne-gold only** for
  streaks, identity, and 2-minute votes. No rainbow colour; at most a subtle
  gradient on hero elements.
- Translucent/material header + segmented control; SF Symbols-style line
  icons only — **no emoji as UI icons**.
- Tabular numerals for all counts; smooth, satisfying completion animation;
  dark mode correct throughout; phone-first layout.

## 10. Widgets (native, WidgetKit)

One app-extension target (`AtomicHabitsWidgets`), same design system:

| Family | Content | Interaction |
|---|---|---|
| Small | Today's Votes ring + next habit cue | Opens app |
| Medium (interactive) | Today's habits + streaks | Toggle check-ins in the widget (iOS 17 AppIntents), no app opening |
| Lock Screen (accessory) | Best clean-day streak | Deep-links to urge timer |
| Large | Votes ring, 7-day heatmap per habit, all streaks | Opens app |

Data sharing: app and widgets read/write one `habits.json` in the App Group
`group.com.parthey.atomichabits`. **Caveat:** App Groups must be provisioned;
under free Personal Team signing the group may not be granted — the app then
falls back to its private store (all in-app features work) and widgets may
show an empty state. Deep links: `atomichabits://today`, `…://urge-timer`,
`…://sos`.

## 11. Notifications (native)

Local notifications from each habit's anchor/time (stack-driven, not generic
clock spam). Permission requested gracefully, in context; denial never blocks
any feature. The prototype shows reminder *cards* only (no real push).

## 12. Platforms & current state (2026-10-24)

| Piece | State |
|---|---|
| Muse original `atomic-habits` | MVP baseline; untouched; seeded start |
| Muse clone `atomic-habits-hooks` | **Design source of truth.** All 18 hooks + luxury design + empty start + form creation + stats-at-bottom layout. Verified by live probes |
| Native `main` (v0.1.0) | Foundation: models, store, Today, detail, urge timer; seeded start; stock UI |
| Native `feat/atomic-hooks` (clone repo) | All 18 hooks + luxury design + WidgetKit target; 22 commits, additions #12–#31 |
| **Pending port** | Form-based creation, empty start (+ remove-everything), and stats-at-bottom layout currently exist **only in the Muse clone**; they port to the native branch after Parthey confirms the clone |
| Validation limit | No Swift compiler exists in the build environment; native code is structurally validated (project references, syntax balance, plists). First true compile happens in Xcode on Parthey's Mac. Widget/AppIntents code is the highest first-build risk |

## 13. Install & signing (native)

1. Unzip on a Mac → open `AtomicHabits.xcodeproj` in Xcode.
2. Xcode Settings → Accounts → sign in with Apple ID; Signing & Capabilities
   → Personal Team.
3. iPhone by USB: trust the computer, enable Developer Mode
   (Settings → Privacy & Security), select the iPhone as run target, Run.
4. Trust the developer certificate (Settings → General → VPN & Device
   Management).
- Free Apple ID signing **expires after 7 days** (re-Run restores it, data
  intact). Paid Apple Developer Program ($99/yr) lasts 1 year.
- To make the history his own, Parthey reviews the commits, rebases with
  `--reset-author -s` to sign off every commit as himself (plain
  `commit --amend -s` only touches the latest), optionally `-S` for GitHub's
  Verified badge, then pushes to his GitHub (empty repo + tag `v0.1.0`).
  Full walkthrough: `docs/SIGNING-AND-PUSH.md`.

## 14. Privacy

No analytics, no tracking, no network calls in the native app. Prototype data
lives in Parthey's private Muse environment. Habit content is personal by
nature and never leaves the surface it was entered on.

## 15. Roadmap / backlog (each lands as its own commit when scheduled)

- Port form creation + empty start + stats placement to native (§12).
- `feat(notifications)` refinements · `feat(widgets)` polish ·
  `feat(healthkit)` auto-count steps for the 10,000-steps habit ·
  `feat(export)` JSON export/import backup · `test:` unit tests for streak
  and tally logic (test target) · App Group provisioning pass once a paid
  team exists.

## 16. Acceptance criteria for promotion (clone → main app / main branch)

- Empty state: Create card first, zero stats on Today.
- Form creation generates card, laws, cue, prep, identity from answers
  (probe-verified on both Build and Quit).
- Post-habit Today order matches §5.1 with stats at the bottom.
- All 18 hook features present and working with form-created habits.
- Audit passes with no console errors and no layout overflow (prototype);
  project structure validates (native).
- Parthey has compared clone vs current app and explicitly confirmed.
