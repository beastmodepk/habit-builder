# Architecture

Atomic Habits — native iOS app. SwiftUI, iOS 17+, no third-party dependencies, fully offline.

## Layers

| File | Role |
|---|---|
| `AtomicHabits/AtomicHabitsApp.swift` | `@main` entry point. Creates the store and injects it into the view hierarchy. |
| `AtomicHabits/Models.swift` | Data model: `HabitKind` (build / quit), `Habit`, `UrgeLogEntry`, `AppData`, and `DayHelper` (date keys, streaks, last-14-days). Check-ins are stored as `yyyy-MM-dd` strings. Law checklists are a 4-element `[Bool]`. |
| `AtomicHabits/Store.swift` | `HabitStore` (`ObservableObject`). Persists `AppData` as JSON to `Application Support/AtomicHabits/habits.json` — on the phone only. Seeds the five starting habits on first launch only. |
| `AtomicHabits/ContentView.swift` | Today screen: "Today's Votes" tally (votes today, today %, this-week %, all-time), Build and Quit sections, habit rows with streak + last-14-days strip, Add Habit. |
| `AtomicHabits/HabitDetailViews.swift` | Habit detail/edit: identity statement, habit stack, 2-minute version, Four Laws checklist (build) / inverted laws, cost list, replacement habit (quit), never-miss-twice note, urge log. |
| `AtomicHabits/UrgeTimerView.swift` | 10-minute urge timer with progress ring (quit habits). |

## Data model parity

The model intentionally matches the design-prototype web app exactly
(habits / check-ins by date / law checks / urge logs, same five seeds), so the
finished design ports screen-for-screen and data concepts carry over 1:1.

## Principles

- Local-first: no server, no account, no network calls.
- Deleting the app deletes its data. There is no cloud copy.
- One feature per commit (see `docs/COMMIT-CONVENTIONS.md`).
