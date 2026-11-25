import Foundation
import Combine

/// One chat bubble in the Habit Coach conversation.
struct CoachMessage: Identifiable, Equatable {
    enum Role: Equatable { case coach, user }
    let id = UUID()
    var role: Role
    var text: String
}

/// What the coach is asking right now. The view renders each step's
/// question, its tappable options and the non-clickable hint row.
enum CoachStep: Equatable {
    case welcome          // returning open: add / check in / review
    case identity         // "Who do you want to be?" — always first in a build
    case goal             // one small action that person does
    case anchor           // after what / when / where
    case replacement      // quit only: cost is generated, replacement is picked
    case shrink           // 2-minute version
    case confirm          // confirmation card; nothing saved before Add
    case done             // added, cancelled, or session expired
}

/// Actions the welcome step can hand back to the tab container.
enum CoachWelcomeAction: Equatable {
    case checkInToday
    case reviewHabits
}

/// Guided Habit Coach — a state machine, NOT an open chatbot.
///
/// Flow: IDENTITY → GOAL → ANCHOR → (REPLACEMENT, quit only) → SHRINK →
/// CONFIRM. Max 2 clarifying questions. One habit per session.
///
/// Guardrails (Parthey's explicit requirement — stay on topic):
/// - Only messages about the habit being built advance the flow.
/// - An off-topic message gets ONE fixed redirect naming the current step;
///   its content is never answered.
/// - A second consecutive off-topic message offers Continue / Cancel.
/// - No medical/financial/general advice, no second habit mid-flow.
/// - Session ends on Add, Cancel, or 10 turns without progress.
final class HabitCoach: ObservableObject {
    @Published private(set) var messages: [CoachMessage] = []
    @Published private(set) var step: CoachStep = .identity
    @Published private(set) var options: [String] = []
    @Published private(set) var draft = HabitDraft()
    @Published var welcomeAction: CoachWelcomeAction? = nil

    private let engine: HabitSuggestionEngine
    private var started = false
    private var offTopicStrikes = 0
    private var clarifyingAsked = 0
    private var turnsWithoutProgress = 0
    /// Candidate actions proposed at the goal step (from the identity).
    private var candidateActions: [String] = []

    init(engine: HabitSuggestionEngine = TemplateSuggestionEngine()) {
        self.engine = engine
    }

    var isFinished: Bool { step == .done }

    // MARK: - Session start

    /// - Parameter returning: true when the store already has habits the
    ///   user works on (a returning open). A half-built draft in this
    ///   session is resumed instead of restarted.
    func start(returning: Bool) {
        if started {
            // Resume: re-ask the current question, keep the draft.
            if step != .done {
                say(currentQuestion())
                options = currentOptions()
            }
            return
        }
        started = true
        if returning {
            step = .welcome
            say("Welcome back. What shall we do?")
            options = ["Add a new habit", "Check in today", "Review my habits"]
        } else {
            beginIdentity()
        }
    }

    /// Start over from scratch (confirmation card's Start over button).
    func reset() {
        draft = HabitDraft()
        offTopicStrikes = 0
        clarifyingAsked = 0
        turnsWithoutProgress = 0
        candidateActions = []
        welcomeAction = nil
        beginIdentity()
    }

    private func beginIdentity() {
        step = .identity
        say("Let's build this from who you want to be, not just what you want to do.\n\nWho do you want to be?")
        options = ["An assertive person", "Calm and focused", "A fit, healthy person"]
    }

    // MARK: - Input

    /// A tapped suggestion chip.
    func selectOption(_ option: String) {
        guard step != .done else { return }
        echo(option)
        handle(answer: option, wasOption: true)
    }

    /// Free-typed input from the chat box.
    func send(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, step != .done else { return }
        echo(text)
        handle(answer: text, wasOption: false)
    }

    /// Confirmation card's Add button: the ONLY path that saves.
    func confirmAdd() -> Habit? {
        guard step == .confirm, !draft.title.isEmpty else { return nil }
        let habit = draft.makeHabit()
        say("Added — “\(habit.title)” is now on your Today list. Every check-in is a vote for: \(draft.identityStatement)")
        options = []
        step = .done
        return habit
    }

    func cancel() {
        say("Cancelled — nothing was added. Tap + any time to start again.")
        options = []
        step = .done
    }

    // MARK: - Flow

    private func handle(answer: String, wasOption: Bool) {
        // Global escape hatches, valid at any step.
        let lower = answer.lowercased()
        if lower == "cancel" || lower == "start over" || lower == "cancel and start over" {
            if offTopicStrikes >= 1 || lower != "cancel" { resetOrCancel(lower) ; return }
            cancel()
            return
        }
        if lower == "continue this habit" || lower == "continue" {
            offTopicStrikes = 0
            say(currentQuestion())
            options = currentOptions()
            return
        }

        if step == .welcome {
            handleWelcome(answer: answer)
            return
        }

        // Guardrail: off-topic input never advances the flow and is
        // never answered.
        if !wasOption && isOffTopic(answer) {
            registerOffTopic()
            return
        }

        offTopicStrikes = 0
        switch step {
        case .identity: handleIdentity(answer)
        case .goal: handleGoal(answer)
        case .anchor: handleAnchor(answer)
        case .replacement: handleReplacement(answer)
        case .shrink: handleShrink(answer)
        case .confirm:
            say("That's the full suggestion above — tap Add this habit, Edit details, or Start over.")
            options = []
        case .welcome, .done:
            break
        }
    }

