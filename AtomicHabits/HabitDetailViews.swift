import SwiftUI

struct HabitDetailView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss
    let habitID: UUID

    @State private var draft: Habit?
    @State private var showDeleteConfirm = false
    @State private var newCue = ""
    @State private var newCraving = ""
    @State private var newInstead = ""

    private let buildLawLabels = [
        "Make it obvious", "Make it attractive", "Make it easy", "Make it satisfying"
    ]
    private let quitLawLabels = [
        "Make it invisible", "Make it unattractive", "Make it hard", "Make it unsatisfying"
    ]

    var body: some View {
        Group {
            if let habit = draft {
                Form {
                    checkInSection(habit)
                    designSection(habit)
                    if habit.kind == .quit {
                        urgeSection(habit)
                    }
                    Section {
                        Button("Delete habit", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
            } else {
                Text("Habit not found")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(draft?.title ?? "Habit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveAndDismiss() }
            }
        }
        .onAppear {
            if draft == nil, var found = store.habit(id: habitID) {
                found.normalise()
                draft = found
            }
        }
        .onDisappear {
            // Persist edits even if the user simply navigates back.
            if let current = draft, store.habit(id: current.id) != nil {
                store.update(current)
            }
        }
        .confirmationDialog("Delete this habit? This cannot be undone.",
                            isPresented: $showDeleteConfirm) {
            Button("Delete habit", role: .destructive) {
                store.delete(id: habitID)
                draft = nil
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func checkInSection(_ habit: Habit) -> some View {
        let checked = habit.isChecked(on: DayHelper.todayString())
        Section(habit.kind == .build ? "Today" : "Today — stayed clean") {
            Toggle(habit.kind == .build ? "Done today" : "Stayed clean today",
                   isOn: Binding(
                    get: { checked },
                    set: { _ in toggleToday() }
                   ))
            Text(habit.kind == .build
                 ? "Streak: \(DayHelper.streak(for: habit)) day(s)"
                 : "Clean streak: \(DayHelper.streak(for: habit)) day(s)")
            Last14DaysView(habit: habit)
            if DayHelper.missedYesterday(for: habit) {
                Label("You missed yesterday — never miss twice. Do the smallest version today.",
                      systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func designSection(_ habit: Habit) -> some View {
        Section("Title") {
            TextField("Title", text: binding(\.title))
        }
        Section("Identity") {
            TextField("I am a person who...", text: binding(\.identityStatement), axis: .vertical)
        }
        if habit.kind == .build {
            Section("Habit stack") {
                TextField("After I..., I will... at...", text: binding(\.habitStack), axis: .vertical)
            }
            Section("2-minute version") {
                TextField("The tiny starter version", text: binding(\.twoMinuteVersion), axis: .vertical)
            }
        } else {
            Section("Real cost list") {
                TextField("One cost per line", text: binding(\.costList), axis: .vertical)
            }
            Section("Replacement habit") {
                TextField("Instead, I will...", text: binding(\.replacementHabit), axis: .vertical)
            }
        }
        cueSection(habit)
        Section(habit.kind == .build ? "Four Laws" : "Four Laws — inverted") {
            let labels = habit.kind == .build ? buildLawLabels : quitLawLabels
            ForEach(0..<4, id: \.self) { index in
                Toggle(labels[index], isOn: lawBinding(index))
            }
        }
    }

    @ViewBuilder
    private func urgeSection(_ habit: Habit) -> some View {
        Section("Urge tools") {
            NavigationLink("10-minute urge timer") {
                UrgeTimerView()
            }
        }
        Section("Log an urge") {
            TextField("Cue — what triggered it?", text: $newCue)
            TextField("Craving — what did you want?", text: $newCraving)
            TextField("What I did instead", text: $newInstead)
            Button("Add urge log entry") {
                guard var current = draft else { return }
                let entry = UrgeLogEntry(date: Date(),
                                         cue: newCue, craving: newCraving, instead: newInstead)
                current.urgeLogs.append(entry)
                current.urgeLogs.sort { $0.date > $1.date }
                draft = current
                newCue = ""; newCraving = ""; newInstead = ""
            }
        }
        if !habit.urgeLogs.isEmpty {
            Section("Urge log") {
                ForEach(habit.urgeLogs.sorted { $0.date > $1.date }) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.date, style: .date)
                            .font(.caption).bold()
                        Text(entry.date, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !entry.cue.isEmpty { Text("Cue: \(entry.cue)").font(.subheadline) }
                        if !entry.craving.isEmpty { Text("Craving: \(entry.craving)").font(.subheadline) }
                        if !entry.instead.isEmpty { Text("Instead: \(entry.instead)").font(.subheadline) }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func cueSection(_ habit: Habit) -> some View {
        Section("Cue — make it obvious") {
            TextField("After I... (anchor)", text: binding(\.anchor), axis: .vertical)
            TextField("Place", text: binding(\.cuePlace))
            DatePicker("Cue time", selection: cueDateBinding, displayedComponents: .hourAndMinute)
            Button {
                if let current = draft {
                    Task {
                        if await AnchorNotifications.requestAuthorization() {
                            AnchorNotifications.schedule(for: current)
                        }
                    }
                }
            } label: {
                Label("Set anchor reminder", systemImage: "bell.badge")
            }
            Button(role: .destructive) {
                if let current = draft { AnchorNotifications.cancel(for: current) }
            } label: {
                Label("Remove anchor reminder", systemImage: "bell.slash")
            }
        }
    }

    private var cueDateBinding: Binding<Date> {
        Binding(
            get: {
                let f = DateFormatter()
                f.dateFormat = "HH:mm"
                if let d = draft, let parsed = f.date(from: d.cueTime) {
                    let cal = Calendar.current
                    var comps = cal.dateComponents([.year, .month, .day], from: Date())
                    let t = cal.dateComponents([.hour, .minute], from: parsed)
                    comps.hour = t.hour; comps.minute = t.minute
                    return cal.date(from: comps) ?? Date()
                }
                return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let f = DateFormatter()
                f.dateFormat = "HH:mm"
                draft?.cueTime = f.string(from: newValue)
            }
        )
    }

    // MARK: - Bindings & actions

    private func binding(_ keyPath: WritableKeyPath<Habit, String>) -> Binding<String> {
        Binding(
            get: { draft?[keyPath: keyPath] ?? "" },
            set: { newValue in draft?[keyPath: keyPath] = newValue }
        )
    }

    private func lawBinding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: {
                guard let d = draft, d.lawChecks.indices.contains(index) else { return false }
                return d.lawChecks[index]
            },
            set: { newValue in
                guard var d = draft, d.lawChecks.indices.contains(index) else { return }
                d.lawChecks[index] = newValue
                draft = d
            }
        )
    }

    private func toggleToday() {
        guard var current = draft else { return }
        let today = DayHelper.todayString()
        if current.checkinDates.contains(today) {
            current.checkinDates.removeAll { $0 == today }
        } else {
            current.checkinDates.append(today)
            current.checkinDates.sort()
        }
        draft = current
        store.update(current)
    }

    private func saveAndDismiss() {
        if let current = draft {
            store.update(current)
        }
        dismiss()
    }
}
