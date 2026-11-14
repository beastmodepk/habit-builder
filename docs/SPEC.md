# Atomic Habits — Full Project Specification

Version: 2026-10-24 · Status: design iteration in progress (not yet promoted)
Owner: Parthey

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
| Web app prototype (`atomic-habits`, plus the comparison clone `atomic-habits-hooks`) | Design source of truth. Iterated first; every accepted design lands here before it is ported. | Hosted full-stack web app, server-side persistence |
| Native iOS app | The shipping product. Standalone, offline, data on the phone only. | SwiftUI, iOS 17+, Xcode project, Codable JSON store |

The original web app (`atomic-habits`) is the plain MVP baseline and is kept
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
  chore/refactor/style`).
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

Three destinations, reached by a segmented/tab control (**Today / Review /
iPhone Widgets** — simplified 2026-10-24, UX Round 2). Build and Quit are
**sections within Today**, not separate destinations. A prominent
**+ Create** action lives in the header; when a form draft exists it reads
**Finish your habit** and reopens the draft.

### 5.1 Today
- **Empty state (no habits):** the *Create your first habit* card is the
  first element on the screen. No statistics, rings, tallies, or placeholder
  boards are shown — there is nothing to measure yet. The Build and Quit
  section prompts below it have **distinct copy**: Build speaks of growing /
  becoming; Quit names its different promise, "…and watch what you save."
- **With habits, in order:** Next Cue card → Identity Board → Prime
  Tomorrow (evening prep) → Build section → Quit section → **stats card at
  the very bottom** (Today's Votes ring, today %, this-week %, all-time
  votes).
- Stack-chain strip: the day rendered as linked stacks ("After I brush my
  teeth → read 10 pages → …").
- **One-tap daily completion:** every habit card carries an immediately
  visible one-tap check-in (round toggle for Build; a "Stayed clean today"
  toggle for Quit) that casts today's vote without opening detail. The
  2-minute version stays one tap away as a secondary action. Detail is for
  designing, not for daily doing.
- **Fixed SOS:** whenever at least one quit habit exists, a fixed,
  thumb-reachable **SOS button** sits at the bottom of Today (above the
  safe area). It opens the guided SOS flow (§8, hook 14); with several quit
  habits it asks which one, with an easy switch inside the flow.

### 5.2 Build / Quit sections (within Today)
Habit cards: name, streak, last-14-days strip, today's state (done / 2-minute
done / pending / rescue), quick actions (one-tap check-in, 2-Minute Mode,
open detail, SOS on quit cards, overflow menu with Delete habit).

### 5.3 Habit detail
Everything the creation form generated (see §7): identity, stack sentence,
2-minute version, Four Laws panel, prep checklist, bundle, reward, month
chain heatmap, Goldilocks shrink suggestion when struggling, edit + delete.
**Delete habit** is available both here and from the card's overflow menu;
it requires an explicit confirmation dialog naming the habit and stating
that its check-ins, prep items, law design, urge logs and history will be
permanently removed. Only that habit's records are deleted; deleting the
last habit returns the app to the clean empty state.

### 5.4 Review
Weekly Review: votes this week vs last, 8-week compounding bar chart,
plateau note ("this is where most people quit"), saved reflection prompts.
Full statistics live here and at the bottom of Today — never as a top hero
(decided 2026-10-24).

### 5.5 iPhone Widgets (preview in prototype; real in native)
The destination is named **iPhone Widgets**. A setup note at the top states
that the previews use live data in the prototype, while the real Home
Screen and Lock Screen widgets are installed from the native iPhone app.
Each preview is labelled a native-widget preview; the medium preview's
working toggles are labelled as a preview interaction demonstrating the
native tap-to-vote behaviour (§10).

### 5.6 Settings / data
Remove-everything reset (with confirmation): deletes all habits, check-ins,
urge logs, reviews, drafts and milestone records, and returns to the empty
state. Separate from individual habit deletion (§5.3).

### 5.7 First-launch onboarding — Opal-style enrollment (native, 2026-10-24)

Native only so far (the web clone has no enrollment). Modelled on
Opal's "enrolls you" pattern: a guided, question-by-question flow that
computes a personal reveal from the user's own answers, generates their
first habit(s), takes a commitment, asks for the reminder permission at
the moment of motivation, and lands on Today with the plan in place.

Steps: **Welcome** (1% hero ring, "Small habits. Remarkable results.",
quiet *Explore first — I already have a setup* skip) → **Name** →
**Path** (Build / Break / Both) → **Diagnostics** (adaptive, mostly
chips: build — habit, current days/week 0–7, biggest obstacle; quit —
habit, frequency, $ per day, how long) → **the Reveal** (build:
hand-drawn 1.01^365 compounding curve to 37.8× + projected votes over
12 weeks at their rhythm and daily; quit: a year of savings at their
daily cost + 84 clean days / 12-week savings — all derived from their
answers and labelled projections, never invented statistics) →
**Your plan, generated** (anchor chips + time + place compose the stack
sentence; 2-minute version; live Today-style card preview; path = Both
runs a second pass for the quit habit: craving when/where + replacement)
→ **Identity & commitment** (editable "I am a person who…" per habit,
pre-suggested; quit habits take the signed contract — commitment text
with name + date, consequence, witness — behind a deliberate two-tap
arm-then-commit button) → **Reminder permission** (the real system
authorization via `AnchorNotifications`, cue reminders scheduled for
created habits; "Not now" never blocks) → **Done** (champagne,
"You're in, <name>.", the habit card(s), first-action button to Today).

Persistence & gating: `AppData` carries `hasOnboarded`, `userName`,
`onboardingPath` in the same `habits.json`, all decode-if-present, so
pre-onboarding data loads untouched. Enrollment is presented only when
`hasOnboarded == false` AND the store launched pristine (fresh install,
or seeded-but-untouched: no check-ins, urge logs or reflections). It
never deletes or alters existing habits, and first-run seeding is
unchanged. Note: the native app has no Remove Everything flow yet (that
reset exists only in the web clone, §5.6), so nothing resets
`hasOnboarded` natively for now; a native reset, when built, must clear
`hasOnboarded`/`userName`/`onboardingPath` so a reset re-enrolls.

## 6. Core concepts & data model

Entities (identical concepts on both surfaces):

- **Habit** — `kind` (build | quit), name, identity statement, stack
  (anchor, time, place), 2-minute version, law fields (below), prep items,
  bundle, reward, daily cost (quit), replacement (quit), contract (quit:
  consequence, witness, signed date), shrunk-until date, created date.
- **Check-in** — habit, date (`yyyy-MM-dd`), kind (`full` | `two-minute` |
  `rescue`). Two-minute and rescue check-ins count toward tally and streak
  and are shown distinctly in chains/heatmaps.
- **Law checks** — 4-element booleans per habit; **derived**: a law counts as
  "designed" when its form blank was filled (see §7). Manually editable later.
- **Urge log entry** — habit, timestamp, cue, craving note, what-I-did-instead,
  intensity before (1–10), intensity after (1–10).
- **Weekly review** — week key, reflection answers.
- **Meta** — schema/purge flags (e.g. the one-time purge of legacy seed
  data); the in-progress **form draft** (kind, step, all field values,
  auto-saved server-side as the user types); and **identity milestone
  celebrations** already shown (per identity: highest celebrated milestone
  of 10 / 25 / 50 votes), so a celebration never repeats on reload.

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

**Three steps (UX Round 2, 2026-10-24):** the form is split into three
short steps with a numbered progress indicator and Back / Continue
controls — Build: *The Habit* → *Make It Stick* → *The Reward*; Quit:
*The Habit* → *Make It Stick* → *The Contract* (step contents below). The
generated preview stays pinned in a persistent summary area at the bottom
of the form on every step, with law chips updating live. Only the current
step's essential blank (the habit's name on Step 1) is validated before
continuing, with gentle inline guidance — never a punitive error.

**Draft auto-save:** the form type, current step, and every field value
persist automatically (server-side in the prototype) as the user types or
navigates. If a draft exists, the Create card and the header + action read
**Finish your habit** and reopen the form at the saved step with values
intact. A **Discard draft** action sits inside the form; successful
creation clears the draft.

**Sentence grammar:** every blank carries a dimmed, concrete example.
Generated sentences compose naturally: "at" for a time, and the place
preposition chosen from the place wording — "in bed", "in the kitchen",
but "at the gym", "at my desk" — e.g. *"After I brush my teeth, I will
read 10 pages at 9:30 PM in bed."* The same composition is used in the
preview, the generated stack, and the card, with no "in/at" artifacts.

### Build form
1. "I want to build the habit of ______"
2. "I am a person who ______" → Identity Board entry
3. "After I ______ (anchor), I will do it at ______ (time), place: ______"
   → habit-stack sentence (grammar rule above), Next Cue, anchor reminder
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
(10) Never-Miss-Twice Rescue Mode (rescue banner on the habit card, shrunk
version, streak protected on completion; language reframed 2026-10-24 to
*"Yesterday slipped. Here's your 2-minute rescue — your streak stays
alive."* — encouraging and factual, no guilt wording) · (11) Weekly Review
+ compounding chart + plateau note + reflections.
**Quit inversions:** (12) urge pattern insights · (13) saved counter ·
(14) Urge SOS flow (intensity before → 10-minute timer → replacement →
intensity after → saved as urge log).
**Widgets:** (15) small · (16) medium interactive · (17) Lock Screen ·
(18) large — see §10.

**UX Round 2 (2026-10-24, web clone; from a UX-engineer review):**
three-step creation form with draft auto-save / resume (§7); navigation
simplified to Today / Review / iPhone Widgets with Build & Quit as Today
sections and a header + Create action (§5); one-tap daily completion on
Today cards; fixed thumb-reachable SOS on Today (§5.1); natural sentence
composition + concrete examples in every blank (§7); Rescue language
reframed (hook 10); iPhone Widgets screen clarified as native previews
(§5.5); **identity milestones** — the Identity Board quietly shows progress
to the next milestone (10 / 25 / 50 votes per identity, e.g. 18/25) and a
restrained champagne celebration ("10 votes — this identity is taking
hold") appears once when a milestone is crossed, persisted so it never
repeats; distinct Build vs Quit empty prompts (§5.1); individual habit
deletion with a naming confirmation dialog (§5.3).

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
| Web original `atomic-habits` | MVP baseline; untouched; seeded start |
| Web clone `atomic-habits-hooks` | **Design source of truth.** All 18 hooks + luxury design + empty start + form creation + stats-at-bottom layout, plus **UX Round 2** (§8): 3-step form with server-side draft auto-save/resume, 3-destination navigation, one-tap daily completion, fixed SOS, natural sentence grammar, reframed Rescue copy, clarified iPhone Widgets screen, identity milestones, distinct empty prompts, individual habit delete with confirmation. Verified by live probes (draft round-trip, grammar strings, surgical delete, SOS overlay, stayed-clean toggle) |
| Native `main` (v0.1.0) | Foundation: models, store, Today, detail, urge timer; seeded start; stock UI |
| Native `feat/atomic-hooks` (clone repo) | All 18 hooks + luxury design + WidgetKit target; additions #12–#35, plus **Opal-style onboarding enrollment (§5.7, addition #36)**: first-launch flow with diagnostics, computed reveal, first-habit generation via onboarding, identity/contract commitment, and motivated-moment reminder permission — gated to a pristine store, existing data never altered |
| **Pending port** | The standalone form-based creation flow (for adding later habits), empty start (+ remove-everything), stats-at-bottom layout, and all of UX Round 2 currently exist **only in the web clone**; they port to the native branch after Parthey confirms the clone. (First-habit *generation* itself is no longer pending — it now exists natively inside onboarding, §5.7.) |
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
lives in Parthey's private environment. Habit content is personal by
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
