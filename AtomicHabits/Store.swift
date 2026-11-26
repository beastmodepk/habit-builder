import Foundation
import Combine

/// On-device-only store. All data lives in a single Codable JSON file —
/// in the App Group container when that entitlement is provisioned (so the
/// widgets share it), otherwise in the app's private Application Support
/// folder (the v0.1.0 behaviour). No server, no network, no account.
final class HabitStore: ObservableObject {
    @Published var habits: [Habit] = [] {
        didSet { save() }
    }
    @Published var weeklyReflections: [WeeklyReflection] = [] {
        didSet { save() }
    }

    // Onboarding meta (see AppData). Persisted in the same file.
    @Published var hasOnboarded: Bool = false {
        didSet { save() }
    }
    @Published var userName: String = "" {
        didSet { save() }
    }
    @Published var onboardingPath: String = "" {
        didSet { save() }
    }

    /// True when, at launch, the store held nothing the user had recorded:
    /// no data file yet (fresh install), or only untouched seeded habits
    /// with no check-ins, urge logs or reflections. Captured once at load;
    /// enrollment is only ever offered from this pristine state, and it
    /// never deletes or alters existing habits.
    private(set) var launchedPristine = false

    var shouldPresentOnboarding: Bool {
        !hasOnboarded && launchedPristine
    }

    private var seeded = false
    private var isReady = false
    private let fileURL: URL