    private func resetOrCancel(_ lower: String) {
        if lower.contains("start over") {
            reset()
            say("Started over. Who do you want to be?")
        } else {
            cancel()
        }
    }

    private func handleWelcome(answer: String) {
        switch answer {
        case "Add a new habit":
            turnsWithoutProgress = 0
            beginIdentity()
        case "Check in today":
            say("Taking you to Today — cast your votes there.")
            options = []
            step = .done
            welcomeAction = .checkInToday
        case "Review my habits":
            say("Taking you to Review.")
            options = []
            step = .done
            welcomeAction = .reviewHabits
        default:
            // Typed input at the welcome step: treat a habit-shaped
            // answer as the start of a build, anything else re-offers.
            if isOffTopic(answer) {
                registerOffTopic()
            } else {
                beginIdentity()
                handleIdentity(answer)
            }
        }
    }

    private func handleIdentity(_ answer: String) {
        let cleaned = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if isVague(cleaned) && clarifyingAsked < 2 {
            clarifyingAsked += 1
            turnsWithoutProgress += 1
            if turnsWithoutProgress >= 10 { expire(); return }
            say("Tell me a little more — in what area of life? Work, health, calm, learning…")
            options = ["At work", "My health", "Calm and focus"]
            return
        }
        draft.identityStatement = Self.identitySentence(from: cleaned)
        candidateActions = engine.candidateActions(forIdentity: cleaned)
        step = .goal
        say("Good — we'll build it from this:\n\nIdentity: “\(draft.identityStatement)”\n\nWhich one small action should we turn into your daily habit?")
        options = candidateActions
    }

    private func handleGoal(_ answer: String) {
        let cleaned = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.title = Self.capitalisedTitle(cleaned)
        draft.kind = Self.detectKind(goal: cleaned, identity: draft.identityStatement)
        step = .anchor
        say("Perfect.\n\nHabit so far: \(draft.title)\nIdentity: “\(draft.identityStatement)”\n\nNow the cue — when exactly will you do it? A specific moment makes it much easier to keep:")
        options = engine.candidateAnchors(for: draft)
    }

    private func handleAnchor(_ answer: String) {
        let cleaned = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.anchor = Self.anchorPhrase(from: cleaned)
        if let time = Self.extractTime(from: cleaned) { draft.cueTime = time }
        if let place = Self.extractPlace(from: cleaned) { draft.cuePlace = place }

        if draft.kind == .quit {
            draft.costList = engine.costList(for: draft)
            step = .replacement
            say("Here's what this one costs you:\n\n\(draft.costList)\n\nWhen the urge hits, what will you do instead?")
            options = engine.candidateReplacements(for: draft)
        } else {
            advanceToShrink()
        }
    }

    private func handleReplacement(_ answer: String) {
        draft.replacementHabit = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        advanceToShrink()
    }

    private func advanceToShrink() {
        step = .shrink
        let proposed = engine.twoMinuteVersion(for: draft)
        draft.twoMinuteVersion = proposed
        if let prep = engine.prepItem(for: draft) {
            draft.prepItems = [prep]
        }
        say("Last piece before I show you the full suggestion — your easy fallback for a tough day. The smallest version that still counts as a vote:\n\n“\(proposed)”")
        options = ["That works", "Make it even smaller"]
    }

    private func handleShrink(_ answer: String) {
        if answer == "Make it even smaller" {
            draft.twoMinuteVersion = "Do just the first tiny step of “\(draft.title)” — 30 seconds counts."
            say("Even smaller: “\(draft.twoMinuteVersion)”\n\nHere's the full suggestion to confirm:")
        } else if answer != "That works" {
            draft.twoMinuteVersion = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            say("Got it — that's your fallback version. Here's the full suggestion to confirm:")
        } else {
            say("Here's the full suggestion to confirm:")
        }
        step = .confirm
        options = []
    }

    // MARK: - Guardrails

    /// Deterministic topic check: known off-topic subjects, requests for
    /// general advice, and attempts to start a second habit mid-flow.
    private func isOffTopic(_ text: String) -> Bool {
        let lower = text.lowercased()
        let offTopicSignals = [
            "weather", "news", "joke", "stock price", "bitcoin", "crypto",
            "president", "election", "movie", "song lyrics", "recipe",
            "translate", "capital of", "lottery", "football", "baseball",
            "what time is it in", "tell me a story", "write a poem",
            "write an email", "medical advice", "diagnose", "investment advice",
        ]
        if offTopicSignals.contains(where: { lower.contains($0) }) { return true }
        // A second habit mid-flow is parked, not started.
        if step != .identity && step != .goal
            && (lower.contains("also add") || lower.contains("another habit")) {
            return true
        }
        return false
    }

