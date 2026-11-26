import Foundation

/// One self-awarding accomplishment badge, computed purely from habit
/// history. There is nothing to claim: when the numbers cross the
/// target, the badge is earned.
struct AccomplishmentBadge: Identifiable, Equatable {
    var id: String
    var title: String
    var systemImage: String
    /// Units needed to earn (wins, days, perfect days…).
    var target: Int
    /// Current progress in the same units (clamped at the target).
    var progress: Int
    /// When the badge was earned, where that can be computed.
    var earnedDate: Date? = nil

    var earned: Bool { progress >= target }
    var ratio: Double {
        target > 0 ? min(1, Double(progress) / Double(target)) : 0
    }
}

/// The accomplishments engine: derives every badge from the habits'
/// check-in history. Pure and deterministic — same history, same badges.
enum Accomplishments {
    static func evaluate(habits: [Habit]) -> [AccomplishmentBadge] {
        let totalWins = habits.reduce(0) { $0 + $1.checkinDates.count }

        // MARK: Cumulative wins (First Win / 100 / 500)
        func cumulativeDate(threshold: Int) -> Date? {
            guard threshold > 0 else { return nil }
            var byDay: [String: Int] = [:]
            for habit in habits {
                for day in habit.checkinDates { byDay[day, default: 0] += 1 }
            }
            var running = 0
            for day in byDay.keys.sorted() {
                running += byDay[day] ?? 0
                if running >= threshold { return DayHelper.date(fromDayString: day) }
            }
            return nil
        }

        // MARK: Streaks (longest consecutive-day run per habit)
        /// Longest run of consecutive checked days, and the end date of
        /// the first run that reaches `threshold` (nil threshold = best).
        func longestRun(for habit: Habit) -> (length: Int, endDate: Date?) {
            let days = habit.checkinDates.sorted()
            var best = 0
            var bestEnd: Date? = nil
            var run = 0
            var previous: Date? = nil
            for day in days {
                guard let date = DayHelper.date(fromDayString: day) else { continue }
                if let prev = previous,
                   Calendar.current.date(byAdding: .day, value: 1, to: prev) == date {
                    run += 1
                } else {
                    run = 1
                }
                if run > best {
                    best = run
                    bestEnd = date
                }
                previous = date
            }
            return (best, bestEnd)
        }

        func streakBadge(id: String, title: String, image: String, target: Int) -> AccomplishmentBadge {
            var progress = 0
            var earnedDate: Date? = nil
            for habit in habits {
                let run = longestRun(for: habit)
                progress = max(progress, run.length)
                if run.length >= target, earnedDate == nil {
                    earnedDate = run.endDate
                }
            }
            return AccomplishmentBadge(id: id, title: title, systemImage: image,
                                       target: target, progress: min(progress, target),
                                       earnedDate: progress >= target ? earnedDate : nil)
        }

        // MARK: Perfect days / weeks (every current habit checked)
        let allDays = Set(habits.flatMap { $0.checkinDates }).sorted()
        let perfectDays: [String] = habits.isEmpty ? [] : allDays.filter { day in
            habits.allSatisfy { $0.isChecked(on: day) }
        }
        let perfectDayBadge = AccomplishmentBadge(
            id: "perfectDay", title: "Perfect Day", systemImage: "sun.max.fill",
            target: 1, progress: perfectDays.isEmpty ? 0 : 1,
            earnedDate: perfectDays.first.flatMap { DayHelper.date(fromDayString: $0) })

        var longestPerfectRun = 0
        var perfectWeekDate: Date? = nil
        do {
            var run = 0
            var previous: Date? = nil
            for day in perfectDays {
                guard let date = DayHelper.date(fromDayString: day) else { continue }
                if let prev = previous,
                   Calendar.current.date(byAdding: .day, value: 1, to: prev) == date {
                    run += 1
                } else {
                    run = 1
                }
                longestPerfectRun = max(longestPerfectRun, run)
                if run >= 7, perfectWeekDate == nil { perfectWeekDate = date }
                previous = date
            }
        }
        let perfectWeekBadge = AccomplishmentBadge(
            id: "perfectWeek", title: "Perfect Week", systemImage: "calendar.badge.checkmark",
            target: 7, progress: min(longestPerfectRun, 7),
            earnedDate: perfectWeekDate)

        // MARK: Clean days (best single quit habit's total check-ins)
        func cleanBadge(id: String, title: String, target: Int) -> AccomplishmentBadge {
            var best = 0
            var earnedDate: Date? = nil
            for habit in habits where habit.kind == .quit {
                best = max(best, habit.checkinDates.count)
                if habit.checkinDates.count >= target, earnedDate == nil {
                    let sorted = habit.checkinDates.sorted()
                    earnedDate = DayHelper.date(fromDayString: sorted[target - 1])
                }
            }
            return AccomplishmentBadge(id: id, title: title, systemImage: "shield.fill",
                                       target: target, progress: min(best, target),
                                       earnedDate: earnedDate)
        }

        // MARK: Comeback (a check-in after ≥2 missed days, with history)
        var comebackDate: Date? = nil
        for habit in habits {
            let days = habit.checkinDates.sorted()
            for index in 1..<max(days.count, 1) where days.count > 1 {
                guard let prev = DayHelper.date(fromDayString: days[index - 1]),
                      let current = DayHelper.date(fromDayString: days[index]) else { continue }
                let gap = Calendar.current.dateComponents([.day], from: prev, to: current).day ?? 0
                if gap - 1 >= 2 {
                    let date = current
                    if comebackDate == nil || date < comebackDate! { comebackDate = date }
                }
            }
        }

        return [
            AccomplishmentBadge(id: "firstWin", title: "First Win", systemImage: "star.fill",
                                target: 1, progress: min(totalWins, 1),
                                earnedDate: cumulativeDate(threshold: 1)),
            streakBadge(id: "streak7", title: "7-Day Streak", image: "flame.fill", target: 7),
            streakBadge(id: "streak30", title: "30-Day Streak", image: "flame.circle.fill", target: 30),
            perfectDayBadge,
            perfectWeekBadge,
            AccomplishmentBadge(id: "wins100", title: "100 Wins", systemImage: "medal.fill",
                                target: 100, progress: min(totalWins, 100),
                                earnedDate: cumulativeDate(threshold: 100)),
            AccomplishmentBadge(id: "wins500", title: "500 Wins", systemImage: "trophy.fill",
                                target: 500, progress: min(totalWins, 500),
                                earnedDate: cumulativeDate(threshold: 500)),
            cleanBadge(id: "clean30", title: "30 Clean Days", target: 30),
            cleanBadge(id: "clean100", title: "100 Clean Days", target: 100),
            AccomplishmentBadge(id: "comeback", title: "Comeback", systemImage: "arrow.uturn.backward.circle.fill",
                                target: 1, progress: comebackDate == nil ? 0 : 1,
                                earnedDate: comebackDate),
        ]
    }
}
