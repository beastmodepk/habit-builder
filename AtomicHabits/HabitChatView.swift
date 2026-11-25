import SwiftUI

/// The AI Habit Coach chat — the app's launch screen and the new front
/// door for adding a habit (replacing the blank form as the first step).
///
/// Pattern (Parthey's orders, 2026-11-25):
/// - Identity first: "Who do you want to be?"
/// - Every coach question shows 2–3 TAPPABLE suggestion chips, plus a
///   final NON-clickable grey hint row: "or type your own answer here…"
/// - The coach suggests a full habit; nothing is saved until the user
///   taps "Add this habit" on the confirmation card.
struct HabitChatView: View {
    @EnvironmentObject var store: HabitStore
    @StateObject private var coach = HabitCoach()
    @State private var inputText = ""
    @State private var showingEditDetails = false

    /// When true (opened from a + Build / + Quit button), skip the
    /// returning-user welcome menu and go straight to identity.
    var forceNewHabit: Bool = false
    /// Welcome-step choices that leave the chat (Today / Review tabs).
    var onWelcomeAction: ((CoachWelcomeAction) -> Void)? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                if coach.step == .confirm {
                    confirmationCard
                } else if !coach.isFinished {
                    optionsArea
                }
                if !coach.isFinished && coach.step != .confirm {
                    inputBar
                }
            }
            .background(AHColor.background.ignoresSafeArea())
            .navigationTitle("Habit Coach")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !coach.isFinished {
                        Button("Cancel") { coach.cancel() }
                            .foregroundStyle(AHColor.graphiteSecondary)
                    }
                }
            }
            .onAppear {
                coach.start(returning: forceNewHabit ? false : !store.habits.isEmpty)
            }
            .onChange(of: coach.welcomeAction) { _, action in
                if let action { onWelcomeAction?(action) }
            }
            .sheet(isPresented: $showingEditDetails) {
                AddHabitView(kind: coach.draft.kind)
            }
        }
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(coach.messages) { message in
                        bubble(message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .onChange(of: coach.messages.count) { _, _ in
                if let last = coach.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func bubble(_ message: CoachMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }
            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(message.role == .coach ? AHColor.graphite : Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(message.role == .coach ? AHColor.surface : AHColor.build)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AHColor.hairline, lineWidth: message.role == .coach ? 1 : 0)
                )
            if message.role == .coach { Spacer(minLength: 48) }
        }
    }

    // MARK: - Options (tappable chips + non-clickable hint)

    private var optionsArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(coach.options, id: \.self) { option in
                Button {
                    coach.selectOption(option)
                } label: {
                    HStack {
                        Text(option)
                            .font(.subheadline).bold()
                            .foregroundStyle(AHColor.accent(for: coach.draft.kind))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption).bold()
                            .foregroundStyle(AHColor.graphiteSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AHColor.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AHColor.hairline, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            // Final row: a hint, deliberately NOT a button (Parthey's order).
            Text("or type your own answer here…")
                .font(.footnote)
                .foregroundStyle(AHColor.graphiteSecondary)
                .padding(.horizontal, 4)
                .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message the coach…", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(sendInput)
            Button {
                sendInput()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AHColor.build)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func sendInput() {
        let text = inputText
        inputText = ""
        coach.send(text)
    }

    // MARK: - Confirmation card (editable; Add is the only save)

    private var confirmationCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                AHSectionHeader(title: "Confirm this habit", systemImage: "checkmark.seal.fill",
                                color: AHColor.champagne)
                Text(coach.draft.kind == .build ? "Build habit" : "Quit habit")
                    .font(AHFont.caption)
                    .foregroundStyle(AHColor.accent(for: coach.draft.kind))

                field("Title") {
                    TextField("Title", text: $coach.draft.title)
                }
                field("Identity") {
                    TextField("I am…", text: $coach.draft.identityStatement)
                }
                field("After I… (anchor)") {
                    TextField("finish lunch, wake up…", text: $coach.draft.anchor)
                }
                HStack(spacing: 12) {
                    field("Time (HH:mm)") {
                        TextField("13:00", text: $coach.draft.cueTime)
                    }
                    field("Place") {
                        TextField("bedroom, gym…", text: $coach.draft.cuePlace)
                    }
                }
                if coach.draft.kind == .build {
                    field("2-minute version") {
                        TextField("Smallest version…", text: $coach.draft.twoMinuteVersion)
                    }
                    field("One prep item") {
                        TextField("Shoes by the door…", text: prepBinding)
                    }
                    Text(coach.draft.habitStack)
                        .font(.footnote)
                        .foregroundStyle(AHColor.graphiteSecondary)
                } else {
                    field("Real costs") {
                        TextField("One cost per line", text: $coach.draft.costList, axis: .vertical)
                    }
                    field("Replacement") {
                        TextField("Instead I will…", text: $coach.draft.replacementHabit)
                    }
                    field("2-minute version") {
                        TextField("Smallest version…", text: $coach.draft.twoMinuteVersion)
                    }
                }

                Button {
                    if let habit = coach.confirmAdd() {
                        store.add(habit)
                    }
                } label: {
                    Text("Add this habit")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(AHColor.accent(for: coach.draft.kind))
                .disabled(coach.draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                HStack(spacing: 10) {
                    Button("Edit details") { showingEditDetails = true }
                        .buttonStyle(.bordered)
                    Button("Start over") { coach.reset() }
                        .buttonStyle(.bordered)
                        .foregroundStyle(AHColor.graphiteSecondary)
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 430)
        .background(AHColor.surface)
        .overlay(Divider().overlay(AHColor.hairline), alignment: .top)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(AHColor.graphiteSecondary)
            content()
                .textFieldStyle(.roundedBorder)
        }
    }

    /// The single prep item as a plain string binding.
    private var prepBinding: Binding<String> {
        Binding(
            get: { coach.draft.prepItems.first ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                coach.draft.prepItems = trimmed.isEmpty ? [] : [trimmed]
            }
        )
    }
}
