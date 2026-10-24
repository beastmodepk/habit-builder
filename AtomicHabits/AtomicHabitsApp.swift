import SwiftUI

@main
struct AtomicHabitsApp: App {
    @StateObject private var store = HabitStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
