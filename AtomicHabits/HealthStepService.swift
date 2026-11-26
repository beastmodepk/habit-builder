import Foundation
import Combine
import HealthKit

/// Which step source inside Apple Health counts toward the goal.
enum StepSourcePreference: String, CaseIterable, Identifiable {
    case total
    case whoop
    case appleDevices

    var id: String { rawValue }

    var title: String {
        switch self {
        case .total: return "Apple Health total"
        case .whoop: return "WHOOP only"
        case .appleDevices: return "iPhone & Watch"
        }
    }

    /// Label shown on the habit card ("… steps · via X").
    var progressLabel: String {
        switch self {
        case .total: return "Apple Health"
        case .whoop: return "WHOOP in Apple Health"
        case .appleDevices: return "iPhone & Watch"
        }
    }
}

enum HealthAuthorizationState: Equatable {
    case notDetermined
    case authorized
    case denied
    case unavailable
}

/// Apple Health step sync (batch item 6): Apple Health is the hub —
/// WHOOP, Apple Watch, iPhone and every other app that shares steps
/// with Apple Health flow through this one read-only connection. No
/// server, no per-vendor integration; health data never leaves the
/// phone beyond what Apple Health already holds.
///
/// Read-only `stepCount` only. Per-day totals are queried explicitly,
/// so the day pager can show any day's real total and a late sync from
/// a source app backfills past days.
@MainActor
final class HealthStepService: ObservableObject {
    @Published private(set) var authorizationState: HealthAuthorizationState = .notDetermined
    @Published private(set) var stepsByDay: [String: Int] = [:]
    @Published var sourcePreference: StepSourcePreference {
        didSet {
            UserDefaults.standard.set(sourcePreference.rawValue, forKey: Self.preferenceKey)
            let days = Array(stepsByDay.keys)
            if !days.isEmpty {
                Task { await refresh(days: days) }
            }
        }
    }

    private static let preferenceKey = "stepSourcePreference"
    private let healthStore = HKHealthStore()
    private var allSources: [HKSource]? = nil
    private var observerQuery: HKObserverQuery? = nil

    private var stepType: HKQuantityType { HKQuantityType(.stepCount) }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.preferenceKey)
        sourcePreference = StepSourcePreference(rawValue: raw ?? "") ?? .total
        if !HKHealthStore.isHealthDataAvailable() {
            authorizationState = .unavailable
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            return
        }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepType])
            // Apple never reveals read-permission status directly; the
            // sharing status is the only signal available.
            authorizationState = healthStore.authorizationStatus(for: stepType) == .sharingDenied
                ? .denied : .authorized
            enableBackgroundUpdates()
            await refresh(days: [DayHelper.todayString(), DayHelper.string(daysAgo: 1)])
        } catch {
            authorizationState = .denied
        }
    }

    // MARK: - Queries

    /// Refresh the cached totals for the given "yyyy-MM-dd" days.
    func refresh(days: [String]) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        for day in days {
            stepsByDay[day] = await steps(on: day)
        }
    }

    private func steps(on day: String) async -> Int {
        guard let start = DayHelper.date(fromDayString: day),
              let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return 0 }
        var predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])
        if sourcePreference != .total {
            let sources = await filteredSources()
            guard !sources.isEmpty else { return 0 }
            let sourcePredicate = HKQuery.predicateForObjects(from: Set(sources))
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, sourcePredicate])
        }
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                continuation.resume(returning: Int(value))
            }
            healthStore.execute(query)
        }
    }

    /// Sources matching the current preference, from a cached
    /// HKSourceQuery over every source that has ever written steps.
    private func filteredSources() async -> [HKSource] {
        if allSources == nil {
            allSources = await loadSources()
        }
        let sources = allSources ?? []
        switch sourcePreference {
        case .total:
            return sources
        case .whoop:
            return sources.filter {
                $0.name.lowercased().contains("whoop")
                    || $0.bundleIdentifier.lowercased().contains("whoop")
            }
        case .appleDevices:
            return sources.filter {
                let name = $0.name.lowercased()
                return name.contains("iphone") || name.contains("apple watch")
            }
        }
    }

    private func loadSources() async -> [HKSource] {
        await withCheckedContinuation { continuation in
            let query = HKSourceQuery(sampleType: stepType, samplePredicate: nil) { _, sources, _ in
                continuation.resume(returning: Array(sources ?? []))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Background updates

    /// Hourly background delivery + an observer query, so a late sync
    /// from a source app (e.g. WHOOP) refreshes today/yesterday without
    /// the user opening the app first.
    private func enableBackgroundUpdates() {
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .hourly) { _, _ in }
        guard observerQuery == nil else { return }
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, _ in
            guard let self else {
                completionHandler()
                return
            }
            Task { @MainActor in
                await self.refresh(days: [DayHelper.todayString(), DayHelper.string(daysAgo: 1)])
                completionHandler()
            }
        }
        observerQuery = query
        healthStore.execute(query)
    }
}
