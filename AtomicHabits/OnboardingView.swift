import SwiftUI

/// Opal-style first-launch enrollment ("enrolls you"): a guided,
/// question-by-question flow — welcome, name, path, a few diagnostic
/// taps, a computed personal reveal, a generated first habit (or two),
/// an identity + commitment moment, the reminder permission asked at
/// the moment of motivation, and a celebration that lands on Today with
/// the plan already in place.
///
/// Shown only from a pristine store (see `HabitStore.shouldPresentOnboarding`);
/// completing or skipping it never deletes or alters existing habits.
/// No paywall, no account, no network — everything stays on-device.
struct OnboardingView: View {
    @EnvironmentObject var store: HabitStore
    let onFinish: () -> Void

    private enum Step: Int {
        case welcome, name, path, buildDiag, quitDiag, reveal, buildPlan, quitPlan, identity, reminder, done
    }

    private enum PathChoice: String {
        case build, quit, both
    }

    @State private var step: Step = .welcome
    @State private var history: [Step] = []

    // Answers — who + which path
    @State private var nameText = ""
    @State private var pathChoice: PathChoice?

    // Answers — build diagnostics
    @State private var buildTitle = ""
    @State private var buildCurrentDays = 3
    @State private var buildObstacle = ""

    // Answers — quit diagnostics
    @State private var quitTitle = ""
    @State private var quitFrequency = "Daily"
    @State private var quitCostText = ""
    @State private var quitDuration = ""

    // Answers — build plan
    @State private var anchorChoice = "wake up"
    @State private var cueDate: Date = OnboardingView.defaultCueDate()
    @State private var cuePlace = ""
    @State private var twoMinute = ""

    // Answers — quit plan
    @State private var cueWhen = ""
    @State private var cueWhere = ""
    @State private var replacement = ""

    // Answers — identity & commitment
    @State private var buildIdentity = ""
    @State private var quitIdentity = ""
    @State private var consequence = ""
    @State private var witness = ""
    @State private var commitArmed = false

    // Habits created at the commitment step
    @State private var createdIDs: [UUID] = []

    // MARK: - Derived answers

