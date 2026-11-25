import Foundation

/// A habit being designed in the AI chat Add flow, before the user confirms
/// it. Mirrors `Habit`'s design fields 1:1 so confirming is a straight map
/// to `Habit` + `store.add(_:)` — habits.json is unchanged, no migration,
/// existing users' data untouched.
struct HabitDraft: Codable, Equatable {
    var kind: HabitKind = .build
    var title: String = ""
    var identityStatement: String = ""

    // Cue design
    var anchor: String = ""          // the preceding action in the stack
    var cueTime: String = ""         // "HH:mm", empty = no set time
    var cuePlace: String = ""

    // Build design
    var twoMinuteVersion: String = ""
    var temptationBundle: String = ""
    var rewardText: String = ""
    var prepItems: [String] = []

    // Quit design
    var costList: String = ""
    var replacementHabit: String = ""
    var dailyCost: Double = 0

    /// The habit-stack sentence, composed from the cue parts the coach
    /// collected ("After I [anchor], I will [title] at [place].").
    var habitStack: String {
        let action = title.isEmpty ? "do it" : title.prefix(1).lowercased() + title.dropFirst()
        var parts = "I will \(action)"
        if !anchor.isEmpty {
            parts = "After I \(anchor), \(parts)"
        }
        if !cuePlace.isEmpty {
            parts += " at \(cuePlace)"
        }
        return parts + "."
    }

    /// Map to the persisted model. Only called from the confirmation card's
    /// Add button — nothing is saved before that tap.
    func makeHabit() -> Habit {
        var habit = Habit(kind: kind, title: title.trimmingCharacters(in: .whitespacesAndNewlines))
        habit.identityStatement = identityStatement
        habit.habitStack = habitStack
        habit.anchor = anchor
        habit.cueTime = cueTime
        habit.cuePlace = cuePlace
        habit.twoMinuteVersion = twoMinuteVersion
        habit.temptationBundle = temptationBundle
        habit.rewardText = rewardText
        habit.prepItems = prepItems
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { PrepItem(title: $0) }
        habit.costList = costList
        habit.replacementHabit = replacementHabit
        habit.dailyCost = dailyCost
        return habit
    }
}

/// Seam for the suggestion engine behind the coach. The deterministic
/// template engine is the always-available v1 path (every iOS 17+ device,
/// offline, no key, no network — the app's "no server, no account" promise
/// stays intact).
protocol HabitSuggestionEngine {
    /// 2–3 candidate actions for an identity, used when the user gave an
    /// identity but no concrete habit yet.
    func candidateActions(forIdentity identity: String) -> [String]
    /// Candidate anchors ("after what / when") for a goal.
    func candidateAnchors(for draft: HabitDraft) -> [String]
    /// A proposed 2-minute version of the habit.
    func twoMinuteVersion(for draft: HabitDraft) -> String
    /// A proposed prep item, or nil when none fits.
    func prepItem(for draft: HabitDraft) -> String?
    /// Quit path: a draft cost list for the behaviour being quit.
    func costList(for draft: HabitDraft) -> String
    /// Quit path: candidate replacements for the behaviour being quit.
    func candidateReplacements(for draft: HabitDraft) -> [String]
}

/// Deterministic keyword-template engine. Same flow and guardrails as any
/// smarter engine; only the phrasing is templated.
struct TemplateSuggestionEngine: HabitSuggestionEngine {

    func candidateActions(forIdentity identity: String) -> [String] {
        let text = identity.lowercased()
        if text.contains("assertive") || text.contains("confident") {
            return ["Speak up once in a meeting", "Say no when I mean no", "State my preference directly"]
        }
        if text.contains("calm") || text.contains("focus") || text.contains("patient") {
            return ["Meditate in the morning", "Take a 5-minute walk without my phone", "Write three lines in a journal"]
        }
        if text.contains("fit") || text.contains("strong") || text.contains("healthy") || text.contains("athlet") {
            return ["Workout", "Walk 10,000 steps", "Eat a healthy protein meal"]
        }
        if text.contains("read") || text.contains("learn") || text.contains("smart") || text.contains("curious") {
            return ["Read 10 pages", "Study for 15 minutes", "Listen to one educational podcast"]
        }
        if text.contains("phone") || text.contains("present") || text.contains("distract") {
            return ["No phone in bed", "No phone for the first hour", "Keep my phone in another room while I work"]
        }
        if text.contains("organised") || text.contains("organized") || text.contains("tidy") {
            return ["Clear my desk before bed", "Plan tomorrow in three lines", "Put everything back after I use it"]
        }
        return ["Take a daily walk", "Read 10 pages", "Write three lines in a journal"]
    }

