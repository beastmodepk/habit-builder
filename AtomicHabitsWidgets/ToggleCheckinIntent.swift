import AppIntents
import WidgetKit

/// Interactive widget action (iOS 17 AppIntents): toggles today's check-in
/// for a habit by writing straight through the shared App Group store —
/// the app does not need to be opened. If the App Group is not provisioned
/// (free signing), the shared file is absent and this no-ops gracefully;
/// the widget then simply reloads its timelines.
struct ToggleCheckinIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Habit Check-in"
    static var description = IntentDescription("Check a habit in — or undo it — for today.")

    @Parameter(title: "Habit ID")
    var habitID: String

    init() {}

    init(habitID: String) {
        self.habitID = habitID
    }

    func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: habitID) {
            SharedStore.toggleTodayInSharedFile(habitID: uuid)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
