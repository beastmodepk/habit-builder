import Foundation

/// Shared on-disk store location. The app and the widget extension read and
/// write the SAME habits.json inside the App Group container
/// (`group.com.parthey.atomichabits`) so widgets can show live data and the
/// interactive widget can toggle check-ins without opening the app.
///
/// Signing caveat: App Groups need the group entitlement on BOTH targets.
/// Under free (Personal Team) signing the group may not be provisioned; in
/// that case `sharedFileURL()` returns nil, the app silently falls back to
/// its private Application Support file (exactly the v0.1.0 behaviour), and
/// widgets show whatever the shared file holds — possibly nothing. Nothing
/// crashes either way.
enum SharedStore {
    static let appGroupID = "group.com.parthey.atomichabits"
    static let fileName = "habits.json"

    static func sharedFileURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static func loadData(from url: URL?) -> AppData? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppData.self, from: data)
    }

    static func saveData(_ appData: AppData, to url: URL?) {
        guard let url, let data = try? JSONEncoder().encode(appData) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    /// Toggle today's check-in for a habit directly in the shared file.
    /// Used by the interactive widget's AppIntent — no app process involved.
    static func toggleTodayInSharedFile(habitID: UUID) {
        guard let url = sharedFileURL() else { return }
        var data = loadData(from: url) ?? AppData()
        guard let idx = data.habits.firstIndex(where: { $0.id == habitID }) else { return }
        let today = DayHelper.todayString()
        if data.habits[idx].checkinDates.contains(today) {
            data.habits[idx].checkinDates.removeAll { $0 == today }
            data.habits[idx].checkinKinds[today] = nil
        } else {
            data.habits[idx].checkinDates.append(today)
            data.habits[idx].checkinDates.sort()
            data.habits[idx].checkinKinds[today] = CheckinKind.full.rawValue
        }
        saveData(data, to: url)
    }
}
