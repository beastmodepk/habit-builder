import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: HabitStore
    @State private var showingAddBuild = false
    @State private var showingAddQuit = false

    var buildHabits: [Habit] { store.habits.filter { $0.kind == .build } }
    var quitHabits: [Habit] { store.habits.filter { $0.kind == .quit } }

    var votesToday: Int {
        store.habits.filter { $0.isChecked(on: DayHelper.todayString()) }.count
    }

    var todayPercent: Int {
        guard !store.habits.isEmpty else { return 0 }
        return Int((Double(votesToday) / Double(store.habits.count)) * 100)
    }

    var weekPercent: Int {
        guard !store.habits.isEmpty else { return 0 }
        let days = (0..<7).map { DayHelper.string(daysAgo: $0) }
        let possible = store.habits.count * days.count
        let cast = store.habits.reduce(0) { sum, habit in
            sum + days.filter { habit.isChecked(on: $0) }.count
        }
        guard possible > 0 else { return 0 }
        return Int((Double(cast) / Double(possible)) * 100)
    }

    var allTimeVotes: Int {
        store.habits.reduce(0) { $0 + $1.checkinDates.count }
    }

    /// Habits with a cue time, in firing order — the day's stack chain.
    var stackedHabits: [Habit] {
        store.habits
            .filter { !$0.cueTime.isEmpty }
            .sorted { $0.cueTime < $1.cueTime }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    heroCard
                    nextCueCard
                    stackChainCard
                    habitSection(title: "Build", kind: .build, habits: buildHabits) {
                        showingAddBuild = true
                    }
                    habitSection(title: "Quit", kind: .quit, habits: quitHabits) {
                        showingAddQuit = true
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(AHColor.background.ignoresSafeArea())
            .navigationTitle("Today")
            .sheet(isPresented: $showingAddBuild) { AddHabitView(kind: .build) }
            .sheet(isPresented: $showingAddQuit) { AddHabitView(kind: .quit) }
        }
    }

    // MARK: - Hero (Fitness-style ring)

    private var heroCard: some View {
        HStack(spacing: 20) {
            ActivityRingView(
                progress: store.habits.isEmpty ? 0 : Double(votesToday) / Double(store.habits.count),
                color: AHColor.build,
                title: "\(votesToday)/\(store.habits.count)",
                subtitle: "votes today"
            )
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Votes")
                    .font(.title3).bold()
                    .foregroundStyle(AHColor.graphite)
                Text("Today \(todayPercent)%  ·  Week \(weekPercent)%")
                    .font(.subheadline)
                    .foregroundStyle(AHColor.graphiteSecondary)
                Text("\(allTimeVotes) all-time votes")
                    .font(.subheadline)
                    .foregroundStyle(AHColor.graphiteSecondary)
                Text("Every check-in is a vote for the person you want to become.")
                    .font(.footnote)
                    .foregroundStyle(AHColor.champagne)
            }
            Spacer(minLength: 0)
        }
        .ahCard()
    }

    // MARK: - Next cue

    private var nextCue: Habit? {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        let now = f.string(from: Date())
        let upcoming = stackedHabits.filter { $0.cueTime >= now && !$0.isChecked(on: DayHelper.todayString()) }
        return upcoming.first ?? stackedHabits.first
    }

    @ViewBuilder
    private var nextCueCard: some View {
        if let cue = nextCue {
            HStack(spacing: 14) {
                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.title3)
                    .foregroundStyle(AHColor.champagne)
                VStack(alignment: .leading, spacing: 3) {
                    Text("NEXT CUE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(AHColor.graphiteSecondary)
                    Text("\(cue.cueTime) · \(cue.title)")
                        .font(AHFont.cardTitle)
                        .foregroundStyle(AHColor.graphite)
                    Text([cue.anchor.isEmpty ? nil : "after I \(cue.anchor)",
                          cue.cuePlace.isEmpty ? nil : "at \(cue.cuePlace)"]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(AHColor.graphiteSecondary)
                }
                Spacer(minLength: 0)
            }
            .ahCard(padding: 16)
        }
    }

    // MARK: - Stack chain (the day as linked habit stacks)

    @ViewBuilder
    private var stackChainCard: some View {
        if !stackedHabits.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                AHSectionHeader(title: "Today's Stack", systemImage: "link")
                ForEach(Array(stackedHabits.enumerated()), id: \.element.id) { index, habit in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(habit.isChecked(on: DayHelper.todayString())
                                      ? AHColor.accent(for: habit.kind) : AHColor.hairline)
                                .frame(width: 10, height: 10)
                            if index < stackedHabits.count - 1 {
                                Rectangle()
                                    .fill(AHColor.hairline)
                                    .frame(width: 1.5, height: 26)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(habit.cueTime)  ·  \(habit.title)")
                                .font(AHFont.cardTitle)
                                .foregroundStyle(AHColor.graphite)
                            if !habit.anchor.isEmpty {
                                Text("after I \(habit.anchor)")
                                    .font(.footnote)
                                    .foregroundStyle(AHColor.graphiteSecondary)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .ahCard()
        }
    }

    // MARK: - Habit sections

    private func habitSection(title: String, kind: HabitKind, habits: [Habit],
                              onAdd: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AHSectionHeader(title: title,
                                systemImage: kind == .build ? "leaf.fill" : "shield.fill",
                                color: AHColor.accent(for: kind))
                Spacer()
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AHColor.accent(for: kind))
                }
                .accessibilityLabel("Add a \(title.lowercased()) habit")
            }
            ForEach(habits) { habit in
                HabitCardView(habit: habit)
            }
        }
    }
}

