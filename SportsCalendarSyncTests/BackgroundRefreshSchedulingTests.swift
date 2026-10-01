import BackgroundTasks
import SwiftData
import XCTest
@testable import SportsCalendarSync

@MainActor
final class BackgroundRefreshSchedulingTests: XCTestCase {
    func testSuccessfulSchedulingSubmitsAndPersistsEarliestDate() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let scheduler = FakeBackgroundScheduler()
        let (health, defaults) = makeHealthStore()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let scheduled = BackgroundRefreshRequestCoordinator.scheduleNext(
            identifier: "test.refresh",
            policy: RefreshPolicy(
                minimumAutomaticInterval: 900,
                backgroundRefreshInterval: 21_600
            ),
            scheduler: scheduler,
            health: health,
            now: now
        )

        XCTAssertEqual(scheduler.submittedIdentifier, "test.refresh")
        XCTAssertEqual(scheduler.submittedDate, now.addingTimeInterval(21_600))
        XCTAssertEqual(scheduled, scheduler.submittedDate)
        XCTAssertEqual(health.nextPlannedRefresh, scheduler.submittedDate)
        XCTAssertNil(health.backgroundSchedulingError)
    }

    func testSchedulingFailureLeavesNextDateUnknownAndRecordsGuidance() {
        let scheduler = FakeBackgroundScheduler()
        scheduler.submitError = TestError.failed
        let (health, defaults) = makeHealthStore()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let scheduled = BackgroundRefreshRequestCoordinator.scheduleNext(
            identifier: "test.refresh",
            policy: RefreshPolicy(),
            scheduler: scheduler,
            health: health,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertNil(scheduled)
        XCTAssertNil(health.nextPlannedRefresh)
        XCTAssertNotNil(health.backgroundSchedulingError)
    }

    func testServiceRegistersAndSchedulesBackgroundRefreshWhenEnabled() {
        let schema = Schema([TrackedTeam.self, TrackedGame.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let scheduler = FakeBackgroundScheduler()
        let (health, defaults) = makeHealthStore()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        let service = AutomaticRefreshService(
            teamManager: TeamManager(preferences: defaults),
            espn: ESPNService(),
            calendar: CalendarService(),
            notifications: NotificationService(),
            modelContainer: container,
            health: health,
            scheduler: scheduler,
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )

        XCTAssertEqual(scheduler.registeredIdentifier, AutomaticRefreshService.backgroundTaskIdentifier)
        service.scheduleNextRefresh()
        XCTAssertEqual(scheduler.submittedIdentifier, AutomaticRefreshService.backgroundTaskIdentifier)
        XCTAssertNotNil(health.nextPlannedRefresh)
    }

    private var defaultsSuiteName: String {
        "BackgroundRefreshSchedulingTests"
    }

    private func makeHealthStore() -> (SyncHealthStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        return (SyncHealthStore(defaults: defaults), defaults)
    }
}

private enum TestError: Error {
    case failed
}

private final class FakeBackgroundScheduler: BackgroundRefreshScheduling {
    var registeredIdentifier: String?
    var submittedIdentifier: String?
    var submittedDate: Date?
    var submitError: Error?

    func register(identifier: String, handler: @escaping (BGTask) -> Void) -> Bool {
        registeredIdentifier = identifier
        return true
    }

    func replaceRequest(identifier: String, earliestBeginDate: Date) throws {
        submittedIdentifier = identifier
        submittedDate = earliestBeginDate
        if let submitError { throw submitError }
    }
}
