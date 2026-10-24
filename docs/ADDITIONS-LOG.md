# Additions Log

A running, numbered log of everything added to this project, in the order it
was added. **Rule: every new addition gets the next number here, in the same
commit that adds it (or the commit immediately after).** Never renumber,
never delete an entry — if an addition is later removed or replaced, add a
new entry saying so.

Started 2026-10-23 at Parthey's request.

## Additions

1. **Muse-app MVP** — Atomic Habits prototype built and verified in Muse: Today's Votes, Build + Quit habits, identity / stack / 2-minute / Four Laws design panels, inverted laws, urge log, urge timer, persistent data. (Design prototype; the native app below mirrors it.)
2. **README** — install and signing notes for the native app. Commit `43e2ead` — `docs(readme):`
3. **Docs pack** — `docs/ARCHITECTURE.md`, `docs/FEATURE-PLAN.md`, `docs/COMMIT-CONVENTIONS.md`, `docs/SIGNING-AND-PUSH.md`, and `CHANGELOG.md`. Commit `7476101` — `docs:`
4. **Xcode project scaffold** — `AtomicHabits.xcodeproj` (shared scheme, automatic signing, bundle id `com.parthey.atomichabits`, iOS 17+, iPhone), app entry point, asset catalog, `.gitignore`. Commit `123974d` — `chore(project):`
5. **Data models + streak logic** — `Models.swift`: habit kinds, check-ins by date, streaks, last-14-days. Commit `d3aa5c5` — `feat(models):`
6. **On-device store + seeding** — `Store.swift`: JSON persistence on the phone only; five seed habits on first launch (10,000 steps, Workout, Healthy protein meal, Read 10 pages; quit: Alcohol outside cheat days). Commit `ce151dd` — `feat(store):`
7. **Today's Votes dashboard** — `ContentView.swift`: today's votes, today %, this-week %, all-time votes; Build / Quit sections; add-habit flow. Commit `a4fd9d2` — `feat(today):`
8. **Habit detail panels** — `HabitDetailViews.swift`: identity statement, habit stack, 2-minute version, Four Laws / inverted laws, cost list, replacement habit, never-miss-twice note, urge log, add/edit/delete. Commit `df931bb` — `feat(detail):`
9. **Urge timer** — `UrgeTimerView.swift`: 10-minute progress-ring timer for quit habits. Commit `08889e8` — `feat(urge):`
10. **Git history + MVP tag** — the project restructured into the per-feature conventional commits above, every commit carrying the `Assisted-by: Muse Wonder` trailer, and the annotated release tag `v0.1.0` (MVP).
11. **This additions log** — `docs/ADDITIONS-LOG.md`, the standing numbered record of all additions from here on.
12. **Hooks data model + shared store** — `Models.swift` extended backwards-compatibly (cue time/place/anchor, temptation bundle, reward text, prep items, habit contract, daily cost, check-in kinds full vs 2-minute, shrunk state, urge intensities, weekly reflections; old JSON still decodes). `SharedStore.swift`: one habits.json in the App Group container `group.com.parthey.atomichabits` when provisioned, private-file fallback otherwise. Rescue-aware streak logic included.
13. **Apple-luxury design system** — `DesignSystem.swift`: restrained adaptive palette (near-white / true black, graphite, deep green Build, warm amber Quit, champagne highlights), Large-Title-friendly typography, 22pt-radius cards with soft shadow + hairline edge, translucent material header, Fitness-style animated activity ring, minimal chain/heatmap graphics, streak pill, styled section headers. Used across all screens and widgets that follow.
14. **Anchor reminders + stack chain (Cue 1)** — `Notifications.swift`: local notification per habit at its cue time, worded from its anchor; permission asked on tap in the detail Cue section, denial no-ops gracefully. Today shows "Today's Stack" — the day as a linked chain of stacked habits in cue-time order. Today screen rebuilt in the design system (Fitness ring hero, luxury cards).
