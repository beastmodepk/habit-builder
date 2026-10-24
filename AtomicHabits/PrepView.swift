import SwiftUI

/// Evening Prep (Cue — prime the environment): every habit's environment
/// checklist in one place, to be run the night before — book on the pillow,
/// gym bag by the door, shoes out. Items are edited per habit here and in
/// the habit's detail screen.
struct PrepView: View {
    @EnvironmentObject var store: HabitStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set tomorrow up tonight.")
                        .font(.title3).bold()
                        .foregroundStyle(AHColor.graphite)
                    Text("Environment beats willpower. Prime each cue now and the habit fires itself tomorrow.")
                        .font(.subheadline)
                        .foregroundStyle(AHColor.graphiteSecondary)
                }
                ForEach(store.habits) { habit in
                    PrepHabitCard(habit: habit)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AHColor.background.ignoresSafeArea())
        .navigationTitle("Evening Prep")
    }
}

private struct PrepHabitCard: View {
    @EnvironmentObject var store: HabitStore
    let habit: Habit
    @State private var newItem = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: habit.kind == .build ? "leaf.fill" : "shield.fill")
                    .foregroundStyle(AHColor.accent(for: habit.kind))
                Text(habit.title)
                    .font(AHFont.cardTitle)
                    .foregroundStyle(AHColor.graphite)
                Spacer()
                if !habit.prepItems.isEmpty {
                    Text("\(habit.prepItems.filter { $0.done }.count)/\(habit.prepItems.count) ready")
                        .font(AHFont.caption)
                        .foregroundStyle(AHColor.graphiteSecondary)
                }
            }
            if habit.prepItems.isEmpty {
                Text("No prep items yet — add the thing that makes tomorrow's cue obvious.")
                    .font(.footnote)
                    .foregroundStyle(AHColor.graphiteSecondary)
            }
            ForEach(habit.prepItems) { item in
                HStack(spacing: 10) {
                    Button {
                        toggle(item)
                    } label: {
                        Image(systemName: item.done ? "checkmark.square.fill" : "square")
                            .foregroundStyle(item.done ? AHColor.build : AHColor.graphiteSecondary)
                    }
                    .buttonStyle(.plain)
                    Text(item.title)
                        .font(.subheadline)
                        .foregroundStyle(AHColor.graphite)
                        .strikethrough(item.done, color: AHColor.graphiteSecondary)
                    Spacer()
                }
            }
            HStack(spacing: 8) {
                TextField("Add a prep item", text: $newItem)
                    .textFieldStyle(.roundedBorder)
                Button("Add") { add() }
                    .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .ahCard(padding: 16)
    }

    private func toggle(_ item: PrepItem) {
        guard var copy = store.habit(id: habit.id),
              let idx = copy.prepItems.firstIndex(where: { $0.id == item.id }) else { return }
        copy.prepItems[idx].done.toggle()
        store.update(copy)
    }

    private func add() {
        guard var copy = store.habit(id: habit.id) else { return }
        copy.prepItems.append(PrepItem(title: newItem.trimmingCharacters(in: .whitespaces)))
        newItem = ""
        store.update(copy)
    }
}
