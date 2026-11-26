import SwiftUI

/// Identity board (Craving — identity-based habits): votes grouped by the
/// identity each habit votes for. "Every action you take is a vote for the
/// type of person you wish to become."
struct IdentityBoardView: View {
    @EnvironmentObject var store: HabitStore
    /// The day the per-group vote count refers to — today by default; the
    /// Today tab passes yesterday when its switcher is set.
    var dayString: String = DayHelper.todayString()
    var dayName: String = "today"
    /// Collapsible (Parthey's request, 2026-11-25): tap the header to
    /// fold the board away. Remembered across launches.
    @AppStorage("identityBoardExpanded") private var isExpanded = true

    private struct IdentityGroup: Identifiable {
        var id: String { identity }
        var identity: String
        var wins: Int
        var habits: Int
        var todayWins: Int
    }

    private var groups: [IdentityGroup] {
        var byIdentity: [String: [Habit]] = [:]
        for habit in store.habits {
            let key = habit.identityStatement.trimmingCharacters(in: .whitespacesAndNewlines)
            byIdentity[key.isEmpty ? "Cast your first win — set an identity" : key, default: []].append(habit)
        }
        return byIdentity.map { key, habits in
            IdentityGroup(
                identity: key,
                wins: habits.reduce(0) { $0 + $1.checkinDates.count },
                habits: habits.count,
                todayWins: habits.filter { $0.isChecked(on: dayString) }.count
            )
        }
        .sorted { $0.wins > $1.wins }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Who I'm Becoming")
                            .font(.title3).bold()
                            .foregroundStyle(AHColor.graphite)
                        Text("IDENTITY WINS")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(AHColor.champagne)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).bold()
                        .foregroundStyle(AHColor.graphiteSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse Who I'm Becoming" : "Expand Who I'm Becoming")
            if isExpanded {
            ForEach(groups) { group in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(AHColor.champagne)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.identity)
                            .font(.subheadline).bold()
                            .foregroundStyle(AHColor.graphite)
                        Text("\(group.habits) habit(s) · \(group.todayWins) win(s) \(dayName)")
                            .font(AHFont.caption)
                            .foregroundStyle(AHColor.graphiteSecondary)
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("\(group.wins)")
                            .font(AHFont.metric)
                            .foregroundStyle(AHColor.champagne)
                        Text("wins")
                            .font(AHFont.caption)
                            .foregroundStyle(AHColor.graphiteSecondary)
                    }
                }
                if group.id != groups.last?.id {
                    Divider().overlay(AHColor.hairline)
                }
            }
            }
        }
        .ahCard()
    }
}