/// One habit as a large luxury card: check control, title, streak pill,
/// chain strip, and a navigation affordance into the detail screen.
struct HabitCardView: View {
    @EnvironmentObject var store: HabitStore
    let habit: Habit

    private var checkedToday: Bool { habit.isChecked(on: DayHelper.todayString()) }

    var body: some View {
        HStack(spacing: 14) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    store.toggleToday(id: habit.id)
                }
            } label: {
                Image(systemName: checkedToday ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30))
                    .foregroundStyle(checkedToday ? AHColor.accent(for: habit.kind) : AHColor.graphiteSecondary.opacity(0.5))
                    .symbolEffect(.bounce, value: checkedToday)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(checkedToday ? "Checked today" : "Check in today")

            NavigationLink {
                HabitDetailView(habitID: habit.id)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(habit.title)
                            .font(AHFont.cardTitle)
                            .foregroundStyle(AHColor.graphite)
                        if habit.isShrunkToday {
                            Text("SHRUNK")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AHColor.champagne)
                        }
                    }
                    HStack(spacing: 8) {
                        StreakPill(streak: DayHelper.streak(for: habit),
                                   label: habit.kind == .build ? "day streak" : "clean days")
                        if !habit.cueTime.isEmpty {
                            Text(habit.cueTime)
                                .font(AHFont.caption)
                                .foregroundStyle(AHColor.graphiteSecondary)
                        }
                    }
                    ChainStripView(habit: habit)
                }
                Spacer(minLength: 0)
            }
            .buttonStyle(.plain)
        }
        .ahCard(padding: 16)
    }
}

struct AddHabitView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss
    let kind: HabitKind

    @State private var title = ""
    @State private var identityStatement = ""
    @State private var habitStack = ""
    @State private var twoMinuteVersion = ""
    @State private var costList = ""
    @State private var replacementHabit = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Title", text: $title)
                }
                if kind == .build {
                    Section("Design") {
                        TextField("I am a person who...", text: $identityStatement)
                        TextField("After I..., I will... at...", text: $habitStack)
                        TextField("2-minute version", text: $twoMinuteVersion)
                    }
                } else {
                    Section("Design") {
                        TextField("I am a person who...", text: $identityStatement)
                        TextField("Real cost list (one per line)", text: $costList, axis: .vertical)
                        TextField("Replacement habit", text: $replacementHabit)
                    }
                }
            }
            .navigationTitle(kind == .build ? "New Build Habit" : "New Quit Habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        var habit = Habit(kind: kind, title: title.trimmingCharacters(in: .whitespacesAndNewlines))
                        habit.identityStatement = identityStatement
                        habit.habitStack = habitStack
                        habit.twoMinuteVersion = twoMinuteVersion
                        habit.costList = costList
                        habit.replacementHabit = replacementHabit
                        store.add(habit)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
