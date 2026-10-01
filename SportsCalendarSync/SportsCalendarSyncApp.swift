import SwiftUI
import SwiftData

@main
@MainActor
struct SportsCalendarSyncApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasStartedLaunchRefresh = false
    @StateObject private var calendarService: CalendarService
    @StateObject private var notificationService: NotificationService
    @StateObject private var toastManager: ToastManager
    @StateObject private var appSettings: AppSettings
    @StateObject private var teamManager: TeamManager
    @StateObject private var espnService: ESPNService
    @StateObject private var syncHealth: SyncHealthStore
    @StateObject private var automaticRefresh: AutomaticRefreshService

    let sharedModelContainer: ModelContainer

    init() {
        let container = Self.makeModelContainer()
        let calendar = CalendarService()
        let notifications = NotificationService()
        let teams = TeamManager()
        let espn = ESPNService()
        let health = SyncHealthStore()
        let refresh = AutomaticRefreshService(
            teamManager: teams,
            espn: espn,
            calendar: calendar,
            notifications: notifications,
            modelContainer: container,
            health: health
        )

        WidgetSnapshotPublisher.publish(context: container.mainContext)
        sharedModelContainer = container
        _calendarService = StateObject(wrappedValue: calendar)
        _notificationService = StateObject(wrappedValue: notifications)
        _toastManager = StateObject(wrappedValue: ToastManager())
        _appSettings = StateObject(wrappedValue: AppSettings())
        _teamManager = StateObject(wrappedValue: teams)
        _espnService = StateObject(wrappedValue: espn)
        _syncHealth = StateObject(wrappedValue: health)
        _automaticRefresh = StateObject(wrappedValue: refresh)
    }

    static func makeModelContainer(
        emptyScreenshotScenario: Bool? = nil,
        mockScenario: MockReviewScenario? = nil
    ) -> ModelContainer {
        let schema = Schema([
            TrackedTeam.self,
            TrackedGame.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: {
                #if DEBUG
                return ScreenshotFixtures.isEnabled
                #else
                return false
                #endif
            }(),
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            #if DEBUG
            if ScreenshotFixtures.isEnabled {
                ScreenshotFixtures.populate(
                    context: container.mainContext,
                    empty: emptyScreenshotScenario,
                    scenario: mockScenario
                )
            }
            #endif
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            appContent
                .modifier(FeedbackLifecycle())
                .preferredColorScheme(appSettings.appearanceMode.colorScheme)
                .environmentObject(calendarService)
                .environmentObject(notificationService)
                .environmentObject(toastManager)
                .environmentObject(appSettings)
                .environmentObject(teamManager)
                .environmentObject(espnService)
                .environmentObject(syncHealth)
                .environmentObject(automaticRefresh)
                .toast(toastManager)
                .task {
                    guard !isRunningTests,
                          scenePhase == .active,
                          !hasStartedLaunchRefresh else { return }
                    hasStartedLaunchRefresh = true
                    await performLaunchRefresh()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard !isRunningTests else { return }
                    switch phase {
                    case .active:
                        calendarService.checkAuthorization()
                        if hasStartedLaunchRefresh {
                            Task {
                                await automaticRefresh.refreshIfNeeded(trigger: .foreground)
                            }
                        } else {
                            hasStartedLaunchRefresh = true
                            Task { await performLaunchRefresh() }
                        }
                    case .background:
                        automaticRefresh.scheduleNextRefresh()
                    default:
                        break
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    @ViewBuilder
    private var appContent: some View {
        #if DEBUG
        if ScreenshotFixtures.isEnabled && !ScreenshotFixtures.isCapturing {
            MockReviewView(initialContainer: sharedModelContainer)
        } else {
            ContentView()
        }
        #else
        ContentView()
        #endif
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func performLaunchRefresh() async {
        #if DEBUG
        if ScreenshotFixtures.isEnabled {
            ScreenshotFixtures.populate(context: sharedModelContainer.mainContext)
            return
        }
        if CommandLine.arguments.contains("-seed-data") {
            let context = sharedModelContainer.mainContext
            await SeedData.populate(modelContext: context, espn: espnService)
        }
        #endif
        if !calendarService.isAuthorized {
            _ = await calendarService.requestAccess()
        }
        await automaticRefresh.refreshIfNeeded(trigger: .launch)
    }
}
