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
    @State private var newPrepItem = ""

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
                    goldilocksSection(habit)
                    designSection(habit)
                    if habit.kind == .quit {
                        contractSection(habit)
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
            if habit.isChecked(on: DayHelper.todayString()) {
                Text(habit.checkinKind(on: DayHelper.todayString()) == .twoMinute
                     ? "Today logged as a 2-minute win — it still counts."
                     : "Today logged as a full win.")
                    .font(.footnote)
                    .foregroundStyle(AHColor.champagne)
            }
            if !checked && !habit.twoMinuteVersion.isEmpty {
                Button("Too much today? Do the 2-minute version") {
                    guard var current = draft else { return }
                    let today = DayHelper.todayString()
                    if !current.checkinDates.contains(today) {
                        current.checkinDates.append(today)
                        current.checkinDates.sort()
                    }
                    current.checkinKinds[today] = CheckinKind.twoMinute.rawValue
                    draft = current
                    store.update(current)
                }
            }
            Last14DaysView(habit: habit)
            Text("This month")
                .font(.footnote)
                .foregroundStyle(.secondary)
            MonthChainView(habit: habit)
            if DayHelper.missedYesterday(for: habit) {
                Label("You missed yesterday — never miss twice. Do the smallest version today.",
                      systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func goldilocksSection(_ habit: Habit) -> some View {
        let suggested = habit.twoMinuteVersion.isEmpty
            ? "Half of it — just the first step of: \(habit.title)"
            : habit.twoMinuteVersion
        Section("Goldilocks — just manageable") {
            if habit.isShrunkToday {
                Label("Shrunk until \(habit.shrunkUntil): \(habit.shrunkGoal)", systemImage: "scissors")
                    .font(.footnote)
                    .foregroundStyle(AHColor.champagne)
                Button("End shrink early") {
                    draft?.shrunkUntil = ""
                    draft?.shrunkGoal = ""
                }
            } else {
                if DayHelper.needsShrink(for: habit) {
                    Text("You missed 2+ of the last 3 days. That's data, not failure — the habit is sized too big right now.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text("Smaller version: \(suggested)")
                    .font(.subheadline)
                Button("Shrink it for 7 days") {
                    draft?.shrunkGoal = suggested
                    draft?.shrunkUntil = DayHelper.string(daysAgo: -7)
                }
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
            Section("Temptation bundle — make it attractive") {
                TextField("Only while doing this, I get to...", text: binding(\.temptationBundle), axis: .vertical)
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
        prepSection(habit)
        Section(habit.kind == .build ? "Four Laws" : "Four Laws — inverted") {
            let labels = habit.kind == .build ? buildLawLabels : quitLawLabels
            ForEach(0..<4, id: \.self) { index in
                Toggle(labels[index], isOn: lawBinding(index))
            }
        }
        Section("Reward — make it satisfying") {
            TextField("The immediate reward I get after", text: binding(\.rewardText), axis: .vertical)
        }
    }

    @ViewBuilder
    private func urgeSection(_ habit: Habit) -> some View {
        Section("Urge patterns") {
            UrgeInsightsView(habit: habit)
        }
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

    @ViewBuilder
    private func prepSection(_ habit: Habit) -> some View {
        Section("Environment prep") {
            ForEach(habit.prepItems) { item in
                HStack {
                    Image(systemName: item.done ? "checkmark.square.fill" : "square")
                        .foregroundStyle(item.done ? AHColor.build : .secondary)
                    Text(item.title)
                    Spacer()
                    Button(role: .destructive) {
                        draft?.prepItems.removeAll { $0.id == item.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                TextField("Add prep item (e.g. book on pillow)", text: $newPrepItem)
                Button("Add") {
                    let t = newPrepItem.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return }
                    draft?.prepItems.append(PrepItem(title: t))
                    newPrepItem = ""
                }
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

    @ViewBuilder
    private func contractSection(_ habit: Habit) -> some View {
        Section("Saved counter") {
            HStack {
                Text("Cost per day ($)")
                Spacer()
                TextField("0", value: doubleBinding(\.dailyCost), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
            }
            let saved = Double(habit.checkinDates.count) * habit.dailyCost
            Label("Saved so far: $\(saved, specifier: "%.2f") across \(habit.checkinDates.count) clean day(s)",
                  systemImage: "banknote.fill")
                .font(.subheadline)
                .foregroundStyle(AHColor.champagne)
        }
        Section("Habit contract") {
            TextField("I commit to...", text: contractBinding(\.commitment), axis: .vertical)
            TextField("If I break this, then...", text: contractBinding(\.consequence), axis: .vertical)
            TextField("Witness (e.g. Shannon)", text: contractBinding(\.witness))
            if habit.contract.isSigned {
                Label("Signed on \(habit.contract.signedDate)", systemImage: "signature")
                    .font(.footnote)
                    .foregroundStyle(AHColor.champagne)
                Button("Revoke signature") {
                    draft?.contract.isSigned = false
                    draft?.contract.signedDate = ""
                }
            } else {
                Button {
                    draft?.contract.isSigned = true
                    draft?.contract.signedDate = DayHelper.todayString()
                } label: {
                    Label("Sign this contract", systemImage: "signature")
                }
                .disabled(habit.contract.commitment.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func doubleBinding(_ keyPath: WritableKeyPath<Habit, Double>) -> Binding<Double> {
        Binding(
            get: { draft?[keyPath: keyPath] ?? 0 },
            set: { newValue in draft?[keyPath: keyPath] = newValue }
        )
    }

    private func contractBinding(_ keyPath: WritableKeyPath<HabitContract, String>) -> Binding<String> {
        Binding(
            get: { draft?.contract[keyPath: keyPath] ?? "" },
            set: { newValue in draft?.contract[keyPath: keyPath] = newValue }
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
