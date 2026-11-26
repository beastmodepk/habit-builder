import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var router: AppRouter
    @State private var showingAddBuild = false
    @State private var showingAddQuit = false
    /// Selected tab: 0 = Coach (the app opens here), 1 = Today,
    /// 2 = Prep, 3 = Review.
    @State private var selectedTab = 0
    /// nil until first appearance decides from the store; then pinned for
    /// the session so enrollment isn't dismissed mid-flow when the
    /// commitment step flips `hasOnboarded`.
    @State private var onboardingActive: Bool? = nil
    /// Today tab day switcher: 0 = today, 1 = yesterday — so a forgotten
    /// check-in can still be logged the next morning (Parthey's request,
    /// 2026-11-25). All check-ins on the Today tab apply to this day.
    @State private var selectedDayOffset = 0

    var buildHabits: [Habit] { store.habits.filter { $0.kind == .build } }
    var quitHabits: [Habit] { store.habits.filter { $0.kind == .quit } }

    var selectedDayString: String { DayHelper.string(daysAgo: selectedDayOffset) }
    var isViewingToday: Bool { selectedDayOffset == 0 }
    var selectedDayName: String { isViewingToday ? "today" : "yesterday" }

    var selectedDateText: String {
        guard let date = DayHelper.date(fromDayString: selectedDayString) else { return selectedDayString }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    var votesToday: Int {
        store.habits.filter { $0.isChecked(on: DayHelper.todayString()) }.count
    }

    var votesSelected: Int {
        store.habits.filter { $0.isChecked(on: selectedDayString) }.count
    }

    var todayPercent: Int {
        guard !store.habits.isEmpty else { return 0 }
        return Int((Double(votesSelected) / Double(store.habits.count)) * 100)
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
        Group {
            if onboardingActive ?? store.shouldPresentOnboarding {
                OnboardingView { onboardingActive = false }
            } else {
                mainTabs
            }
        }
        .onAppear {
            if onboardingActive == nil {
                onboardingActive = store.shouldPresentOnboarding
            }
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            // The app opens directly on the Habit Coach chat screen
            // (Parthey's order, 2026-11-25). The coach's welcome step can
            // hand off to Today (check in) or Review.
            HabitChatView(onWelcomeAction: { action in
                selectedTab = action == .checkInToday ? 1 : 3
            })
                .tabItem { Label("Coach", systemImage: "message.fill") }
                .tag(0)
            todayBody
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(1)
            NavigationStack { PrepView() }
                .tabItem { Label("Prep", systemImage: "moon.stars.fill") }
                .tag(2)
            NavigationStack { WeeklyReviewView() }
                .tabItem { Label("Review", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(3)
        }
    }

    private var todayBody: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    daySwitcher
                    heroCard
                    IdentityBoardView()
                    if isViewingToday {
                        rescueCard
                        nextCueCard
                    }
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.showSOS = true
                    } label: {
                        Label("Urge SOS", systemImage: "lifepreserver.fill")
                            .foregroundStyle(AHColor.quit)
                    }
                }
            }
            .sheet(isPresented: $showingAddBuild) { HabitChatView(forceNewHabit: true) }
            .sheet(isPresented: $showingAddQuit) { HabitChatView(forceNewHabit: true) }
            .sheet(isPresented: $router.showSOS) { SOSView() }
            .sheet(isPresented: $router.showTimer) {
                NavigationStack { UrgeTimerView() }
            }
        }
    }

    // MARK: - Day switcher (Today / Yesterday)

    private var daySwitcher: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Day", selection: $selectedDayOffset) {
                Text("Today").tag(0)
                Text("Yesterday").tag(1)
            }
            .pickerStyle(.segmented)
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.footnote)
                    .foregroundStyle(AHColor.champagne)
                Text(selectedDateText)
                    .font(.subheadline).bold()
                    .foregroundStyle(AHColor.graphite)
                if !isViewingToday {
                    Text("— logging for yesterday")
                        .font(.footnote)
                        .foregroundStyle(AHColor.graphiteSecondary)
                }
            }
        }
    }

    // MARK: - Hero (Fitness-style ring)

    private var heroCard: some View {
        HStack(spacing: 20) {
            ActivityRingView(
                progress: store.habits.isEmpty ? 0 : Double(votesSelected) / Double(store.habits.count),
                color: AHColor.build,
                title: "\(votesSelected)/\(store.habits.count)",
                subtitle: "votes \(selectedDayName)"
            )
            VStack(alignment: .leading, spacing: 8) {
                Text(isViewingToday ? "Today's Votes" : "Yesterday's Votes")
                    .font(.title3).bold()
                    .foregroundStyle(AHColor.graphite)
                Text("\(isViewingToday ? "Today" : "Yesterday") \(todayPercent)%  ·  Week \(weekPercent)%")
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

    // MARK: - Rescue mode (never miss twice)

    private var rescueHabits: [Habit] {
        store.habits.filter { DayHelper.rescueAvailable(for: $0) }
    }

    @ViewBuilder
    private var rescueCard: some View {
        if !rescueHabits.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                AHSectionHeader(title: "Rescue Mode — never miss twice", systemImage: "lifepreserver.fill",
                                color: AHColor.quit)
                ForEach(rescueHabits) { habit in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(habit.title)
                            .font(AHFont.cardTitle)
                            .foregroundStyle(AHColor.graphite)
                        Text("Yesterday slipped. One small vote today bridges the gap and protects the \(DayHelper.streak(for: habit))-day streak.")
                            .font(.footnote)
                            .foregroundStyle(AHColor.graphiteSecondary)
                        if !habit.twoMinuteVersion.isEmpty {
                            Text("Tiny version: \(habit.twoMinuteVersion)")
                                .font(.footnote).bold()
                                .foregroundStyle(AHColor.champagne)
                        }
                        HStack(spacing: 10) {
                            Button("Rescue with 2-minute vote") {
                                store.logTwoMinuteToday(id: habit.id)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AHColor.quit)
                            Button("Full vote") { store.toggleToday(id: habit.id) }
                                .buttonStyle(.bordered)
                        }
                    }
                    if habit.id != rescueHabits.last?.id {
                        Divider().overlay(AHColor.hairline)
                    }
                }
            }
            .ahCard()
        }
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
                AHSectionHeader(title: isViewingToday ? "Today's Stack" : "Yesterday's Stack", systemImage: "link")
                ForEach(Array(stackedHabits.enumerated()), id: \.element.id) { index, habit in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(habit.isChecked(on: selectedDayString)
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
                HabitCardView(habit: habit, dayString: selectedDayString, dayName: selectedDayName)
            }
        }
    }
}

