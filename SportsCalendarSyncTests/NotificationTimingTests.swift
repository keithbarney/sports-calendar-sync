import BackgroundTasks
import SwiftData
import UserNotifications
import XCTest
@testable import SportsCalendarSync

@MainActor
final class NotificationTimingTests: XCTestCase {
    private let identifier = "game-travel-team-travel-fixture"
    private let mexico = TimeZone(identifier: "America/Mexico_City")!
    private let wisconsin = TimeZone(identifier: "America/Chicago")!

    private func futureKickoff(month: Int = 9, day: Int = 16, hour: Int = 19, second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let year = calendar.component(.year, from: Date()) + 1
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, second: second))!
    }

    private func fixture(kickoff: Date, status: String? = nil) -> FixtureSnapshot {
        FixtureSnapshot(espnEventId: "travel-fixture", followedTeamId: "travel-team", leagueSlug: "eng.league_cup",
                        homeTeamName: "Home", homeTeamLogo: nil, awayTeamName: "Away", awayTeamLogo: nil,
                        kickoff: kickoff, venue: nil, broadcasts: [], status: status)
    }

    private func legacyRequest(kickoff: Date) -> UNNotificationRequest {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = mexico
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute],
                                                 from: kickoff.addingTimeInterval(-1800))
        return UNNotificationRequest(identifier: identifier, content: UNMutableNotificationContent(),
                                     trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
    }

    private func schedule(_ service: NotificationService, kickoff: Date,
                          reminder: KickoffReminder = .thirtyMin) async -> NotificationWriteResult {
        await service.reconcileGameNotification(homeTeam: "Home", awayTeam: "Away", leagueName: "Carabao Cup",
                                                kickoff: kickoff, followedTeamId: "travel-team",
                                                espnEventId: "travel-fixture", reminder: reminder)
    }

    func testMexicoToWisconsinTravelKeepsThirtyMinuteReminder() async throws {
        let originalZone = NSTimeZone.default
        defer { NSTimeZone.default = originalZone }
        let kickoff = futureKickoff()
        NSTimeZone.default = mexico
        let legacy = try XCTUnwrap(legacyRequest(kickoff: kickoff).trigger as? UNCalendarNotificationTrigger)
        let center = TimingNotificationCenter()
        let service = NotificationService(mutationCenter: center, checkAuthorizationOnInit: false)
        service.isAuthorized = true
        let result = await schedule(service, kickoff: kickoff)
        XCTAssertTrue(result.succeeded)
        let fixed = try XCTUnwrap(center.pending[identifier]?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(fixed.nextTriggerDate(), kickoff.addingTimeInterval(-1800))

        NSTimeZone.default = wisconsin
        // Reproduce the reported 90-minute alert with the former implementation.
        XCTAssertEqual(legacy.nextTriggerDate(), kickoff.addingTimeInterval(-5400))
        XCTAssertEqual(fixed.nextTriggerDate(), kickoff.addingTimeInterval(-1800))
        NSTimeZone.default = TimeZone(identifier: "Europe/Berlin")!
        XCTAssertEqual(fixed.nextTriggerDate(), kickoff.addingTimeInterval(-1800))
    }

    func testEveryReminderPreservesInstantAcrossYearBoundaryAndTravel() async throws {
        let originalZone = NSTimeZone.default
        defer { NSTimeZone.default = originalZone }
        let kickoff = futureKickoff(month: 1, day: 1, hour: 0, second: 37)
        let center = TimingNotificationCenter()
        let service = NotificationService(mutationCenter: center, checkAuthorizationOnInit: false)
        service.isAuthorized = true
        for reminder in KickoffReminder.allCases where reminder != .off {
            NSTimeZone.default = mexico
            let result = await schedule(service, kickoff: kickoff, reminder: reminder)
            XCTAssertTrue(result.succeeded)
            let trigger = try XCTUnwrap(center.pending[identifier]?.trigger as? UNCalendarNotificationTrigger)
            for zone in [wisconsin, TimeZone(identifier: "Europe/Berlin")!, TimeZone(identifier: "Pacific/Auckland")!] {
                NSTimeZone.default = zone
                XCTAssertEqual(trigger.nextTriggerDate(), kickoff.addingTimeInterval(reminder.offsetSeconds!))
            }
        }
    }

    func testDayBeforeReminderSpansDaylightSavingTransitionAsTwentyFourHours() async throws {
        let originalZone = NSTimeZone.default
        defer { NSTimeZone.default = originalZone }
        NSTimeZone.default = wisconsin
        let center = TimingNotificationCenter()
        let service = NotificationService(mutationCenter: center, checkAuthorizationOnInit: false)
        service.isAuthorized = true
        // Find the first Sunday in November, after Wisconsin's autumn clock change.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = wisconsin
        let kickoff = try XCTUnwrap(calendar.nextDate(after: futureKickoff(month: 10, day: 31),
                                                      matching: DateComponents(hour: 3, weekday: 1),
                                                      matchingPolicy: .nextTime))
        XCTAssertNotEqual(wisconsin.secondsFromGMT(for: kickoff),
                          wisconsin.secondsFromGMT(for: kickoff.addingTimeInterval(-86400)))
        let result = await schedule(service, kickoff: kickoff, reminder: .dayBefore)
        XCTAssertTrue(result.succeeded)
        let trigger = try XCTUnwrap(center.pending[identifier]?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.nextTriggerDate(), kickoff.addingTimeInterval(-86400))
    }

    func testLegacyRepairUsesStoredKickoffAndIsIdempotent() async throws {
        let originalZone = NSTimeZone.default
        defer { NSTimeZone.default = originalZone }
        NSTimeZone.default = wisconsin
        let kickoff = futureKickoff()
        let center = TimingNotificationCenter()
        center.pending[identifier] = legacyRequest(kickoff: kickoff)
        center.pending["test-unrelated"] = UNNotificationRequest(identifier: "test-unrelated",
            content: UNMutableNotificationContent(), trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false))
        let service = NotificationService(mutationCenter: center, checkAuthorizationOnInit: false)
        service.isAuthorized = true
        let result = await service.repairLegacyGameNotifications(fixtures: [fixture(kickoff: kickoff)], reminder: .thirtyMin)
        XCTAssertTrue(result.succeeded)
        let trigger = try XCTUnwrap(center.pending[identifier]?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.nextTriggerDate(), kickoff.addingTimeInterval(-1800))
        XCTAssertNotNil(center.pending["test-unrelated"])
        _ = await service.repairLegacyGameNotifications(fixtures: [fixture(kickoff: kickoff)], reminder: .thirtyMin)
        XCTAssertEqual(center.addCount, 1)
    }

    func testLegacyRepairFailureRemainsRetryable() async throws {
        let kickoff = futureKickoff()
        let center = TimingNotificationCenter()
        center.pending[identifier] = legacyRequest(kickoff: kickoff)
        center.failAdds = true
        let service = NotificationService(mutationCenter: center, checkAuthorizationOnInit: false)
        service.isAuthorized = true
        let failed = await service.repairLegacyGameNotifications(fixtures: [fixture(kickoff: kickoff)], reminder: .thirtyMin)
        XCTAssertFalse(failed.succeeded)
        XCTAssertNotNil(failed.errorMessage)
        XCTAssertNil((center.pending[identifier]?.trigger as? UNCalendarNotificationTrigger)?.dateComponents.timeZone)
        center.failAdds = false
        let retry = await service.repairLegacyGameNotifications(fixtures: [fixture(kickoff: kickoff)], reminder: .thirtyMin)
        XCTAssertTrue(retry.succeeded)
        XCTAssertNotNil((center.pending[identifier]?.trigger as? UNCalendarNotificationTrigger)?.dateComponents.timeZone)
    }

    func testLegacyRepairRemovesOffCancelledPostponedAndPastAlerts() async {
        let center = TimingNotificationCenter()
        let service = NotificationService(mutationCenter: center, checkAuthorizationOnInit: false)
        service.isAuthorized = true
        for (game, reminder) in [(fixture(kickoff: futureKickoff()), KickoffReminder.off),
                                 (fixture(kickoff: futureKickoff(), status: "STATUS_POSTPONED"), .thirtyMin),
                                 (fixture(kickoff: futureKickoff(), status: "STATUS_CANCELED"), .thirtyMin),
                                 (fixture(kickoff: Date().addingTimeInterval(-3600)), .thirtyMin)] {
            center.pending[identifier] = legacyRequest(kickoff: game.kickoff)
            let result = await service.repairLegacyGameNotifications(fixtures: [game], reminder: reminder)
            XCTAssertTrue(result.succeeded)
            XCTAssertNil(center.pending[identifier])
        }
        XCTAssertEqual(center.addCount, 0)
    }

    func testForegroundRepairsWithoutWaitingForFixtureRefreshOrCalendarAccess() async throws {
        let suite = "NotificationTimingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "fixtureCrestFormatV1RefreshAttempted")
        let schema = Schema([TrackedTeam.self, TrackedGame.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let kickoff = futureKickoff()
        container.mainContext.insert(TrackedGame(espnEventId: "travel-fixture", followedTeamId: "travel-team",
            leagueSlug: "eng.league_cup", homeTeamName: "Home", awayTeamName: "Away", kickoff: kickoff))
        try container.mainContext.save()
        let center = TimingNotificationCenter()
        center.pending[identifier] = legacyRequest(kickoff: kickoff)
        let service = NotificationService(mutationCenter: center, checkAuthorizationOnInit: false)
        XCTAssertFalse(service.isAuthorized)
        let health = SyncHealthStore(defaults: defaults)
        health.recordAttempt(at: Date())
        let refresh = AutomaticRefreshService(teamManager: TeamManager(preferences: defaults), espn: ESPNService(),
            calendar: TimingCalendarService(), notifications: service, modelContainer: container,
            health: health, scheduler: TimingBackgroundScheduler(), preferences: defaults)
        let result = await refresh.refreshIfNeeded(trigger: .foreground)
        XCTAssertNil(result, "The fixture fetch remains throttled")
        XCTAssertTrue(service.isAuthorized, "Repair must await the initial permission check")
        XCTAssertNil(health.lastSuccessfulSync, "Local repair must not claim a fresh schedule fetch")
        XCTAssertEqual(center.addCount, 1)
        let trigger = try XCTUnwrap(center.pending[identifier]?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.nextTriggerDate(), kickoff.addingTimeInterval(-1800))
    }

    func testMockModeAndDeniedPermissionDoNotRepairPendingNotifications() async {
        let center = TimingNotificationCenter()
        center.pending[identifier] = legacyRequest(kickoff: futureKickoff())
        let service = NotificationService(mutationCenter: center, checkAuthorizationOnInit: false)
        _ = await service.repairLegacyGameNotifications(fixtures: [fixture(kickoff: futureKickoff())], reminder: .thirtyMin)
        service.isAuthorized = true
        let originalArguments = ScreenshotFixtures.argumentsForTesting
        defer { ScreenshotFixtures.argumentsForTesting = originalArguments }
        ScreenshotFixtures.argumentsForTesting = ["-mock-data"]
        _ = await service.repairLegacyGameNotifications(fixtures: [fixture(kickoff: futureKickoff())], reminder: .thirtyMin)
        XCTAssertEqual(center.pendingReadCount, 0)
        XCTAssertEqual(center.addCount, 0)
        XCTAssertNotNil(center.pending[identifier])
    }
}

@MainActor
private final class TimingNotificationCenter: NotificationCenterMutationHandling {
    var pending: [String: UNNotificationRequest] = [:]
    var addCount = 0
    var pendingReadCount = 0
    var failAdds = false
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func add(_ request: UNNotificationRequest) async -> Error? {
        addCount += 1
        if failAdds { return NSError(domain: "NotificationTimingTests", code: 1) }
        pending[request.identifier] = request
        return nil
    }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        for id in identifiers { pending.removeValue(forKey: id) }
    }
    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingReadCount += 1
        return Array(pending.values)
    }
}

@MainActor
private final class TimingCalendarService: CalendarService {
    override func checkAuthorization() { isAuthorized = false }
}

private final class TimingBackgroundScheduler: BackgroundRefreshScheduling {
    func register(identifier: String, handler: @escaping (BGTask) -> Void) -> Bool { true }
    func replaceRequest(identifier: String, earliestBeginDate: Date) throws {}
}
