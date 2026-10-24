import WidgetKit
import SwiftUI

// MARK: - Snapshot model (widget-local, computed from the shared store)

struct HabitSnapshot: Identifiable {
    var id: String          // habit UUID string (used by the interactive intent)
    var title: String
    var isQuit: Bool
    var checkedToday: Bool
    var streak: Int
    var last7: [Bool]       // oldest -> newest
}

struct HabitsEntry: TimelineEntry {
    var date: Date
    var votesToday: Int
    var totalHabits: Int
    var nextTitle: String
    var nextTime: String
    var bestCleanStreak: Int
    var snapshots: [HabitSnapshot]

    static let empty = HabitsEntry(date: Date(), votesToday: 0, totalHabits: 0,
                                   nextTitle: "Open the app to begin",
                                   nextTime: "", bestCleanStreak: 0, snapshots: [])

    var progress: Double {
        totalHabits == 0 ? 0 : Double(votesToday) / Double(totalHabits)
    }
}

enum HabitsProvider: TimelineProvider {
    private static func loadEntry() -> HabitsEntry {
        guard let data = SharedStore.loadData(from: SharedStore.sharedFileURL()) else {
            return .empty
        }
        let today = DayHelper.todayString()
        let snapshots = data.habits.map { habit in
            HabitSnapshot(
                id: habit.id.uuidString,
                title: habit.title,
                isQuit: habit.kind == .quit,
                checkedToday: habit.isChecked(on: today),
                streak: DayHelper.streak(for: habit),
                last7: (0..<7).reversed().map { habit.isChecked(on: DayHelper.string(daysAgo: $0)) }
            )
        }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        let now = f.string(from: Date())
        let next = data.habits
            .filter { !$0.cueTime.isEmpty && $0.cueTime >= now && !$0.isChecked(on: today) }
            .sorted { $0.cueTime < $1.cueTime }
            .first ?? data.habits.first { !$0.cueTime.isEmpty }
        return HabitsEntry(
            date: Date(),
            votesToday: data.habits.filter { $0.isChecked(on: today) }.count,
            totalHabits: data.habits.count,
            nextTitle: next?.title ?? "All cues done",
            nextTime: next?.cueTime ?? "",
            bestCleanStreak: data.habits.filter { $0.kind == .quit }.map { DayHelper.streak(for: $0) }.max() ?? 0,
            snapshots: snapshots
        )
    }

    static func entry() -> HabitsEntry { loadEntry() }

    func placeholder(in context: Context) -> HabitsEntry { .empty }

    func getSnapshot(in context: Context, completion: @escaping (HabitsEntry) -> Void) {
        completion(Self.loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitsEntry>) -> Void) {
        let entry = Self.loadEntry()
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

// MARK: - Shared widget styling (same design system language as the app)

enum WidgetStyle {
    static let green = Color(red: 0.055, green: 0.36, blue: 0.20)
    static let amber = Color(red: 0.66, green: 0.42, blue: 0.05)
    static let champagne = Color(red: 0.66, green: 0.53, blue: 0.28)
    static let graphiteSecondary = Color.secondary
}

struct MiniRing: View {
    var progress: Double
    var size: CGFloat = 74

    var body: some View {
        ZStack {
            Circle().stroke(WidgetStyle.green.opacity(0.15), lineWidth: 9)
            Circle()
                .trim(from: 0, to: max(0.02, min(progress, 1)))
                .stroke(WidgetStyle.green,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Small widget: Today's Votes ring + next habit

struct SmallWidgetView: View {
    var entry: HabitsEntry

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                MiniRing(progress: entry.progress)
                Text("\(entry.votesToday)/\(entry.totalHabits)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("TODAY'S VOTES")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(WidgetStyle.graphiteSecondary)
                Text(entry.nextTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                if !entry.nextTime.isEmpty {
                    Text(entry.nextTime)
                        .font(.system(size: 11))
                        .foregroundStyle(WidgetStyle.graphiteSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

struct SmallWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SmallWidget", provider: HabitsProvider()) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Votes")
        .description("Your votes ring and the next habit cue.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Bundle

@main
struct AtomicHabitsWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SmallWidget()
    }
}
