import Foundation
import Combine

/// On-device-only store. All data lives in a single Codable JSON file in
/// the app's Application Support folder. No server, no network, no account.
final class HabitStore: ObservableObject {
    @Published var habits: [Habit] = [] {
        didSet { save() }
    }

    private var seeded = false
    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("AtomicHabits", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("habits.json")
        load()
    }

    // MARK: - Persistence

    private func load() {
        let fm = FileManager.default
        if fm.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppData.self, from: data) {
            seeded = decoded.seeded
            habits = decoded.habits.map { habit in
                var h = habit
                h.normalise()
                return h
            }
            if !seeded {
                seedIfNeeded()
            }
        } else {
            seedIfNeeded()
        }
    }

    private func save() {
        // Avoid writing during the initial load / seed assignment churn
        // before a file exists and seeding has not finished.
        let payload = AppData(habits: habits, seeded: seeded)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: [.atomic])
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
        steps.twoMinuteVersion = "Put on my shoes and walk for 2 minutes."

        var workout = Habit(kind: .build, title: "Workout")
        workout.identityStatement = "I am a person who trains consistently."
        workout.habitStack = "After I get home from work, I will work out at the gym."
        workout.twoMinuteVersion = "Put on gym clothes and do one set."

        var protein = Habit(kind: .build, title: "Healthy protein meal")
        protein.identityStatement = "I am a person who fuels my body well."
        protein.habitStack = "After I plan dinner, I will include a protein source at home."
        protein.twoMinuteVersion = "Add one protein item to my plate."

        var read = Habit(kind: .build, title: "Read 10 pages")
        read.identityStatement = "I am a reader."
        read.habitStack = "After I get into bed, I will read 10 pages in my bedroom."
        read.twoMinuteVersion = "Read one page."

        var alcohol = Habit(kind: .quit, title: "Alcohol outside cheat days")
        alcohol.identityStatement = "I am a person who keeps my commitments."
        alcohol.costList = "Costs money\nHurts sleep and next-day energy\nAdds empty calories\nBreaks my 75-day challenge streak"
        alcohol.replacementHabit = "Have sparkling water, make tea, or go for a short walk."

        return [steps, workout, protein, read, alcohol]
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

    func toggleToday(id: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == id }) else { return }
        let today = DayHelper.todayString()
        if habits[idx].checkinDates.contains(today) {
            habits[idx].checkinDates.removeAll { $0 == today }
        } else {
            habits[idx].checkinDates.append(today)
            habits[idx].checkinDates.sort()
        }
    }
}
