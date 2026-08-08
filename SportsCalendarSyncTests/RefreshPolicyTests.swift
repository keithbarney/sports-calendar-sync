import XCTest
@testable import SportsCalendarSync

final class RefreshPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFirstAutomaticRefreshRuns() {
        let policy = RefreshPolicy(minimumAutomaticInterval: 900, backgroundRefreshInterval: 21_600)

        XCTAssertTrue(policy.shouldRefresh(trigger: .launch, lastAttempt: nil, now: now))
        XCTAssertTrue(policy.shouldRefresh(trigger: .foreground, lastAttempt: nil, now: now))
    }

    func testRecentAutomaticAttemptIsThrottled() {
        let policy = RefreshPolicy(minimumAutomaticInterval: 900, backgroundRefreshInterval: 21_600)
        let recentAttempt = now.addingTimeInterval(-899)

        XCTAssertFalse(policy.shouldRefresh(trigger: .launch, lastAttempt: recentAttempt, now: now))
        XCTAssertFalse(policy.shouldRefresh(trigger: .foreground, lastAttempt: recentAttempt, now: now))
        XCTAssertFalse(policy.shouldRefresh(trigger: .background, lastAttempt: recentAttempt, now: now))
    }

    func testDueAutomaticAndManualRefreshRun() {
        let policy = RefreshPolicy(minimumAutomaticInterval: 900, backgroundRefreshInterval: 21_600)
        let oldAttempt = now.addingTimeInterval(-900)

        XCTAssertTrue(policy.shouldRefresh(trigger: .foreground, lastAttempt: oldAttempt, now: now))
        XCTAssertTrue(policy.shouldRefresh(trigger: .manual, lastAttempt: now, now: now))
        XCTAssertTrue(policy.shouldRefresh(trigger: .permissionGranted, lastAttempt: now, now: now))
    }

    func testBackgroundRequestUsesConfiguredEarliestDate() {
        let policy = RefreshPolicy(minimumAutomaticInterval: 900, backgroundRefreshInterval: 21_600)

        XCTAssertEqual(
            policy.nextBackgroundRefresh(after: now),
            now.addingTimeInterval(21_600)
        )
    }

    func testPendingCalendarWritesDoNotReportSuccessfulCalendarSync() {
        var result = SyncResult()
        result.teamsAttempted = 1
        result.teamsSucceeded = 1
        result.calendarWritesPending = 1

        XCTAssertFalse(result.isSuccessful)
    }
}