    private func registerOffTopic() {
        offTopicStrikes += 1
        turnsWithoutProgress += 1
        if turnsWithoutProgress >= 10 { expire(); return }
        if offTopicStrikes >= 2 {
            say("Let's stick to this habit. Continue this habit, or Cancel and start over?")
            options = ["Continue this habit", "Cancel and start over"]
        } else {
            say("Let's stick to this habit — we were picking \(stepName). \(currentQuestion())")
            options = currentOptions()
        }
    }

    private func expire() {
        say("We've gone a few rounds without landing this one — session ended, nothing was added. Tap + any time to start again.")
        options = []
        step = .done
    }

    private var stepName: String {
        switch step {
        case .welcome: return "what to do next"
        case .identity: return "who you want to be"
        case .goal: return "the small action"
        case .anchor: return "when it happens"
        case .replacement: return "what replaces it"
        case .shrink: return "the 2-minute version"
        case .confirm: return "whether to add it"
        case .done: return "this habit"
        }
    }

    private func currentQuestion() -> String {
        switch step {
        case .welcome: return "What shall we do?"
        case .identity: return "Who do you want to be?"
        case .goal: return "Which one small action should we turn into your daily habit?"
        case .anchor: return "When exactly will you do it?"
        case .replacement: return "When the urge hits, what will you do instead?"
        case .shrink: return "What's the smallest version that still counts as a vote?"
        case .confirm: return "Add this habit, Edit details, or Start over?"
        case .done: return ""
        }
    }

    private func currentOptions() -> [String] {
        switch step {
        case .welcome: return ["Add a new habit", "Check in today", "Review my habits"]
        case .identity: return ["An assertive person", "Calm and focused", "A fit, healthy person"]
        case .goal: return candidateActions
        case .anchor: return engine.candidateAnchors(for: draft)
        case .replacement: return engine.candidateReplacements(for: draft)
        case .shrink: return ["That works", "Make it even smaller"]
        case .confirm, .done: return []
        }
    }

    private func isVague(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return lower.isEmpty || ["idk", "i don't know", "dont know", "something", "anything", "not sure", "better", "a better person"].contains(lower)
    }

    // MARK: - Text helpers

    private func say(_ text: String) {
        messages.append(CoachMessage(role: .coach, text: text))
    }

    private func echo(_ text: String) {
        messages.append(CoachMessage(role: .user, text: text))
    }

    /// "an assertive person" / "I want to be an assertive person" →
    /// "I am an assertive person."
    static func identitySentence(from raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        for prefix in ["i want to be ", "i wanna be ", "to be ", "be "] where lower.hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count))
            break
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("i am ") {
            return text.hasSuffix(".") ? text : text + "."
        }
        let article: String
        if ["a ", "an ", "the "].contains(where: { text.lowercased().hasPrefix($0) }) {
            article = ""
        } else if let first = text.lowercased().first, "aeiou".contains(first) {
            article = "an "
        } else {
            article = "a "
        }
        let sentence = "I am \(article)\(text)"
        return sentence.hasSuffix(".") ? sentence : sentence + "."
    }

    static func capitalisedTitle(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// Build vs quit detection: explicit quit signals, or a negated goal
    /// ("no phone in bed", "stop smoking").
    static func detectKind(goal: String, identity: String) -> HabitKind {
        let lower = goal.lowercased()
        let quitSignals = ["quit", "stop", "give up", "avoid", "no phone", "no alcohol",
                           "no sugar", "no smoking", "less phone", "cut down", "not "]
        if quitSignals.contains(where: { lower.contains($0) }) { return .quit }
        if lower.hasPrefix("no ") { return .quit }
        return .build
    }

    /// "In standup" → "standup"; "After lunch" → "lunch"; free text kept
    /// as the anchor phrase, lower-cased at the front for the stack.
    static func anchorPhrase(from raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        for prefix in ["after i ", "after ", "in ", "during ", "when i "] where lower.hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count))
            break
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = text.first else { return text }
        return first.lowercased() + text.dropFirst()
    }

    /// First "HH:mm"-shaped time in the answer, if any.
    static func extractTime(from raw: String) -> String? {
        let parts = raw.split { !$0.isNumber && $0 != ":" }
        for part in parts {
            let pair = part.split(separator: ":")
            if pair.count == 2, pair[0].count <= 2, pair[1].count == 2,
               Int(pair[0]) != nil, Int(pair[1]) != nil {
                return String(part)
            }
        }
        return nil
    }

    /// A recognisable place word in the answer, if any.
    static func extractPlace(from raw: String) -> String? {
        let lower = raw.lowercased()
        for place in ["bedroom", "kitchen", "gym", "office", "living room", "desk", "home"] {
            if lower.contains(place) { return place }
        }
        return nil
    }
}
