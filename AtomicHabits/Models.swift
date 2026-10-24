import Foundation

enum HabitKind: String, Codable, CaseIterable {
    case build
    case quit

    var title: String {
        switch self {
        case .build: return "Build"
        case .quit: return "Quit"
        }
    }
}

struct UrgeLogEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date = Date()
    var cue: String = ""
    var craving: String = ""
    var instead: String = ""
}

struct Habit: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: HabitKind
    var title: String
    var createdAt: Date = Date()

    // Build-habit design fields
    var identityStatement: String = ""
    var habitStack: String = ""
    var twoMinuteVersion: String = ""

    // Four Laws checklist. For Build: [obvious, attractive, easy, satisfying].
    // For Quit (inverted): [invisible, unattractive, hard, unsatisfying].
    var lawChecks: [Bool] = [false, false, false, false]

    // Quit-habit design fields
    var costList: String = ""
    var replacementHabit: String = ""

    // Check-ins stored as "yyyy-MM-dd" strings (local day).
    var checkinDates: [String] = []

    var urgeLogs: [UrgeLogEntry] = []

    // Normalises old / partial data so lawChecks always has exactly 4 entries.
    mutating func normalise() {
        if lawChecks.count < 4 {
            lawChecks += Array(repeating: false, count: 4 - lawChecks.count)
        } else if lawChecks.count > 4 {
            lawChecks = Array(lawChecks.prefix(4))
        }
    }

    func isChecked(on dayString: String) -> Bool {
        checkinDates.contains(dayString)
    }
}

struct AppData: Codable {
    var habits: [Habit] = []
    var seeded: Bool = false
}

enum DayHelper {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(for date: Date) -> String {
        formatter.string(from: date)
    }

    static func todayString() -> String {
        string(for: Date())
    }

    static func string(daysAgo: Int, from date: Date = Date()) -> String {
        let d = Calendar.current.date(byAdding: .day, value: -daysAgo, to: date) ?? date
        return string(for: d)
    }

    /// Consecutive checked days ending today, or ending yesterday if today
    /// has not been checked yet (the day is not over, so the streak lives).
    static func streak(for habit: Habit) -> Int {
        var count = 0
        var offset = habit.isChecked(on: todayString()) ? 0 : 1
        while habit.isChecked(on: string(daysAgo: offset)) {
            count += 1
            offset += 1
        }
        return count
    }

    /// True when there is real history before yesterday, yesterday was
    /// missed, and today is not checked yet.
    static func missedYesterday(for habit: Habit) -> Bool {
        guard !habit.isChecked(on: string(daysAgo: 1)) else { return false }
        guard !habit.isChecked(on: todayString()) else { return false }
        return habit.checkinDates.contains { $0 < string(daysAgo: 1) }
    }
}
