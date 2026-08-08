import XCTest
@testable import SportsCalendarSync

@MainActor
final class SyncHealthStoreTests: XCTestCase {
    func testRepairBannerIsDismissableAndSessionOnly() {
        let (health, defaults) = makeHealthStore()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        var result = successfulResult()
        result.calendarRepairs = 2

        health.recordCompletion(result, at: Date())

        XCTAssertEqual(health.calendarRepairBannerCount, 2)
        XCTAssertNil(SyncHealthStore(defaults: defaults).calendarRepairBannerCount)
        health.dismissCalendarRepairBanner()
        XCTAssertNil(health.calendarRepairBannerCount)
    }

    func testFailedSyncClearsPreviousRepairBanner() {
        let (health, defaults) = makeHealthStore()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        var successful = successfulResult()
        successful.calendarRepairs = 2
        health.recordCompletion(successful, at: Date())

        var failed = SyncResult()
        failed.teamsAttempted = 1
        failed.failures = ["LAFC: The fixture feed could not be reached."]
        health.recordCompletion(failed, at: Date())

        XCTAssertNil(health.calendarRepairBannerCount)
        XCTAssertNotNil(health.lastError)
    }

    func testTroubleshootingErrorsDoNotSurviveAppRelaunch() {
        let (health, defaults) = makeHealthStore()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        var result = SyncResult()
        result.teamsAttempted = 1
        result.failures = ["LAFC: The fixture feed could not be reached."]

        health.recordCompletion(result, at: Date())

        XCTAssertNotNil(health.lastError)
        XCTAssertNil(SyncHealthStore(defaults: defaults).lastError)
    }

    private var defaultsSuiteName: String { "SyncHealthStoreTests" }

    private func makeHealthStore() -> (SyncHealthStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        return (SyncHealthStore(defaults: defaults), defaults)
    }

    private func successfulResult() -> SyncResult {
        var result = SyncResult()
        result.teamsAttempted = 1
        result.teamsSucceeded = 1
        return result
    }
}
