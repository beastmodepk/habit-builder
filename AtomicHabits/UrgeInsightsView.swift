import SwiftUI

/// Urge pattern insights (Quit — attack the cue): simple, honest statistics
/// over a quit habit's urge log. No invented data: with no logs it says so.
struct UrgeInsightsView: View {
    let habit: Habit

    private var logs: [UrgeLogEntry] { habit.urgeLogs }

    private var thisWeekCount: Int {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return logs.filter { $0.date >= start }.count
    }

    private var topHourText: String {
        guard !logs.isEmpty else { return "—" }
        var counts: [Int: Int] = [:]
        for log in logs {
            counts[Calendar.current.component(.hour, from: log.date), default: 0] += 1
        }
        guard let (hour, _) = counts.max(by: { $0.value < $1.value }) else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "h a"
        var comps = DateComponents()
        comps.hour = hour
        let d = Calendar.current.date(from: comps) ?? Date()
        return "around \(f.string(from: d))"
    }

    private var topCueText: String {
        var counts: [String: Int] = [:]
        for log in logs {
            let cue = log.cue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cue.isEmpty { counts[cue, default: 0] += 1 }
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? "not recorded yet"
    }

    private var averageDropText: String {
        let pairs = logs.filter { $0.intensityBefore > 0 && $0.intensityAfter > 0 }
        guard !pairs.isEmpty else { return "log intensity in SOS to see cravings peak and pass" }
        let avg = Double(pairs.reduce(0) { $0 + ($1.intensityBefore - $1.intensityAfter) }) / Double(pairs.count)
        return String(format: "intensity falls by %.1f points on average after riding it out", avg)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if logs.isEmpty {
                Text("No urges logged yet — patterns will appear here once you log a few in SOS or the urge log.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                insightRow(icon: "clock.fill", text: "Urges strike most \(topHourText)")
                insightRow(icon: "scope", text: "Top cue: \(topCueText)")
                insightRow(icon: "calendar", text: "\(thisWeekCount) urge(s) logged this week · \(logs.count) all-time")
                insightRow(icon: "waveform.path.ecg", text: averageDropText)
                Text("Attack the cue, not your willpower: change the time, place, or what comes right before it.")
                    .font(.footnote)
                    .foregroundStyle(AHColor.champagne)
            }
        }
    }

    private func insightRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AHColor.quit)
            Text(text)
                .font(.subheadline)
        }
    }
}