/// One habit as a large luxury card: check control, title, streak pill,
/// chain strip, and a navigation affordance into the detail screen.
struct HabitCardView: View {
    @EnvironmentObject var store: HabitStore
    let habit: Habit
    /// The day this card's check-in applies to ("yyyy-MM-dd") — today by
    /// default; the Today tab passes yesterday when its switcher is set.
    var dayString: String = DayHelper.todayString()
    /// "today" / "yesterday", for labels.
    var dayName: String = "today"
    @State private var celebrated = false

    private var checkedToday: Bool { habit.isChecked(on: dayString) }

    var body: some View {
        HStack(spacing: 14) {
            Button {
                let wasChecked = checkedToday
                store.toggleCheckin(id: habit.id, on: dayString)
                if !wasChecked {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                        celebrated = true
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_400_000_000)
                        withAnimation { celebrated = false }
                    }
                }
            } label: {
                Image(systemName: checkedToday ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30))
                    .foregroundStyle(checkedToday ? AHColor.accent(for: habit.kind) : AHColor.graphiteSecondary.opacity(0.5))
                    .symbolEffect(.bounce, value: checkedToday)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(checkedToday ? "Checked \(dayName)" : "Check in \(dayName)")

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
                    if !habit.temptationBundle.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "headphones")
                                .foregroundStyle(AHColor.champagne)
                            Text(habit.temptationBundle)
                                .lineLimit(1)
                        }
                        .font(.footnote)
                        .foregroundStyle(AHColor.graphiteSecondary)
                    }
                    ChainStripView(habit: habit)
                    if habit.kind == .quit && habit.dailyCost > 0 {
                        Text("Saved $\(Double(habit.checkinDates.count) * habit.dailyCost, specifier: "%.0f") so far")
                            .font(.footnote).bold()
                            .foregroundStyle(AHColor.champagne)
                    }
                }
                Spacer(minLength: 0)
                if !checkedToday && !habit.twoMinuteVersion.isEmpty {
                    Button {
                        withAnimation { store.logTwoMinute(id: habit.id, on: dayString) }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "timer")
                            Text("2-min")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(AHColor.champagne)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Too much today? Log the 2-minute version: \(habit.twoMinuteVersion)")
                }
            }
            .buttonStyle(.plain)
        }
        .ahCard(padding: 16)
        .overlay {
            if celebrated {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(AHColor.accent(for: habit.kind))
                    Text(habit.rewardText.isEmpty ? "Vote cast." : habit.rewardText)
                        .font(.subheadline).bold()
                        .foregroundStyle(AHColor.graphite)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
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
    @State private var temptationBundle = ""
    @State private var costList = ""
    @State private var replacementHabit = ""

    var body: some View {
        TabView {
            todayBody
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            NavigationStack { PrepView() }
                .tabItem { Label("Prep", systemImage: "moon.stars.fill") }
            NavigationStack { WeeklyReviewView() }
                .tabItem { Label("Review", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }

    private var todayBody: some View {
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
                        TextField("Temptation bundle (only while doing it, I get to...)", text: $temptationBundle)
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
                        habit.temptationBundle = temptationBundle
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

/// Compatibility wrapper used by the habit detail screen (chain strip).
struct Last14DaysView: View {
    let habit: Habit

    var body: some View {
        ChainStripView(habit: habit, days: 14, cell: 15)
    }
}
