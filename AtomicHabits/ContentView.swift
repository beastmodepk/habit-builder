import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: HabitStore
    @State private var showingAddBuild = false
    @State private var showingAddQuit = false

    private var buildHabits: [Habit] { store.habits.filter { $0.kind == .build } }
    private var quitHabits: [Habit] { store.habits.filter { $0.kind == .quit } }

    private var votesToday: Int {
        store.habits.filter { $0.isChecked(on: DayHelper.todayString()) }.count
    }

    private var todayPercent: Int {
        guard !store.habits.isEmpty else { return 0 }
        return Int((Double(votesToday) / Double(store.habits.count)) * 100)
    }

    private var weekPercent: Int {
        guard !store.habits.isEmpty else { return 0 }
        let days = (0..<7).map { DayHelper.string(daysAgo: $0) }
        let possible = store.habits.count * days.count
        let cast = store.habits.reduce(0) { sum, habit in
            sum + days.filter { habit.isChecked(on: $0) }.count
        }
        guard possible > 0 else { return 0 }
        return Int((Double(cast) / Double(possible)) * 100)
    }

    private var allTimeVotes: Int {
        store.habits.reduce(0) { $0 + $1.checkinDates.count }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today's Votes")
                            .font(.headline)
                        Text("\(votesToday) of \(store.habits.count) votes cast today")
                            .font(.title3)
                            .bold()
                        Text("Today: \(todayPercent)%  •  This week: \(weekPercent)%  •  All-time votes: \(allTimeVotes)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Every check-in is a vote for the person you want to become.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Build") {
                    ForEach(buildHabits) { habit in
                        HabitRowView(habit: habit)
                    }
                    Button("Add a build habit") { showingAddBuild = true }
                }

                Section("Quit") {
                    ForEach(quitHabits) { habit in
                        HabitRowView(habit: habit)
                    }
                    Button("Add a quit habit") { showingAddQuit = true }
                }
            }
            .navigationTitle("Atomic Habits")
            .sheet(isPresented: $showingAddBuild) {
                AddHabitView(kind: .build)
            }
            .sheet(isPresented: $showingAddQuit) {
                AddHabitView(kind: .quit)
            }
        }
    }
}

struct HabitRowView: View {
    @EnvironmentObject var store: HabitStore
    let habit: Habit

    private var checkedToday: Bool { habit.isChecked(on: DayHelper.todayString()) }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                store.toggleToday(id: habit.id)
            } label: {
                Image(systemName: checkedToday ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(checkedToday ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(checkedToday ? "Checked today" : "Check in today")

            NavigationLink {
                HabitDetailView(habitID: habit.id)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .foregroundStyle(.primary)
                    Text(habit.kind == .build
                         ? "Streak: \(DayHelper.streak(for: habit)) day(s)"
                         : "Clean streak: \(DayHelper.streak(for: habit)) day(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Last14DaysView(habit: habit)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct Last14DaysView: View {
    let habit: Habit

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array((0..<14).reversed()), id: \.self) { offset in
                let day = DayHelper.string(daysAgo: offset)
                RoundedRectangle(cornerRadius: 2)
                    .fill(habit.isChecked(on: day) ? Color.green : Color.gray.opacity(0.25))
                    .frame(width: 12, height: 12)
            }
        }
        .accessibilityLabel("Last 14 days")
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