    init() {
        if let shared = SharedStore.sharedFileURL() {
            fileURL = shared
        } else {
            let fm = FileManager.default
            let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dir = base.appendingPathComponent("AtomicHabits", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            fileURL = dir.appendingPathComponent("habits.json")
        }
        load()
        isReady = true
        save()
    }

    // MARK: - Persistence

    private func load() {
        if let decoded = SharedStore.loadData(from: fileURL) {
            seeded = decoded.seeded
            hasOnboarded = decoded.hasOnboarded
            userName = decoded.userName
            onboardingPath = decoded.onboardingPath
            launchedPristine = decoded.weeklyReflections.isEmpty
                && decoded.habits.allSatisfy { $0.checkinDates.isEmpty && $0.urgeLogs.isEmpty }
            weeklyReflections = decoded.weeklyReflections
            habits = decoded.habits.map { habit in
                var h = habit
                h.normalise()
                return h
            }
            if !seeded {
                seedIfNeeded()
            }
        } else {
            launchedPristine = true
            seedIfNeeded()
        }
    }

    private func save() {
        guard isReady else { return }
        let payload = AppData(habits: habits, seeded: seeded, weeklyReflections: weeklyReflections,
                              hasOnboarded: hasOnboarded, userName: userName,
                              onboardingPath: onboardingPath)
        SharedStore.saveData(payload, to: fileURL)
    }

    // MARK: - Seeding (first launch only)

    private func seedIfNeeded() {
        guard !seeded else { return }
        seeded = true
        habits = Self.seedHabits()
    }

    static func seedHabits() -> [Habit] {
        var steps = Habit(kind: .build, title: "10,000 steps")
        steps.identityStatement = "I am a person who moves every day."
        steps.habitStack = "After I finish lunch, I will walk at my neighbourhood / office route."
        steps.anchor = "finish lunch"
        steps.cueTime = "13:00"
        steps.cuePlace = "office route"
        steps.twoMinuteVersion = "Put on my shoes and walk for 2 minutes."
        steps.temptationBundle = "Only listen to my favourite podcast while walking."
        steps.rewardText = "A quiet coffee after the walk."
        steps.prepItems = [PrepItem(title: "Shoes by the door")]
        steps.healthMetric = "stepCount"
        steps.healthGoal = 10000

        var workout = Habit(kind: .build, title: "Workout")
        workout.identityStatement = "I am a person who trains consistently."
        workout.habitStack = "After I get home from work, I will work out at the gym."
        workout.anchor = "get home from work"
        workout.cueTime = "18:00"
        workout.cuePlace = "gym"
        workout.twoMinuteVersion = "Put on gym clothes and do one set."
        workout.rewardText = "Sauna / long shower after training."
        workout.prepItems = [PrepItem(title: "Gym bag packed by the door")]

        var protein = Habit(kind: .build, title: "Healthy protein meal")
        protein.identityStatement = "I am a person who fuels my body well."
        protein.habitStack = "After I plan dinner, I will include a protein source at home."
        protein.anchor = "plan dinner"
        protein.cuePlace = "home"
        protein.twoMinuteVersion = "Add one protein item to my plate."

        var read = Habit(kind: .build, title: "Read 10 pages")
        read.identityStatement = "I am a reader."
        read.habitStack = "After I get into bed, I will read 10 pages in my bedroom."
        read.anchor = "get into bed"
        read.cueTime = "22:00"
        read.cuePlace = "bedroom"
        read.twoMinuteVersion = "Read one page."
        read.prepItems = [PrepItem(title: "Book on the pillow")]

        var alcohol = Habit(kind: .quit, title: "Alcohol outside cheat days")
        alcohol.identityStatement = "I am a person who keeps my commitments."
        alcohol.costList = "Costs money\nHurts sleep and next-day energy\nAdds empty calories\nBreaks my 75-day challenge streak"
        alcohol.replacementHabit = "Have sparkling water, make tea, or go for a short walk."
        alcohol.dailyCost = 12
        alcohol.contract = HabitContract(
            commitment: "I will not drink alcohol outside my planned cheat days during the 75-day challenge.",
            consequence: "If I break this, I restart the count and tell my witness the same day.",
            witness: "Shannon"
        )

        // Added 2026-11-25 via the AI-coach trial dialog; confirmed by
        // Parthey ("Add this to the defaults").
        var standup = Habit(kind: .build, title: "Speak up in standup")
        standup.identityStatement = "I am an assertive person."
        standup.habitStack = "During standup, I will give a proper update on my previous day and my plans for today."
        standup.anchor = "standup"
        standup.cuePlace = ""
        standup.twoMinuteVersion = "Share just one line — one thing from yesterday + one plan for today."
        standup.rewardText = "I start the day clear, and seen as someone who knows his work."
        standup.prepItems = [PrepItem(title: "Log: yesterday what I did/finished + today's todo plans")]

        return [steps, workout, protein, read, alcohol, standup]
    }

    // MARK: - Onboarding

    /// "Explore first / I already have a setup": closes enrollment without
    /// creating anything. Existing (seeded) habits stay exactly as they are.
    func skipOnboarding() {
        hasOnboarded = true
    }

    /// Records the completed enrollment: who this is and which path they
    /// took. The generated habits themselves are added via `add(_:)`.
    func completeOnboarding(name: String, path: String) {
        userName = name
        onboardingPath = path
        hasOnboarded = true
    }

    // MARK: - Mutations

    func habit(id: UUID) -> Habit? {
        habits.first { $0.id == id }
    }

    func add(_ habit: Habit) {
        habits.append(habit)
    }

    func update(_ habit: Habit) {
        guard let idx = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        var h = habit
        h.normalise()
        habits[idx] = h
    }

    func delete(id: UUID) {
        habits.removeAll { $0.id == id }
    }

    /// Toggle a check-in on an explicit day ("yyyy-MM-dd"), recording how
    /// it was done (full vs 2-minute). Backs the Today tab's Today /
    /// Yesterday switcher, so a forgotten day can still be logged.
    func toggleCheckin(id: UUID, on day: String, kind: CheckinKind = .full) {
        guard let idx = habits.firstIndex(where: { $0.id == id }) else { return }
        if habits[idx].checkinDates.contains(day) {
            habits[idx].checkinDates.removeAll { $0 == day }
            habits[idx].checkinKinds[day] = nil
        } else {
            habits[idx].checkinDates.append(day)
            habits[idx].checkinDates.sort()
            habits[idx].checkinKinds[day] = kind.rawValue
        }
    }

    /// Toggle today's check-in, recording how it was done (full vs 2-minute).
    func toggleToday(id: UUID, kind: CheckinKind = .full) {
        toggleCheckin(id: id, on: DayHelper.todayString(), kind: kind)
    }

    /// Apple Health goal reached for a day: add a full check-in for
    /// that day only if one is absent. Never removes anything — a later
    /// step-data dip never takes a win back.
    func markHealthGoalReached(id: UUID, on day: String) {
        guard let idx = habits.firstIndex(where: { $0.id == id }) else { return }
        guard !habits[idx].checkinDates.contains(day) else { return }
        habits[idx].checkinDates.append(day)
        habits[idx].checkinDates.sort()
        habits[idx].checkinKinds[day] = CheckinKind.full.rawValue
    }

    /// Log a 2-minute vote on an explicit day (2-Minute Mode).
    func logTwoMinute(id: UUID, on day: String) {
        guard let idx = habits.firstIndex(where: { $0.id == id }) else { return }
        if !habits[idx].checkinDates.contains(day) {
            habits[idx].checkinDates.append(day)
            habits[idx].checkinDates.sort()
        }
        habits[idx].checkinKinds[day] = CheckinKind.twoMinute.rawValue
    }

    /// Log today explicitly as a 2-minute vote (2-Minute Mode).
    func logTwoMinuteToday(id: UUID) {
        logTwoMinute(id: id, on: DayHelper.todayString())
    }

    func saveReflection(_ reflection: WeeklyReflection) {
        if let idx = weeklyReflections.firstIndex(where: { $0.weekStart == reflection.weekStart }) {
            weeklyReflections[idx] = reflection
        } else {
            weeklyReflections.append(reflection)
        }
    }
}