    func candidateAnchors(for draft: HabitDraft) -> [String] {
        let text = draft.title.lowercased()
        if text.contains("standup") || text.contains("meeting") {
            return ["In standup", "In my first meeting each day", "Whenever I have an idea or disagree"]
        }
        if text.contains("meditat") || text.contains("journal") || text.contains("plan tomorrow") {
            return ["After I wake up", "After I make coffee", "After I get into bed"]
        }
        if text.contains("read") || text.contains("bed") || text.contains("phone") {
            return ["After I get into bed", "After dinner", "After I brush my teeth"]
        }
        if text.contains("workout") || text.contains("gym") {
            return ["After I get home from work", "After I wake up", "After lunch"]
        }
        if text.contains("walk") || text.contains("steps") {
            return ["After lunch", "After dinner", "After I finish work"]
        }
        return ["After I wake up", "After lunch", "After I get home from work"]
    }

    func twoMinuteVersion(for draft: HabitDraft) -> String {
        let text = draft.title.lowercased()
        if text.contains("meditat") { return "Sit and breathe for 2 minutes." }
        if text.contains("read") { return "Read one page." }
        if text.contains("walk") || text.contains("steps") { return "Put on my shoes and walk for 2 minutes." }
        if text.contains("workout") || text.contains("gym") { return "Put on gym clothes and do one set." }
        if text.contains("speak") || text.contains("standup") { return "Share just one line — one thing from yesterday + one plan for today." }
        if text.contains("journal") || text.contains("write") { return "Write one line." }
        if text.contains("phone") { return "Leave my phone outside the room for 2 minutes." }
        let action = draft.title.prefix(1).lowercased() + draft.title.dropFirst()
        return "Do the smallest version: \(action) for 2 minutes."
    }

    func prepItem(for draft: HabitDraft) -> String? {
        let text = draft.title.lowercased()
        if text.contains("read") { return "Book on the pillow" }
        if text.contains("workout") || text.contains("gym") { return "Gym bag packed by the door" }
        if text.contains("walk") || text.contains("steps") { return "Shoes by the door" }
        if text.contains("meditat") { return "Cushion out where I will see it" }
        if text.contains("phone") { return "Charger outside the bedroom" }
        if text.contains("speak") || text.contains("standup") { return "Log: yesterday what I did/finished + today's todo plans" }
        if text.contains("journal") || text.contains("write") { return "Notebook and pen on the desk" }
        return nil
    }

    func costList(for draft: HabitDraft) -> String {
        let text = draft.title.lowercased()
        if text.contains("phone") {
            return "Costs sleep and next-morning energy\nFeeds distraction instead of rest\nSteals time from reading and people"
        }
        if text.contains("alcohol") || text.contains("drink") {
            return "Costs money\nHurts sleep and next-day energy\nAdds empty calories"
        }
        if text.contains("smok") || text.contains("vape") {
            return "Costs money every day\nHurts health and stamina\nControls my schedule instead of me"
        }
        if text.contains("sugar") || text.contains("snack") || text.contains("junk") {
            return "Costs energy and focus\nAdds empty calories\nMakes the next craving stronger"
        }
        return "Costs time and energy\nWorks against who I want to be\nMakes the next urge stronger"
    }

    func candidateReplacements(for draft: HabitDraft) -> [String] {
        let text = draft.title.lowercased()
        if text.contains("phone") {
            return ["Read 10 pages instead", "Leave my phone charging outside the bedroom", "Listen to music or a podcast instead"]
        }
        if text.contains("alcohol") || text.contains("drink") {
            return ["Have sparkling water or make tea", "Go for a short walk", "Text a friend instead"]
        }
        return ["Go for a short walk", "Make a tea or a glass of water", "Do the 2-minute version of a build habit instead"]
    }
}

#if canImport(FoundationModels)
// TODO(v2): on-device Foundation Models engine. Deployment target stays
// iOS 17.0, so this type is only compiled where the SDK ships the
// framework and only used behind an iOS 26 availability check; the
// template engine above remains the fallback on every other device.
// Deliberately no model calls yet — v1 ships the deterministic path so
// the flow, guardrails and confirmation are identical for everyone.
@available(iOS 26, *)
final class FoundationModelsSuggestionEngine {
    /// Checked by the coach before this engine would ever be preferred.
    var isModelAvailable: Bool { false }
}
#endif
