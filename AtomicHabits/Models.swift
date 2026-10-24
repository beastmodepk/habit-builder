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

enum CheckinKind: String, Codable {
    case full
    case twoMinute
}

struct PrepItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String = ""
    var done: Bool = false
}

struct HabitContract: Codable, Equatable {
    var commitment: String = ""
    var consequence: String = ""
    var witness: String = ""
    var isSigned: Bool = false
    var signedDate: String = ""   // "yyyy-MM-dd"
}

struct UrgeLogEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date = Date()
    var cue: String = ""
    var craving: String = ""
    var instead: String = ""
    // 0 = not recorded, 1...10 = reported intensity.
    var intensityBefore: Int = 0
    var intensityAfter: Int = 0
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

    // Cue design (hooks): when / where / after what this habit fires.
    var cueTime: String = ""        // "HH:mm", empty = no set time
    var cuePlace: String = ""
    var anchor: String = ""         // the preceding action in the stack

    // Craving design (hooks)
    var temptationBundle: String = ""

    // Reward design (hooks): the immediate reward text shown on completion.
    var rewardText: String = ""

    // Environment prep checklist (hooks)
    var prepItems: [PrepItem] = []

    // Habit contract (quit habits): commitment / consequence / witness.
    var contract: HabitContract = HabitContract()

    // Saved counter (quit habits): monetary cost per day of the habit.
    var dailyCost: Double = 0

    // Goldilocks shrink state: while `shrunkUntil` >= today, the habit is
    // temporarily scaled to `shrunkGoal` (defaults to the 2-minute version).
    var shrunkUntil: String = ""
    var shrunkGoal: String = ""

    // Check-ins stored as "yyyy-MM-dd" strings (local day).
    var checkinDates: [String] = []
    // How each check-in was done: day string -> CheckinKind raw value.
    var checkinKinds: [String: String] = [:]

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

    func checkinKind(on dayString: String) -> CheckinKind {
        CheckinKind(rawValue: checkinKinds[dayString] ?? "") ?? .full
    }

    var isShrunkToday: Bool {
        !shrunkUntil.isEmpty && shrunkUntil >= DayHelper.todayString()
    }
}

struct WeeklyReflection: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var weekStart: String = ""     // "yyyy-MM-dd" of the Monday of that week
    var wins: String = ""
    var lessons: String = ""
    var focus: String = ""
    var createdAt: Date = Date()
}

struct AppData: Codable {
    var habits: [Habit] = []
    var seeded: Bool = false
    var weeklyReflections: [WeeklyReflection] = []
}

// MARK: - Backward-compatible decoding
// Every field added after v0.1.0 decodes with its default when the key is
// missing, so a habits.json written by the original MVP still loads.

extension KeyedDecodingContainer {
    fileprivate func dec<T: Decodable>(_ type: T.Type, _ key: Key, fallback: T) throws -> T {
        try decodeIfPresent(type, forKey: key) ?? fallback
    }
}

extension Habit {
    enum CodingKeys: String, CodingKey {
        case id, kind, title, createdAt, identityStatement, habitStack, twoMinuteVersion
        case lawChecks, costList, replacementHabit, cueTime, cuePlace, anchor
        case temptationBundle, rewardText, prepItems, contract, dailyCost
        case shrunkUntil, shrunkGoal, checkinDates, checkinKinds, urgeLogs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.dec(UUID.self, .id, fallback: UUID())
        kind = try c.dec(HabitKind.self, .kind, fallback: .build)
        title = try c.dec(String.self, .title, fallback: "")
        createdAt = try c.dec(Date.self, .createdAt, fallback: Date())
        identityStatement = try c.dec(String.self, .identityStatement, fallback: "")
        habitStack = try c.dec(String.self, .habitStack, fallback: "")
        twoMinuteVersion = try c.dec(String.self, .twoMinuteVersion, fallback: "")
        lawChecks = try c.dec([Bool].self, .lawChecks, fallback: [false, false, false, false])
        costList = try c.dec(String.self, .costList, fallback: "")
        replacementHabit = try c.dec(String.self, .replacementHabit, fallback: "")
        cueTime = try c.dec(String.self, .cueTime, fallback: "")
        cuePlace = try c.dec(String.self, .cuePlace, fallback: "")
        anchor = try c.dec(String.self, .anchor, fallback: "")
        temptationBundle = try c.dec(String.self, .temptationBundle, fallback: "")
        rewardText = try c.dec(String.self, .rewardText, fallback: "")
        prepItems = try c.dec([PrepItem].self, .prepItems, fallback: [])
        contract = try c.dec(HabitContract.self, .contract, fallback: HabitContract())
        dailyCost = try c.dec(Double.self, .dailyCost, fallback: 0)
        shrunkUntil = try c.dec(String.self, .shrunkUntil, fallback: "")
        shrunkGoal = try c.dec(String.self, .shrunkGoal, fallback: "")
        checkinDates = try c.dec([String].self, .checkinDates, fallback: [])
        checkinKinds = try c.dec([String: String].self, .checkinKinds, fallback: [:])
        urgeLogs = try c.dec([UrgeLogEntry].self, .urgeLogs, fallback: [])
    }
}

