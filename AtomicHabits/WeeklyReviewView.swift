import SwiftUI

/// Weekly Review (Reward — reflection + the 1% graph): this week vs last
/// week, an 8-week compounding view of cumulative votes, the plateau note,
/// and three reflection prompts saved per week.
struct WeeklyReviewView: View {
    @EnvironmentObject var store: HabitStore
    @State private var wins = ""
    @State private var lessons = ""
    @State private var focus = ""
    @State private var loaded = false

    private var thisWeekVotes: Int { DayHelper.votes(store.habits, lastDays: 7) }

    private var lastWeekVotes: Int {
        (7..<14).reduce(0) { sum, offset in
            sum + DayHelper.votes(store.habits, on: DayHelper.string(daysAgo: offset))
        }
    }

    /// Cumulative votes at the end of each of the last 8 weeks (oldest first).
    private var cumulativeByWeek: [Int] {
        var result: [Int] = []
        var running = 0
        for week in (0..<8).reversed() {
            let startOffset = week * 7 + 6
            running += (0..<7).reduce(0) { sum, d in
                sum + DayHelper.votes(store.habits, on: DayHelper.string(daysAgo: startOffset - d))
            }
            result.append(running)
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                comparisonCard
                compoundingCard
                plateauCard
                reflectionCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AHColor.background.ignoresSafeArea())
        .navigationTitle("Weekly Review")
        .onAppear(perform: loadReflection)
    }

    private var comparisonCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("THIS WEEK")
                    .font(AHFont.caption).foregroundStyle(AHColor.graphiteSecondary)
                Text("\(thisWeekVotes)")
                    .font(AHFont.heroNumber).foregroundStyle(AHColor.build)
                Text("wins")
                    .font(AHFont.caption).foregroundStyle(AHColor.graphiteSecondary)
            }
            Spacer()
            Image(systemName: thisWeekVotes >= lastWeekVotes ? "arrow.up.right" : "arrow.down.right")
                .font(.title2)
                .foregroundStyle(thisWeekVotes >= lastWeekVotes ? AHColor.build : AHColor.quit)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("LAST WEEK")
                    .font(AHFont.caption).foregroundStyle(AHColor.graphiteSecondary)
                Text("\(lastWeekVotes)")
                    .font(AHFont.heroNumber).foregroundStyle(AHColor.graphite)
                Text("wins")
                    .font(AHFont.caption).foregroundStyle(AHColor.graphiteSecondary)
            }
        }
        .ahCard()
    }

    private var compoundingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            AHSectionHeader(title: "Compounding wins — 8 weeks", systemImage: "chart.line.uptrend.xyaxis",
                            color: AHColor.champagne)
            let maxValue = max(cumulativeByWeek.max() ?? 1, 1)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(cumulativeByWeek.enumerated()), id: \.offset) { _, value in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(AHColor.champagne.opacity(0.85))
                            .frame(height: max(6, 110 * Double(value) / Double(maxValue)))
                        Text("\(value)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AHColor.graphiteSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text("Getting 1% better every day compounds quietly. The bars are your cumulative wins — proof, stacking up even when no single day looks dramatic.")
                .font(.footnote)
                .foregroundStyle(AHColor.graphiteSecondary)
        }
        .ahCard()
    }

    private var plateauCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            AHSectionHeader(title: "The plateau", systemImage: "mountain.2.fill", color: AHColor.quit)
            Text("Results lag effort. Clear calls this the Plateau of Latent Potential — the flat stretch where most people quit, right before the breakthrough. A flat week in the graph above is not failure; it is stored work.")
                .font(.subheadline)
                .foregroundStyle(AHColor.graphite)
        }
        .ahCard()
    }

    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            AHSectionHeader(title: "Reflect — week of \(DayHelper.weekStartString())", systemImage: "pencil.line")
            promptField("What wins am I proudest of?", text: $wins)
            promptField("Where did the system break down?", text: $lessons)
            promptField("One tweak for next week:", text: $focus)
            Button("Save reflection") {
                store.saveReflection(WeeklyReflection(
                    weekStart: DayHelper.weekStartString(),
                    wins: wins, lessons: lessons, focus: focus, createdAt: Date()))
            }
            .buttonStyle(.borderedProminent)
            .tint(AHColor.build)
        }
        .ahCard()
    }

    private func promptField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline).bold()
                .foregroundStyle(AHColor.graphite)
            TextField(label, text: text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func loadReflection() {
        guard !loaded else { return }
        loaded = true
        if let saved = store.weeklyReflections.first(where: { $0.weekStart == DayHelper.weekStartString() }) {
            wins = saved.wins
            lessons = saved.lessons
            focus = saved.focus
        }
    }
}