    private var includesBuild: Bool { pathChoice == .build || pathChoice == .both }
    private var includesQuit: Bool { pathChoice == .quit || pathChoice == .both }
    private var trimmedName: String { nameText.ob_trimmed }
    private var firstName: String {
        trimmedName.split(separator: " ").first.map(String.init) ?? trimmedName
    }
    private var quitCost: Double {
        Double(quitCostText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    private var createdHabits: [Habit] {
        store.habits.filter { createdIDs.contains($0.id) }
    }
    private var hasCueReminder: Bool {
        createdHabits.contains { !$0.cueTime.isEmpty }
    }
    private var progress: Double {
        Double(step.rawValue) / Double(Step.done.rawValue)
    }

    // MARK: - Navigation

    private func nextStep(after s: Step) -> Step? {
        switch s {
        case .welcome: return .name
        case .name: return .path
        case .path: return includesBuild ? .buildDiag : .quitDiag
        case .buildDiag: return includesQuit ? .quitDiag : .reveal
        case .quitDiag: return .reveal
        case .reveal: return includesBuild ? .buildPlan : .quitPlan
        case .buildPlan: return includesQuit ? .quitPlan : .identity
        case .quitPlan: return .identity
        case .identity: return hasCueReminder ? .reminder : .done
        case .reminder: return .done
        case .done: return nil
        }
    }

    private func goNext() {
        guard let next = nextStep(after: step) else { return }
        history.append(step)
        commitArmed = false
        withAnimation(.easeInOut(duration: 0.3)) { step = next }
    }

    private func goBack() {
        guard let previous = history.popLast() else { return }
        commitArmed = false
        withAnimation(.easeInOut(duration: 0.3)) { step = previous }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AHColor.background.ignoresSafeArea()
            VStack(spacing: 0) {
                if step != .welcome && step != .done {
                    header
                }
                switch step {
                case .welcome: welcomeStep
                case .name: nameStep
                case .path: pathStep
                case .buildDiag: buildDiagStep
                case .quitDiag: quitDiagStep
                case .reveal: revealStep
                case .buildPlan:
                    buildPlanStep
                        .onAppear { prefillTwoMinute() }
                case .quitPlan: quitPlanStep
                case .identity:
                    identityStep
                        .onAppear { prefillIdentities() }
                case .reminder: reminderStep
                case .done: doneStep
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button { goBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AHColor.graphite)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(AHColor.surface))
                    .overlay(Circle().strokeBorder(AHColor.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .opacity(history.isEmpty ? 0 : 1)
            .disabled(history.isEmpty)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AHColor.hairline)
                    Capsule()
                        .fill(AHColor.champagne)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Shared building blocks

    private func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                content()
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stepTitle(_ title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(AHColor.graphite)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AHColor.graphiteSecondary)
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AHColor.graphite)
    }

    private func cta(title: String, color: Color, enabled: Bool = true,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(enabled ? color : AHColor.hairline)
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func chipRow(_ options: [String], selected: String, color: Color,
                         display: @escaping (String) -> String = { $0 },
                         onSelect: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)],
                  alignment: .leading, spacing: 10) {
            ForEach(options, id: \.self) { option in
                ObChip(title: display(option), selected: selected == option, color: color) {
                    onSelect(option)
                }
            }
        }
    }

    // MARK: - Step 1 · Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()
            ActivityRingView(progress: 0.72, color: AHColor.build, size: 148,
                             lineWidth: 14, title: "1%", subtitle: "better daily")
            Text("Small habits.\nRemarkable results.")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AHColor.graphite)
                .multilineTextAlignment(.center)
                .padding(.top, 28)
            Text("Improve by just 1% every day and a year compounds to 37.8\u{00D7}. Enrollment takes about a minute — answer a few questions and we will design your first habit with you.")
                .font(.subheadline)
                .foregroundStyle(AHColor.graphiteSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 8)
            Spacer()
            cta(title: "Get started", color: AHColor.build) { goNext() }
            Button {
                store.skipOnboarding()
                onFinish()
            } label: {
                Text("Explore first — I already have a setup")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AHColor.graphiteSecondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 26)
    }

    // MARK: - Step 2 · Name

    private var nameStep: some View {
        page {
            stepTitle("What should we call you?",
                      subtitle: "Your name goes on your plan — and on your commitment.")
            TextField("Your name", text: $nameText)
                .font(.title3)
                .obField()
                .autocorrectionDisabled()
            cta(title: "Continue", color: AHColor.build, enabled: !trimmedName.isEmpty) {
                goNext()
            }
        }
    }

    // MARK: - Step 3 · Path

    private var pathStep: some View {
        page {
            stepTitle("What are we working on\(firstName.isEmpty ? "" : ", \(firstName)")?",
                      subtitle: "Pick one — you can always add the other later.")
            pathCard(.build, icon: "leaf.fill", color: AHColor.build,
                     title: "Build a habit",
                     subtitle: "Start something good and make it stick.")
            pathCard(.quit, icon: "shield.fill", color: AHColor.quit,
                     title: "Break a habit",
                     subtitle: "Quit something that is costing you.")
            pathCard(.both, icon: "arrow.triangle.2.circlepath", color: AHColor.champagne,
                     title: "Both",
                     subtitle: "Build one, break one — the full reset.")
            cta(title: "Continue", color: AHColor.build, enabled: pathChoice != nil) {
                goNext()
            }
        }
    }

    private func pathCard(_ choice: PathChoice, icon: String, color: Color,
                          title: String, subtitle: String) -> some View {
        let selected = pathChoice == choice
        return Button { pathChoice = choice } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AHFont.cardTitle)
                        .foregroundStyle(AHColor.graphite)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AHColor.graphiteSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? color : AHColor.graphiteSecondary.opacity(0.5))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selected ? color.opacity(0.10) : AHColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(selected ? color : AHColor.hairline,
                                  lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 4 · Diagnostics

    private var buildDiagStep: some View {
        page {
            stepTitle("First, the build",
                      subtitle: "Three quick answers — be honest, the reveal uses your real numbers.")
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("What do you want to build?")
                TextField("e.g. Read 10 pages", text: $buildTitle)
                    .obField()
                chipRow(["Read 10 pages", "Work out", "10,000 steps", "Meditate", "Write in a journal"],
                        selected: buildTitle, color: AHColor.build) { buildTitle = $0 }
            }
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("How many days a week do you manage it now?")
                daysRow
            }
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("Biggest obstacle?")
                chipRow(["Forgetting", "No set time", "Starts too big", "Motivation fades"],
                        selected: buildObstacle, color: AHColor.build) { buildObstacle = $0 }
            }
            cta(title: "Continue", color: AHColor.build,
                enabled: !buildTitle.ob_trimmed.isEmpty) { goNext() }
        }
    }

    private var daysRow: some View {
        HStack(spacing: 8) {
            ForEach(0...7, id: \.self) { day in
                Button { buildCurrentDays = day } label: {
                    Text("\(day)")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(buildCurrentDays == day ? AHColor.build : AHColor.surface)
                        )
                        .foregroundStyle(buildCurrentDays == day ? .white : AHColor.graphite)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(buildCurrentDays == day ? AHColor.build : AHColor.hairline,
                                              lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quitDiagStep: some View {
        page {
            stepTitle("Now, the break",
                      subtitle: "Same deal — a few honest answers, no judgement.")
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("What do you want to quit?")
                TextField("e.g. Alcohol", text: $quitTitle)
                    .obField()
                chipRow(["Alcohol", "Smoking", "Vaping", "Social media", "Sugar"],
                        selected: quitTitle, color: AHColor.quit) { quitTitle = $0 }
            }
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("How often does it happen?")
                chipRow(["Daily", "A few times a week", "Weekly", "Rarely"],
                        selected: quitFrequency, color: AHColor.quit) { quitFrequency = $0 }
            }
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("What does it cost you per day?")
                HStack(spacing: 8) {
                    Text("$")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AHColor.graphiteSecondary)
                    TextField("0", text: $quitCostText)
                        .keyboardType(.decimalPad)
                        .obField()
                }
                if quitCost > 0 {
                    Text("That is $\(Int(quitCost * 365)) over a year.")
                        .font(.footnote)
                        .foregroundStyle(AHColor.champagne)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("How long has it been a habit?")
                chipRow(["Under 6 months", "6–12 months", "1–3 years", "Over 3 years"],
                        selected: quitDuration, color: AHColor.quit) { quitDuration = $0 }
            }
            cta(title: "Continue", color: AHColor.quit,
                enabled: !quitTitle.ob_trimmed.isEmpty) { goNext() }
        }
    }

    // MARK: - Step 5 · The Reveal

    private var revealStep: some View {
        page {
            stepTitle("Here is what your answers add up to\(firstName.isEmpty ? "" : ", \(firstName)")",
                      subtitle: "Computed from what you just told us — nothing generic.")
            if includesBuild {
                buildRevealCard
            }
            if includesQuit {
                quitRevealCard
            }
            Text("Projections, not promises — they simply show the shape of consistency when the days stack up.")
                .font(.footnote)
                .foregroundStyle(AHColor.graphiteSecondary)
            cta(title: "Build my plan", color: AHColor.build) { goNext() }
        }
    }

    private var buildRevealCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1% better every day")
                        .font(AHFont.cardTitle)
                        .foregroundStyle(AHColor.graphite)
                    Text("compounds for a year (1.01\u{2073}\u{2076}\u{2075}) to")
                        .font(.footnote)
                        .foregroundStyle(AHColor.graphiteSecondary)
                }
                Spacer(minLength: 0)
                Text("37.8\u{00D7}")
                    .font(AHFont.heroNumber)
                    .foregroundStyle(AHColor.build)
            }
            CompoundingCurveView()
            Divider().overlay(AHColor.hairline)
            if buildCurrentDays > 0 {
                Text("At your current \(buildCurrentDays) day\(buildCurrentDays == 1 ? "" : "s") a week, \(buildTitle.ob_trimmed) earns **\(buildCurrentDays * 12) votes** in your first 12 weeks.")
                    .font(.subheadline)
                    .foregroundStyle(AHColor.graphite)
            } else {
                Text("You are starting from zero days a week — so every rhythm from here is pure gain.")
                    .font(.subheadline)
                    .foregroundStyle(AHColor.graphite)
            }
            Text("Show up daily and it is **\(7 * 12) votes** in 12 weeks. That is the whole system: votes, stacked.")
                .font(.subheadline)
                .foregroundStyle(AHColor.graphite)
        }
        .ahCard()
    }

    private var quitRevealCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Breaking \(quitTitle.ob_trimmed)")
                .font(AHFont.cardTitle)
                .foregroundStyle(AHColor.graphite)
            if quitCost > 0 {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kept in your pocket in one year")
                            .font(.footnote)
                            .foregroundStyle(AHColor.graphiteSecondary)
                        Text("at $\(Int(quitCost)) a day, every clean day pays you")
                            .font(.footnote)
                            .foregroundStyle(AHColor.graphiteSecondary)
                    }
                    Spacer(minLength: 0)
                    Text("$\(Int(quitCost * 365))")
                        .font(AHFont.heroNumber)
                        .foregroundStyle(AHColor.quit)
                }
            }
            Divider().overlay(AHColor.hairline)
            Text("Your first 12 weeks hold **84 clean days**\(quitCost > 0 ? " — and $\(Int(quitCost * 84)) saved across them" : "").")
                .font(.subheadline)
                .foregroundStyle(AHColor.graphite)
            if !quitDuration.isEmpty {
                Text("It has been a habit for \(quitDuration.lowercased()). It was built one day at a time; it comes apart the same way.")
                    .font(.subheadline)
                    .foregroundStyle(AHColor.graphiteSecondary)
            }
        }
        .ahCard()
    }

    // MARK: - Step 6 · Your plan, generated

    private var buildPlanStep: some View {
        page {
            stepTitle(planTitle, subtitle: "Designed from your answers — tweak anything.")
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("I will do it after I…")
                chipRow(["wake up", "have coffee", "finish lunch", "finish dinner", "brush my teeth"],
                        selected: anchorChoice, color: AHColor.build,
                        display: { "After I \($0)" }) { anchorChoice = $0 }
            }
            HStack(spacing: 16) {
                fieldLabel("At")
                DatePicker("", selection: $cueDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("Where?")
                TextField("e.g. in bed, at the gym", text: $cuePlace)
                    .obField()
            }
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("The 2-minute version — for the hard days")
                TextField("2-minute version", text: $twoMinute)
                    .obField()
            }
            VStack(alignment: .leading, spacing: 10) {
                AHSectionHeader(title: "Your habit, as it will appear", systemImage: "eye")
                OnboardingHabitPreview(habit: draftBuildHabit())
            }
            cta(title: "Looks right", color: AHColor.build) { goNext() }
        }
    }

    private var quitPlanStep: some View {
        page {
            stepTitle(planTitle, subtitle: "Know the cue. Starve it. Replace it.")
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("When does the craving usually hit?")
                TextField("e.g. After dinner", text: $cueWhen)
                    .obField()
                chipRow(["After dinner", "With coffee", "When stressed", "Out with friends"],
                        selected: cueWhen, color: AHColor.quit) { cueWhen = $0 }
            }
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("Where are you when it hits?")
                TextField("e.g. On the porch", text: $cueWhere)
                    .obField()
            }
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("Your replacement — what happens instead?")
                TextField("e.g. Sparkling water", text: $replacement)
                    .obField()
                chipRow(["Sparkling water", "A short walk", "Make tea", "Chew gum", "Call a friend"],
                        selected: replacement, color: AHColor.quit) { replacement = $0 }
            }
            VStack(alignment: .leading, spacing: 10) {
                AHSectionHeader(title: "Your habit, as it will appear", systemImage: "eye")
                OnboardingHabitPreview(habit: draftQuitHabit())
            }
            cta(title: "Looks right", color: AHColor.quit) { goNext() }
        }
    }

    private var planTitle: String {
        firstName.isEmpty ? "Here is your plan" : "\(firstName), here is your plan"
    }

    // MARK: - Step 7 · Identity & commitment

    private var identityStep: some View {
        page {
            stepTitle("Become the person",
                      subtitle: "Every action is a vote for the type of person you wish to become. This is who the votes are for.")
            if includesBuild {
                VStack(alignment: .leading, spacing: 10) {
                    fieldLabel("For \(buildTitle.ob_trimmed)")
                    TextField("I am a person who…", text: $buildIdentity, axis: .vertical)
                        .obField()
                }
            }
            if includesQuit {
                VStack(alignment: .leading, spacing: 10) {
                    fieldLabel("For quitting \(quitTitle.ob_trimmed)")
                    TextField("I am a person who…", text: $quitIdentity, axis: .vertical)
                        .obField()
                }
                contractCard
            }
            cta(title: commitArmed ? "Tap again to commit" : (includesQuit ? "Sign & commit" : "I commit to my plan"),
                color: includesQuit && !includesBuild ? AHColor.quit : AHColor.build) {
                if commitArmed {
                    commit()
                } else {
                    withAnimation { commitArmed = true }
                }
            }
            if commitArmed {
                Text("One more tap makes it real — your habit goes on Today and your plan starts.")
                    .font(.footnote)
                    .foregroundStyle(AHColor.graphiteSecondary)
            }
        }
    }

    private var contractCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            AHSectionHeader(title: "Your contract", systemImage: "signature", color: AHColor.quit)
            Text(commitmentText)
                .font(.subheadline)
                .foregroundStyle(AHColor.graphite)
            TextField("If I slip, I will…", text: $consequence)
                .obField()
            TextField("My witness", text: $witness)
                .obField()
            Text("Signed: \(trimmedName.isEmpty ? "—" : trimmedName) · \(Self.longDate(Date()))")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AHColor.champagne)
        }
        .ahCard()
    }

    private var commitmentText: String {
        let who = trimmedName.isEmpty ? "I" : "I, \(trimmedName),"
        return "\(who) commit to quitting \(sentenceStart(quitTitle.ob_trimmed)) from today, \(Self.longDate(Date()))."
    }

    private func commit() {
        var ids: [UUID] = []
        if includesBuild {
            var habit = draftBuildHabit()
            habit.identityStatement = buildIdentity.ob_trimmed
            habit.lawChecks = [!habit.anchor.isEmpty, false, !habit.twoMinuteVersion.isEmpty, false]
            store.add(habit)
            ids.append(habit.id)
        }
        if includesQuit {
            var habit = draftQuitHabit()
            habit.identityStatement = quitIdentity.ob_trimmed
            habit.contract = HabitContract(
                commitment: commitmentText,
                consequence: consequence.ob_trimmed,
                witness: witness.ob_trimmed,
                isSigned: true,
                signedDate: DayHelper.todayString()
            )
            habit.lawChecks = [!cueWhen.ob_trimmed.isEmpty, quitCost > 0,
                               !replacement.ob_trimmed.isEmpty, true]
            store.add(habit)
            ids.append(habit.id)
        }
        createdIDs = ids
        store.completeOnboarding(name: trimmedName,
                                  path: pathChoice?.rawValue ?? PathChoice.both.rawValue)
        goNext()
    }

    // MARK: - Step 8 · Reminder permission (at the motivated moment)

    private var reminderStep: some View {
        page {
            VStack(alignment: .center, spacing: 16) {
                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AHColor.champagne)
                Text("One last thing — your cue reminder")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AHColor.graphite)
                    .multilineTextAlignment(.center)
                if let cue = createdHabits.first(where: { !$0.cueTime.isEmpty }) {
                    Text("\u{201C}After I \(cue.anchor)\u{201D} fires at \(Self.displayTime(fromHHmm: cue.cueTime)). A gentle nudge lands right then — at the exact moment the habit is supposed to start.")
                        .font(.subheadline)
                        .foregroundStyle(AHColor.graphiteSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            cta(title: "Turn on my cue reminder", color: AHColor.build) {
                Task {
                    let granted = await AnchorNotifications.requestAuthorization()
                    if granted {
                        for habit in createdHabits where !habit.cueTime.isEmpty {
                            AnchorNotifications.schedule(for: habit)
                        }
                    }
                    goNext()
                }
            }
            Button { goNext() } label: {
                Text("Not now")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AHColor.graphiteSecondary)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Step 9 · Done

    private var doneStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(AHColor.champagne)
                        .padding(.top, 36)
                    Text("You\u{2019}re in\(firstName.isEmpty ? "" : ", \(firstName)").")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AHColor.graphite)
                    Text("Your plan starts today. Day one asks for exactly one vote.")
                        .font(.subheadline)
                        .foregroundStyle(AHColor.graphiteSecondary)
                        .multilineTextAlignment(.center)
                    ForEach(createdHabits) { habit in
                        OnboardingHabitPreview(habit: habit)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
            cta(title: includesBuild ? "Cast your first vote" : "Start clean — day one",
                color: includesBuild ? AHColor.build : AHColor.quit) {
                onFinish()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 26)
        }
    }

    // MARK: - Habit generation (shared by preview + commit)

    private func draftBuildHabit() -> Habit {
        var habit = Habit(kind: .build, title: buildTitle.ob_trimmed)
        habit.anchor = anchorChoice
        habit.cueTime = Self.timeString(from: cueDate)
        habit.cuePlace = cuePlace.ob_trimmed
        habit.twoMinuteVersion = twoMinute.ob_trimmed
        habit.habitStack = stackSentence()
        return habit
    }

    private func draftQuitHabit() -> Habit {
        var habit = Habit(kind: .quit, title: quitTitle.ob_trimmed)
        habit.anchor = cueWhen.ob_trimmed
        habit.cuePlace = cueWhere.ob_trimmed
        habit.replacementHabit = replacement.ob_trimmed
        habit.dailyCost = quitCost
        if quitCost > 0 {
            habit.costList = "Costs about $\(Int(quitCost)) a day — $\(Int(quitCost * 365)) a year."
        }
        return habit
    }

    private func stackSentence() -> String {
        var sentence = "After I \(anchorChoice), I will \(sentenceStart(buildTitle.ob_trimmed)) at \(Self.displayTime(from: cueDate))"
        let place = cuePlace.ob_trimmed
        if !place.isEmpty {
            sentence += " \(placePhrase(place))"
        }
        return sentence + "."
    }

    /// "in bed" / "at the gym" style place phrases, mirroring the
    /// sentence grammar used by the generated stacks elsewhere.
    private func placePhrase(_ place: String) -> String {
        let lower = place.lowercased()
        let inPlaces = ["bed", "bedroom", "the bedroom", "kitchen", "the kitchen",
                        "the garden", "garden", "my bedroom", "my bed", "my kitchen"]
        if inPlaces.contains(lower) {
            return "in \(place)"
        }
        return "at \(place)"
    }

    /// Lowercases the first character for mid-sentence use, unless the
    /// second character is uppercase (an acronym like "AA").
    private func sentenceStart(_ text: String) -> String {
        guard let first = text.first else { return text }
        if let second = text.dropFirst().first, second.isUppercase {
            return text
        }
        return first.lowercased() + text.dropFirst()
    }

    // MARK: - Prefills (only when the user has not typed anything)

    private func prefillTwoMinute() {
        let title = buildTitle.ob_trimmed
        if twoMinute.isEmpty && !title.isEmpty {
            twoMinute = "\(title) for just 2 minutes."
        }
    }

    private func prefillIdentities() {
        if includesBuild && buildIdentity.isEmpty {
            let title = buildTitle.ob_trimmed
            if !title.isEmpty {
                buildIdentity = "I am a person who makes time for \(sentenceStart(title)) every day."
            }
        }
        if includesQuit && quitIdentity.isEmpty {
            let title = quitTitle.ob_trimmed
            if !title.isEmpty {
                quitIdentity = "I am a person who is free from \(sentenceStart(title))."
            }
        }
    }

    // MARK: - Formatting helpers

    private static func defaultCueDate() -> Date {
        Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private static func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private static func displayTime(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private static func displayTime(fromHHmm hhmm: String) -> String {
        guard let hm = AnchorNotifications.components(from: hhmm) else { return hhmm }
        var comps = DateComponents()
        comps.hour = hm.hour
        comps.minute = hm.minute
        guard let date = Calendar.current.date(from: comps) else { return hhmm }
        return displayTime(from: date)
    }

    private static func longDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM d, yyyy"
        return f.string(from: date)
    }
}

// MARK: - File-scope components

struct ObChip: View {
    let title: String
    let selected: Bool
    var color: Color = AHColor.build
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selected ? color : AHColor.graphite)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(selected ? color.opacity(0.14) : AHColor.surface))
                .overlay(
                    Capsule().strokeBorder(selected ? color : AHColor.hairline,
                                           lineWidth: selected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// The generated habit as a Today-style card — same design tokens as the
/// real `HabitCardView`, minus its navigation/check-in controls.
struct OnboardingHabitPreview: View {
    let habit: Habit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: habit.kind == .build ? "leaf.fill" : "shield.fill")
                    .foregroundStyle(AHColor.accent(for: habit.kind))
                Text(habit.title)
                    .font(AHFont.cardTitle)
                    .foregroundStyle(AHColor.graphite)
                Spacer(minLength: 0)
                StreakPill(streak: 0, label: habit.kind == .build ? "day streak" : "clean days")
            }
            if !habit.habitStack.isEmpty {
                Text(habit.habitStack)
                    .font(.footnote)
                    .foregroundStyle(AHColor.graphiteSecondary)
            }
            if habit.kind == .build && !habit.twoMinuteVersion.isEmpty {
                Text("2-minute version: \(habit.twoMinuteVersion)")
                    .font(.footnote)
                    .foregroundStyle(AHColor.champagne)
            }
            if habit.kind == .quit && !habit.replacementHabit.isEmpty {
                Text("Instead: \(habit.replacementHabit)")
                    .font(.footnote)
                    .foregroundStyle(AHColor.graphiteSecondary)
            }
            if habit.kind == .quit && habit.dailyCost > 0 {
                Text("Keeping $\(Int(habit.dailyCost * 365)) a year")
                    .font(.footnote).bold()
                    .foregroundStyle(AHColor.champagne)
            }
            ChainStripView(habit: habit)
        }
        .ahCard(padding: 16)
    }
}

/// The 1%-better compounding curve: 1.01^day over a year, drawn as a
/// simple SwiftUI path (no chart framework, no invented data).
struct CompoundingCurveView: View {
    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let maxValue = 37.78
                Path { path in
                    for i in 0...48 {
                        let day = Double(i) / 48.0 * 365.0
                        let value = pow(1.01, day)
                        let x = width * CGFloat(i) / 48.0
                        let y = height - (CGFloat(value / maxValue) * (height - 8)) - 4
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(AHColor.build, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 92)
            HStack {
                Text("Day 1 · 1.0\u{00D7}")
                Spacer()
                Text("Day 365 · 37.8\u{00D7}")
            }
            .font(.caption)
            .foregroundStyle(AHColor.graphiteSecondary)
        }
    }
}

extension View {
    /// Onboarding text-field chrome: surface fill, hairline edge, soft corners.
    func obField() -> some View {
        self
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AHColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AHColor.hairline, lineWidth: 1)
            )
    }
}

extension String {
    var ob_trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