extension UrgeLogEntry {
    enum CodingKeys: String, CodingKey {
        case id, date, cue, craving, instead, intensityBefore, intensityAfter
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.dec(UUID.self, .id, fallback: UUID())
        date = try c.dec(Date.self, .date, fallback: Date())
        cue = try c.dec(String.self, .cue, fallback: "")
        craving = try c.dec(String.self, .craving, fallback: "")
        instead = try c.dec(String.self, .instead, fallback: "")
        intensityBefore = try c.dec(Int.self, .intensityBefore, fallback: 0)
        intensityAfter = try c.dec(Int.self, .intensityAfter, fallback: 0)
    }
}

extension PrepItem {
    enum CodingKeys: String, CodingKey { case id, title, done }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.dec(UUID.self, .id, fallback: UUID())
        title = try c.dec(String.self, .title, fallback: "")
        done = try c.dec(Bool.self, .done, fallback: false)
    }
}

extension HabitContract {
    enum CodingKeys: String, CodingKey { case commitment, consequence, witness, isSigned, signedDate }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        commitment = try c.dec(String.self, .commitment, fallback: "")
        consequence = try c.dec(String.self, .consequence, fallback: "")
        witness = try c.dec(String.self, .witness, fallback: "")
        isSigned = try c.dec(Bool.self, .isSigned, fallback: false)
        signedDate = try c.dec(String.self, .signedDate, fallback: "")
    }
}

extension WeeklyReflection {
    enum CodingKeys: String, CodingKey { case id, weekStart, wins, lessons, focus, createdAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.dec(UUID.self, .id, fallback: UUID())
        weekStart = try c.dec(String.self, .weekStart, fallback: "")
        wins = try c.dec(String.self, .wins, fallback: "")
        lessons = try c.dec(String.self, .lessons, fallback: "")
        focus = try c.dec(String.self, .focus, fallback: "")
        createdAt = try c.dec(Date.self, .createdAt, fallback: Date())
    }
}

extension AppData {
    enum CodingKeys: String, CodingKey { case habits, seeded, weeklyReflections }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        habits = try c.dec([Habit].self, .habits, fallback: [])
        seeded = try c.dec(Bool.self, .seeded, fallback: false)
        weeklyReflections = try c.dec([WeeklyReflection].self, .weeklyReflections, fallback: [])
    }
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

    static func date(fromDayString day: String) -> Date? {
        formatter.date(from: day)
    }

    /// Consecutive checked days ending today, or ending yesterday if today
    /// has not been checked yet (the day is not over, so the streak lives).
    /// Rescue rule ("never miss twice"): a single missed yesterday does NOT
    /// break the streak when today is checked and the habit has history
    /// before the miss — today's rescue completion bridges the gap. The
    /// missed day itself is not counted as a vote.
    static func streak(for habit: Habit) -> Int {
        var count = 0
        var offset = habit.isChecked(on: todayString()) ? 0 : 1
        var rescueUsed = false
        while true {
            if habit.isChecked(on: string(daysAgo: offset)) {
                count += 1
                offset += 1
            } else if !rescueUsed,
                      offset == 1,
                      habit.isChecked(on: todayString()),
                      habit.isChecked(on: string(daysAgo: 2)) {
                // Rescue bridge over yesterday's miss.
                rescueUsed = true
                offset += 1
            } else {
                break
            }
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

    /// True when the habit is in Rescue Mode today: yesterday was missed
    /// (with history) and today can still rescue the streak.
    static func rescueAvailable(for habit: Habit) -> Bool {
        missedYesterday(for: habit) && habit.isChecked(on: string(daysAgo: 2))
    }

    /// How many of the last `days` days (including today) were missed.
    static func missedCount(for habit: Habit, lastDays days: Int) -> Int {
        (0..<days).filter { !habit.isChecked(on: string(daysAgo: $0)) }.count
    }

    /// Goldilocks signal: missed at least 2 of the last 3 days.
    static func needsShrink(for habit: Habit) -> Bool {
        missedCount(for: habit, lastDays: 3) >= 2 && !habit.checkinDates.isEmpty
    }

    /// Votes cast by a set of habits on a given day string.
    static func votes(_ habits: [Habit], on day: String) -> Int {
        habits.filter { $0.isChecked(on: day) }.count
    }

    /// Total votes cast across the last `days` days including today.
    static func votes(_ habits: [Habit], lastDays days: Int) -> Int {
        (0..<days).reduce(0) { $0 + votes(habits, on: string(daysAgo: $1)) }
    }

    /// Monday (yyyy-MM-dd) of the week containing `date`.
    static func weekStartString(for date: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return string(for: cal.date(from: comps) ?? date)
    }
}
