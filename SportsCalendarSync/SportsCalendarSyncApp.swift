import SwiftUI
import SwiftData

@main
struct SportsCalendarSyncApp: App {
    @StateObject private var calendarService = CalendarService()
    @StateObject private var toastManager = ToastManager()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var teamManager = TeamManager()
    @StateObject private var espnService = ESPNService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TrackedTeam.self,
            TrackedGame.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(calendarService)
                .environmentObject(toastManager)
                .environmentObject(appSettings)
                .environmentObject(teamManager)
                .environmentObject(espnService)
                .toast(toastManager)
                #if DEBUG
                .task {
                    if CommandLine.arguments.contains("-seed-data") {
                        let context = sharedModelContainer.mainContext
                        await SeedData.populate(modelContext: context, espn: espnService)
                    }
                }
                #endif
        }
        .modelContainer(sharedModelContainer)
    }
}
