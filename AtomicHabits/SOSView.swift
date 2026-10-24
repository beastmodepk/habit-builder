import SwiftUI

/// App-level navigation router for deep links:
/// atomichabits://urge-timer, atomichabits://sos, atomichabits://today.
final class AppRouter: ObservableObject {
    @Published var showSOS = false
    @Published var showTimer = false
}

/// Urge SOS (Quit — intercept the craving): one flow — pick the quit habit,
/// rate the urge, see your replacement, start the timer, rate it after,
/// save. The saved entry feeds Urge Pattern Insights.
struct SOSView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedID: UUID?
    @State private var cue = ""
    @State private var intensityBefore = 7
    @State private var intensityAfter = 3

    private var quitHabits: [Habit] { store.habits.filter { $0.kind == .quit } }
    private var selected: Habit? {
        store.habits.first { $0.id == (selectedID ?? quitHabits.first?.id) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "lifepreserver.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(AHColor.quit)
                        Text("Ride this one out. Urges peak and pass — give it 10 minutes.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(AHColor.graphiteSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                if quitHabits.count > 1 {
                    Section("Which habit is calling?") {
                        Picker("Quit habit", selection: Binding(
                            get: { selectedID ?? quitHabits.first?.id ?? UUID() },
                            set: { selectedID = $0 }
                        )) {
                            ForEach(quitHabits) { habit in
                                Text(habit.title).tag(habit.id)
                            }
                        }
                    }
                }

                Section("Right now") {
                    TextField("Cue — what just happened?", text: $cue)
                    Stepper("Urge intensity: \(intensityBefore)/10", value: $intensityBefore, in: 1...10)
                }

                if let habit = selected, !habit.replacementHabit.isEmpty {
                    Section("Your replacement") {
                        Label(habit.replacementHabit, systemImage: "arrow.triangle.swap")
                            .font(.subheadline)
                    }
                }

                Section("10-minute timer") {
                    NavigationLink("Start the urge timer") {
                        UrgeTimerView()
                    }
                }

                Section("After it passes") {
                    Stepper("Intensity now: \(intensityAfter)/10", value: $intensityAfter, in: 0...10)
                    Button("Save this urge") { save() }
                        .disabled(selected == nil)
                }
            }
            .navigationTitle("Urge SOS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func save() {
        guard var habit = selected else { return }
        habit.urgeLogs.append(UrgeLogEntry(
            date: Date(),
            cue: cue,
            craving: "",
            instead: habit.replacementHabit,
            intensityBefore: intensityBefore,
            intensityAfter: intensityAfter
        ))
        habit.urgeLogs.sort { $0.date > $1.date }
        store.update(habit)
        dismiss()
    }
}
