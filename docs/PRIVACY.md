# Privacy — Atomic Habits

**Data Not Collected.** Atomic Habits is local-first and offline:

- No account, no sign-in, no server, no analytics, no advertising, no tracking.
- All habits, check-ins, urge logs and reflections live only on the user's
  iPhone, in the app's own storage (or the on-device App Group container it
  shares with its own widget extension). Nothing leaves the device.
- **Notifications are local notifications**, scheduled on-device by iOS at
  each habit's cue time. No push server, no notification token, no remote
  delivery. Permission is requested only inside the app (onboarding's
  reminder step, or "Set anchor reminder" in a habit's Cue section) and can
  be revoked any time in iOS Settings.
- Deleting the app deletes its data permanently.

App Store privacy label: **Data Not Collected** (matches
`AtomicHabits/PrivacyInfo.xcprivacy`: tracking off, no collected data types,
no required-reason APIs declared because none are used).

If a cloud backend is ever added, this page and the App Store privacy
answers must be updated before that version ships.
