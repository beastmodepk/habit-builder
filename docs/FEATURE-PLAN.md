# Feature plan

Development model: the design is iterated first in the web app prototype.
Once a piece of design is locked there, it lands here as **one feature = one
commit** (see `docs/COMMIT-CONVENTIONS.md`). Releases are tagged.

## v0.1.0 — MVP (current, tagged `v0.1.0`)

- [x] Xcode project scaffold, automatic signing, iPhone, iOS 17+
- [x] Data models + streak/date logic
- [x] On-device JSON store + first-launch seeding (5 habits)
- [x] Today screen: Today's Votes tally, Build / Quit sections
- [x] Habit detail: identity, stack, 2-minute version, Four Laws / inverted laws
- [x] Quit support: cost list, replacement habit, urge log, 10-minute urge timer
- [x] Add / edit / delete habits

## Next — design port (after the web-app design is locked)

- [ ] `feat(ui):` port the finished visual design (colours, typography, cards)
- [ ] `feat(today):` final Today-screen hierarchy from the locked design
- [ ] `feat(urge):` final urge-moment flow from the locked design

## Backlog (each lands as its own `feat:` commit when scheduled)

- [ ] `feat(notifications):` daily reminder at a chosen time
- [ ] `feat(widgets):` Home Screen widget with today's votes
- [ ] `feat(healthkit):` auto-count 10,000 steps from HealthKit
- [ ] `feat(export):` export / import data as JSON (backup & restore)
- [x] Hooks batch (branch feat/atomic-hooks): anchor reminders, next cue, environment prep, temptation bundling, identity board, habit contract, 2-minute mode, Goldilocks shrink, instant reward, rescue mode, weekly review, urge insights, saved counter, urge SOS + deep links, and all four widgets (small / medium interactive / Lock Screen / large)
- [ ] `test:` unit tests for streak and tally logic (test target)
