import SwiftUI

@main
struct AtomicHabitsApp: App {
    @StateObject private var store = HabitStore()
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(router)
                .task {
                    // Re-arm cue reminders for habits whose permission was
                    // already granted; never prompts on launch.
                    await AnchorNotifications.rescheduleAllIfAuthorized(store.habits)
                }
                .onOpenURL { url in
                    guard url.scheme == "atomichabits" else { return }
                    switch url.host {
                    case "urge-timer":
                        router.showTimer = true
                    case "sos":
                        router.showSOS = true
                    case "today":
                        router.showSOS = false
                        router.showTimer = false
                    default:
                        break
                    }
                }
        }
    }
}
