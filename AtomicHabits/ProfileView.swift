import SwiftUI
import UIKit

/// A Profile section that folds away under its heading — tap to toggle,
/// open/closed remembered per section (same pattern as the Who I'm
/// Becoming board).
struct CollapsibleProfileSection<Content: View>: View {
    let title: String
    var systemImage: String? = nil
    @AppStorage private var isExpanded: Bool
    @ViewBuilder let content: Content

    init(key: String, title: String, systemImage: String? = nil,
         startsExpanded: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self._isExpanded = AppStorage(wrappedValue: startsExpanded, "profileSection_\(key)")
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    AHSectionHeader(title: title, systemImage: systemImage, color: AHColor.champagne)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).bold()
                        .foregroundStyle(AHColor.graphiteSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse \(title)" : "Expand \(title)")
            if isExpanded {
                content
            }
        }
    }
}

/// Profile tab: who you are, what you've earned (Accomplishments), your
/// connections (added by their own commits), and settings.
struct ProfileView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.openURL) private var openURL

    private var displayName: String {
        store.userName.isEmpty ? "You" : store.userName
    }

    private var initials: String {
        let parts = store.userName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map { String($0) }
        return letters.isEmpty ? "Y" : letters.joined().uppercased()
    }

    private var buildingSince: String {
        let earliest = store.habits.map { $0.createdAt }.min() ?? Date()
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: earliest)
    }

    private var allTimeWins: Int {
        store.habits.reduce(0) { $0 + $1.checkinDates.count }
    }

    private var currentStreak: Int {
        store.habits.map { DayHelper.streak(for: $0) }.max() ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                CollapsibleProfileSection(key: "accomplishments", title: "Accomplishments",
                                          systemImage: "medal.fill") {
                    AccomplishmentsSectionView()
                }
                CollapsibleProfileSection(key: "connectedHealth", title: "Connected Health",
                                          systemImage: "heart.fill") {
                    ConnectedHealthSectionView()
                }
                CollapsibleProfileSection(key: "reading", title: "Reading",
                                          systemImage: "book.fill") {
                    ReadingSectionView()
                }
                settingsSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AHColor.background.ignoresSafeArea())
        .navigationTitle("Profile")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Text(initials)
                .font(.title3).bold()
                .foregroundStyle(AHColor.graphite)
                .frame(width: 56, height: 56)
                .background(Circle().fill(AHColor.champagne.opacity(0.18)))
                .overlay(Circle().strokeBorder(AHColor.champagne.opacity(0.4), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.title3).bold()
                    .foregroundStyle(AHColor.graphite)
                Text("Building since \(buildingSince)")
                    .font(.subheadline)
                    .foregroundStyle(AHColor.graphiteSecondary)
                Text("\(allTimeWins) all-time wins · \(currentStreak)-day streak")
                    .font(.footnote).bold()
                    .foregroundStyle(AHColor.champagne)
            }
            Spacer(minLength: 0)
        }
        .ahCard(padding: 16)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AHSectionHeader(title: "Settings", systemImage: "gearshape.fill", color: AHColor.champagne)
            VStack(spacing: 0) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    settingsRowLabel(icon: "bell.fill", title: "Notifications",
                                     detail: "Open iOS Settings")
                }
                .buttonStyle(.plain)
                Divider().overlay(AHColor.hairline).padding(.leading, 46)
                NavigationLink {
                    WidgetsInfoView()
                } label: {
                    settingsRowLabel(icon: "square.grid.2x2.fill", title: "Widgets", detail: nil)
                }
                .buttonStyle(.plain)
                Divider().overlay(AHColor.hairline).padding(.leading, 46)
                NavigationLink {
                    CheatDaysView()
                } label: {
                    settingsRowLabel(icon: "calendar.badge.exclamationmark", title: "Cheat days", detail: nil)
                }
                .buttonStyle(.plain)
                Divider().overlay(AHColor.hairline).padding(.leading, 46)
                NavigationLink {
                    AboutView()
                } label: {
                    settingsRowLabel(icon: "info.circle.fill", title: "About", detail: nil)
                }
                .buttonStyle(.plain)
            }
            .ahCard(padding: 6)
        }
    }

    private func settingsRowLabel(icon: String, title: String, detail: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AHColor.champagne)
                .frame(width: 22)
            Text(title)
                .font(AHFont.cardTitle)
                .foregroundStyle(AHColor.graphite)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(AHColor.graphiteSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption).bold()
                .foregroundStyle(AHColor.graphiteSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Accomplishments section

struct AccomplishmentsSectionView: View {
    @EnvironmentObject var store: HabitStore

    private var badges: [AccomplishmentBadge] {
        Accomplishments.evaluate(habits: store.habits)
    }

    private var latest: AccomplishmentBadge? {
        badges.filter { $0.earned }
            .max { ($0.earnedDate ?? .distantPast) < ($1.earnedDate ?? .distantPast) }
    }

    private var next: AccomplishmentBadge? {
        badges.filter { !$0.earned }.max { $0.ratio < $1.ratio }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let latest {
                HStack(spacing: 12) {
                    Image(systemName: latest.systemImage)
                        .font(.title3)
                        .foregroundStyle(AHColor.graphite)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(AHColor.champagne))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LATEST — \(latest.title.uppercased())")
                            .font(.subheadline).bold()
                            .foregroundStyle(AHColor.champagne)
                        if let date = latest.earnedDate {
                            Text("Earned \(earnedText(date))")
                                .font(.footnote)
                                .foregroundStyle(AHColor.graphiteSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
            } else {
                Text("No badges yet — your first win earns First Win.")
                    .font(.subheadline)
                    .foregroundStyle(AHColor.graphiteSecondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                      spacing: 14) {
                ForEach(Array(badges.prefix(4))) { badge in
                    badgeCell(badge)
                }
            }

            if let next {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Next: \(next.title)")
                            .font(.footnote).bold()
                            .foregroundStyle(AHColor.graphite)
                        Spacer()
                        Text("\(next.progress) / \(next.target)")
                            .font(.footnote)
                            .foregroundStyle(AHColor.graphiteSecondary)
                    }
                    ProgressView(value: next.ratio)
                        .tint(AHColor.champagne)
                }
            }

            HStack {
                Spacer()
                NavigationLink {
                    AccomplishmentsAllView()
                } label: {
                    Text("See all")
                        .font(.subheadline).bold()
                        .foregroundStyle(AHColor.champagne)
                }
                .buttonStyle(.plain)
            }
        }
        .ahCard()
    }

    private func badgeCell(_ badge: AccomplishmentBadge) -> some View {
        VStack(spacing: 6) {
            Image(systemName: badge.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(badge.earned ? AHColor.graphite : AHColor.graphiteSecondary.opacity(0.6))
                .frame(width: 46, height: 46)
                .background(Circle().fill(badge.earned ? AHColor.champagne : AHColor.hairline.opacity(0.5)))
            Text(badge.title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(badge.earned ? AHColor.graphite : AHColor.graphiteSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    private func earnedText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}

/// Every badge with its progress — the "See all" destination.
struct AccomplishmentsAllView: View {
    @EnvironmentObject var store: HabitStore

    private var badges: [AccomplishmentBadge] {
        Accomplishments.evaluate(habits: store.habits)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(badges) { badge in
                    HStack(spacing: 12) {
                        Image(systemName: badge.systemImage)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(badge.earned ? AHColor.graphite : AHColor.graphiteSecondary.opacity(0.6))
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(badge.earned ? AHColor.champagne : AHColor.hairline.opacity(0.5)))
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(badge.title)
                                    .font(AHFont.cardTitle)
                                    .foregroundStyle(AHColor.graphite)
                                Spacer()
                                if badge.earned, let date = badge.earnedDate {
                                    Text("Earned \(shortDate(date))")
                                        .font(.footnote).bold()
                                        .foregroundStyle(AHColor.champagne)
                                } else {
                                    Text("\(badge.progress) / \(badge.target)")
                                        .font(.footnote)
                                        .foregroundStyle(AHColor.graphiteSecondary)
                                }
                            }
                            ProgressView(value: badge.ratio)
                                .tint(AHColor.champagne)
                        }
                    }
                    .ahCard(padding: 14)
                }
                Text("Badges award themselves the moment your history earns them — there is nothing to claim.")
                    .font(.footnote)
                    .foregroundStyle(AHColor.graphiteSecondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AHColor.background.ignoresSafeArea())
        .navigationTitle("Accomplishments")
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

// MARK: - Connected Health section

struct ConnectedHealthSectionView: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var healthService: HealthStepService

    private var linkedHabit: Habit? {
        store.habits.first { $0.healthGoal > 0 && !$0.healthMetric.isEmpty }
    }

    private var stepsCandidate: Habit? {
        store.habits.first { $0.title == "10,000 steps" }
    }

    private var statusText: String {
        switch healthService.authorizationState {
        case .authorized: return "Connected"
        case .denied: return "No access"
        case .unavailable: return "Unavailable"
        case .notDetermined: return "Not connected"
        }
    }

    private var sourceBinding: Binding<StepSourcePreference> {
        Binding(get: { healthService.sourcePreference },
                set: { healthService.sourcePreference = $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Apple Health")
                    .font(AHFont.cardTitle)
                    .foregroundStyle(AHColor.graphite)
                Spacer()
                Text(statusText)
                    .font(.subheadline).bold()
                    .foregroundStyle(healthService.authorizationState == .authorized ? AHColor.build : AHColor.graphiteSecondary)
            }
            if healthService.authorizationState != .authorized {
                Button("Connect Apple Health") {
                    Task { await healthService.requestAuthorization() }
                }
                .buttonStyle(.borderedProminent)
                .tint(AHColor.build)
                Text("Read-only: Habit Builder reads just your step count — from WHOOP, Apple Watch, iPhone, or any app that shares steps with Apple Health — to update your steps habit. Nothing leaves your phone.")
                    .font(.footnote)
                    .foregroundStyle(AHColor.graphiteSecondary)
            }
            HStack {
                Text("Steps source")
                    .font(.subheadline)
                    .foregroundStyle(AHColor.graphite)
                Spacer()
                Picker("Steps source", selection: sourceBinding) {
                    ForEach(StepSourcePreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .pickerStyle(.menu)
                .tint(AHColor.champagne)
            }
            if let linked = linkedHabit {
                let todaySteps = healthService.stepsByDay[DayHelper.todayString()] ?? 0
                Text("\(linked.title): \(todaySteps.formatted()) / \(linked.healthGoal.formatted()) steps today")
                    .font(.footnote).bold()
                    .foregroundStyle(AHColor.champagne)
            } else if let candidate = stepsCandidate {
                Button("Link \u{201C}10,000 steps\u{201D} to Apple Health") {
                    var habit = candidate
                    habit.healthMetric = "stepCount"
                    habit.healthGoal = 10000
                    store.update(habit)
                    Task { await healthService.refresh(days: [DayHelper.todayString()]) }
                }
                .buttonStyle(.bordered)
                .tint(AHColor.champagne)
                Text("Your steps habit isn't linked yet. Linking is explicit — it never happens by title alone.")
                    .font(.footnote)
                    .foregroundStyle(AHColor.graphiteSecondary)
            } else {
                Text("No steps habit yet — add one and link it here so its win lands automatically at goal.")
                    .font(.footnote)
                    .foregroundStyle(AHColor.graphiteSecondary)
            }
        }
        .ahCard()
        .task {
            await healthService.refresh(days: [DayHelper.todayString()])
        }
    }
}

// MARK: - Reading section

struct ReadingSectionView: View {
    /// Global default reading app, shared with the habit cards.
    @AppStorage("readingAppPreference") private var readingAppPreference = "kindle"
    @Environment(\.openURL) private var openURL

    private var selectedApp: ReadingApp {
        ReadingApp(rawValue: readingAppPreference) ?? .kindle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reading app")
                    .font(AHFont.cardTitle)
                    .foregroundStyle(AHColor.graphite)
                Spacer()
                Picker("Reading app", selection: $readingAppPreference) {
                    ForEach(ReadingApp.allCases) { app in
                        Text(app.displayName).tag(app.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .tint(AHColor.champagne)
            }
            if selectedApp != .none, let url = selectedApp.openURL {
                Button(selectedApp.openLabel) {
                    openURL(url)
                }
                .buttonStyle(.bordered)
                .tint(AHColor.champagne)
                Text("Opens your \(selectedApp.displayName) library — pick your book there and it opens where you left off.")
                    .font(.footnote)
                    .foregroundStyle(AHColor.graphiteSecondary)
                Text("Reading progress — manual Win (\(selectedApp.displayName) shares no data)")
                    .font(.footnote)
                    .foregroundStyle(AHColor.graphiteSecondary)
            } else {
                Text("Reading progress — manual Win")
                    .font(.footnote)
                    .foregroundStyle(AHColor.graphiteSecondary)
            }
        }
        .ahCard()
    }
}

// MARK: - Settings destinations

struct WidgetsInfoView: View {
    private let widgets: [(name: String, detail: String)] = [
        ("Today's Wins", "Small — your wins ring and the next habit cue."),
        ("Check In", "Medium — tick today's habits without opening the app."),
        ("Week Chain", "Large — the week's heatmap and every streak at a glance."),
        ("Clean Streak", "Lock Screen — your clean-day streak; tap for the urge timer."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(widgets, id: \.name) { widget in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(widget.name)
                            .font(AHFont.cardTitle)
                            .foregroundStyle(AHColor.graphite)
                        Text(widget.detail)
                            .font(.subheadline)
                            .foregroundStyle(AHColor.graphiteSecondary)
                    }
                }
                Divider().overlay(AHColor.hairline)
                Text("To add one: long-press your Home Screen, tap +, search “Habit Builder”, pick a size, and tap Add Widget. The Lock Screen widget lives under Settings → Wallpaper, or long-press the Lock Screen and tap Customise.")
                    .font(.subheadline)
                    .foregroundStyle(AHColor.graphite)
            }
            .padding(18)
            .ahCard()
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .background(AHColor.background.ignoresSafeArea())
        .navigationTitle("Widgets")
    }
}

struct CheatDaysView: View {
    @EnvironmentObject var store: HabitStore

    private var quitHabits: [Habit] { store.habits.filter { $0.kind == .quit } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Cheat days belong to each quit habit's plan: a planned day off is part of the system, not a broken streak. Open a quit habit to review its contract and replacement.")
                    .font(.subheadline)
                    .foregroundStyle(AHColor.graphite)
                if quitHabits.isEmpty {
                    Text("No quit habits yet — cheat days appear here once you add one.")
                        .font(.subheadline)
                        .foregroundStyle(AHColor.graphiteSecondary)
                } else {
                    ForEach(quitHabits) { habit in
                        NavigationLink {
                            HabitDetailView(habitID: habit.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "shield.fill")
                                    .foregroundStyle(AHColor.quit)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(habit.title)
                                        .font(AHFont.cardTitle)
                                        .foregroundStyle(AHColor.graphite)
                                    Text("\(DayHelper.streak(for: habit)) clean days")
                                        .font(.footnote)
                                        .foregroundStyle(AHColor.graphiteSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption).bold()
                                    .foregroundStyle(AHColor.graphiteSecondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if habit.id != quitHabits.last?.id {
                            Divider().overlay(AHColor.hairline)
                        }
                    }
                }
            }
            .padding(18)
            .ahCard()
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .background(AHColor.background.ignoresSafeArea())
        .navigationTitle("Cheat days")
    }
}

struct AboutView: View {
    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(AHColor.champagne)
            Text("Habit Builder")
                .font(.title2).bold()
                .foregroundStyle(AHColor.graphite)
            Text(versionText)
                .font(.subheadline)
                .foregroundStyle(AHColor.graphiteSecondary)
            Text("Every win is a step toward the person you want to become.")
                .font(.footnote)
                .foregroundStyle(AHColor.champagne)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .padding(.top, 48)
        .frame(maxWidth: .infinity)
        .background(AHColor.background.ignoresSafeArea())
        .navigationTitle("About")
    }
}
