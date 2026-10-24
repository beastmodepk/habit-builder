import SwiftUI

/// Identity board (Craving — identity-based habits): votes grouped by the
/// identity each habit votes for. "Every action you take is a vote for the
/// type of person you wish to become."
struct IdentityBoardView: View {
    @EnvironmentObject var store: HabitStore

    private struct IdentityGroup: Identifiable {
        var id: String { identity }
        var identity: String
        var votes: Int
        var habits: Int
        var todayVotes: Int
    }

    private var groups: [IdentityGroup] {
        var byIdentity: [String: [Habit]] = [:]
        for habit in store.habits {
            let key = habit.identityStatement.trimmingCharacters(in: .whitespacesAndNewlines)
            byIdentity[key.isEmpty ? "Cast a vote — set an identity" : key, default: []].append(habit)
        }
        return byIdentity.map { key, habits in
            IdentityGroup(
                identity: key,
                votes: habits.reduce(0) { $0 + $1.checkinDates.count },
                habits: habits.count,
                todayVotes: habits.filter { $0.isChecked(on: DayHelper.todayString()) }.count
            )
        }
        .sorted { $0.votes > $1.votes }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AHSectionHeader(title: "Who I'm Becoming", systemImage: "person.crop.circle.badge.checkmark",
                            color: AHColor.champagne)
            ForEach(groups) { group in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(AHColor.champagne)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.identity)
                            .font(.subheadline).bold()
                            .foregroundStyle(AHColor.graphite)
                        Text("\(group.habits) habit(s) · \(group.todayVotes) vote(s) today")
                            .font(AHFont.caption)
                            .foregroundStyle(AHColor.graphiteSecondary)
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("\(group.votes)")
                            .font(AHFont.metric)
                            .foregroundStyle(AHColor.champagne)
                        Text("votes")
                            .font(AHFont.caption)
                            .foregroundStyle(AHColor.graphiteSecondary)
                    }
                }
                if group.id != groups.last?.id {
                    Divider().overlay(AHColor.hairline)
                }
            }
        }
        .ahCard()
    }
}
