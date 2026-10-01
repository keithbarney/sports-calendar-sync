import XCTest
import SwiftData
import SwiftUI
import UserNotifications
@testable import SportsCalendarSync

final class ScreenshotFixturesTests: XCTestCase {
    @MainActor
    func testCaptureStoreIsIsolatedAndScenariosReset() throws {
        ScreenshotFixtures.argumentsForTesting = ["-screenshot-fixtures", "-screenshot-date", "2026-09-10T00:00:00Z"]
        defer { ScreenshotFixtures.argumentsForTesting = nil }
        let first = SportsCalendarSyncApp.makeModelContainer()
        XCTAssertEqual(try first.mainContext.fetchCount(FetchDescriptor<TrackedTeam>()), 18)
        XCTAssertEqual(try first.mainContext.fetchCount(FetchDescriptor<TrackedGame>()), 24)
        let games = try first.mainContext.fetch(FetchDescriptor<TrackedGame>())
        XCTAssertTrue(games.allSatisfy { $0.venue != nil && !$0.broadcasts.isEmpty })
        ScreenshotFixtures.argumentsForTesting?.append("-screenshot-empty")
        let empty = SportsCalendarSyncApp.makeModelContainer()
        XCTAssertEqual(try empty.mainContext.fetchCount(FetchDescriptor<TrackedTeam>()), 0)
        XCTAssertEqual(try first.mainContext.fetchCount(FetchDescriptor<TrackedTeam>()), 18)
        ScreenshotFixtures.argumentsForTesting?.removeLast()
        let replay = SportsCalendarSyncApp.makeModelContainer()
        XCTAssertEqual(try replay.mainContext.fetch(FetchDescriptor<TrackedGame>()).map(\.kickoff).sorted(), games.map(\.kickoff).sorted())
    }

    @MainActor
    func testEveryCatalogClubHasDistinctBundledArtwork() throws {
        ScreenshotFixtures.argumentsForTesting = ["-screenshot-fixtures"]
        defer { ScreenshotFixtures.argumentsForTesting = nil }
        let container = SportsCalendarSyncApp.makeModelContainer()
        let followed = try container.mainContext.fetch(FetchDescriptor<TrackedTeam>())
        let catalog = Dictionary(ScreenshotFixtures.teams.values.flatMap { $0 }.map { ($0.id, $0) },
                                 uniquingKeysWith: { first, _ in first })
        XCTAssertEqual(Set(catalog.keys), ScreenshotFixtures.artworkIDs)
        XCTAssertEqual(catalog.count, 23)
        var rendered: Set<Data> = []
        for (id, club) in catalog {
            let reference = try XCTUnwrap(club.logos?.first?.href)
            let original = try XCTUnwrap(UIImage(named: "mock-crest-" + id), "Missing actual asset: \(id)")
            let loaded = try XCTUnwrap(ScreenshotFixtures.artwork(for: reference), id)
            XCTAssertEqual(loaded.pngData(), original.pngData(), "Generated badges are not real artwork")
            XCTAssertGreaterThan(loaded.size.width, 100)
            XCTAssertTrue(followed.filter { $0.espnId == id }.allSatisfy { $0.logoURL == reference })
            let renderer = ImageRenderer(content: CrestView(url: reference, size: 88))
            rendered.insert(try XCTUnwrap(renderer.uiImage?.pngData()))
        }
        XCTAssertEqual(rendered.count, 23)
        XCTAssertTrue(followed.allSatisfy { catalog[$0.espnId] != nil })
        XCTAssertNil(ScreenshotFixtures.artwork(for: "mock-crest://missing-club"))
        ScreenshotFixtures.argumentsForTesting = []
        XCTAssertNil(ScreenshotFixtures.artwork(for: "mock-crest://screenshot-united"))
    }

    @MainActor
    func testSecondDivisionFollowSyncsEverySelectedCompetitionAndRemainsIdempotent() async throws {
        ScreenshotFixtures.argumentsForTesting = ["-mock-data", "-mock-second-divisions", "-screenshot-empty"]
        defer { ScreenshotFixtures.argumentsForTesting = nil }
        let container = SportsCalendarSyncApp.makeModelContainer()
        let provider = ESPNService()
        let manager = TeamManager()
        let calendar = CalendarService()
        for (club, league) in [
            (ScreenshotFixtures.darmstadt, Competition.bundesliga2),
            (ScreenshotFixtures.norwich, .championship), (ScreenshotFixtures.almeria, .laLiga2),
            (ScreenshotFixtures.palermo, .serieB), (ScreenshotFixtures.saintEtienne, .ligue2)
        ] {
            let discovered = try await provider.getCompetitions(for: club, source: league)
            XCTAssertGreaterThan(discovered.competitions.count, 1)
            let result = await manager.followAcrossCompetitions(espnTeam: club, sourceCompetition: league,
                competitions: discovered.competitions, context: container.mainContext, espn: provider, calendar: calendar)
            XCTAssertTrue(result.failed.isEmpty)
            XCTAssertEqual(result.added, discovered.competitions.count)
            let games = try container.mainContext.fetch(FetchDescriptor<TrackedGame>()).filter { $0.followedTeamId == club.id }
            XCTAssertEqual(Set(games.map(\.leagueSlug)), Set(discovered.competitions.map(\.slug)))
            XCTAssertTrue(games.allSatisfy { $0.calendarEventId?.hasPrefix("screenshot-") == true })
            let repeatResult = await manager.followAcrossCompetitions(espnTeam: club, sourceCompetition: league,
                competitions: discovered.competitions, context: container.mainContext, espn: provider, calendar: calendar)
            XCTAssertEqual(repeatResult.added, 0)
            XCTAssertTrue(repeatResult.failed.isEmpty)
        }
        for id in ScreenshotFixtures.secondDivisionArtworkIDs {
            XCTAssertNotNil(ScreenshotFixtures.artwork(for: "mock-crest://" + id))
        }
        // The opt-in review must not alter the approved marketing dataset.
        ScreenshotFixtures.argumentsForTesting = ["-screenshot-fixtures", "-mock-second-divisions"]
        XCTAssertNil(ScreenshotFixtures.teams[.bundesliga2])
    }

    @MainActor
    func testAllProviderRoutesUseFixturesAndCalendarWritesAreSimulated() async throws {
        ScreenshotFixtures.argumentsForTesting = ["-screenshot-fixtures"]
        defer { ScreenshotFixtures.argumentsForTesting = nil }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RejectNetworkProtocol.self]
        let provider = ESPNService(session: URLSession(configuration: configuration))
        let teams = try await provider.getTeams(league: .epl)
        XCTAssertEqual(teams.count, 5)
        let membership = try await provider.getCompetitions(for: teams[0], source: .epl)
        XCTAssertEqual(Set(membership.competitions), [.epl, .faCup, .championsLeague])
        XCTAssertTrue(membership.unavailable.isEmpty)
        let schedule = try await provider.getSchedule(league: .epl, teamId: teams[0].id)
        let scoreboard = try await provider.getScoreboard(league: .epl)
        let future = try await provider.getUpcomingFixtures(league: .epl, teamId: teams[0].id)
        XCTAssertEqual(schedule.count, 7)
        XCTAssertEqual(scoreboard.count, 7)
        XCTAssertEqual(future.count, 7)
        let calendar = CalendarService()
        XCTAssertTrue(calendar.isAuthorized)
        XCTAssertNil(calendar.appCalendar)
        let access = await calendar.requestAccess()
        XCTAssertTrue(access)
        let write = calendar.upsertGame(identifier: nil, fixtureIdentity: "fixture", homeTeam: "Home", awayTeam: "Away", kickoff: Date(), venue: nil, broadcasts: [], leagueName: "League", status: nil, reminderOffset: nil)
        XCTAssertTrue(write.succeeded)
        XCTAssertEqual(write.identifier, "screenshot-fixture")
        calendar.updateGame(identifier: "personal-event", newKickoff: Date(), newTitle: "Mock")
        XCTAssertTrue(calendar.removeEvent(identifier: "personal-event"))
        XCTAssertEqual(calendar.removeAllEvents(), 0)
        let notifications = NotificationService()
        let granted = await notifications.requestAccess()
        XCTAssertFalse(granted)
        notifications.sendTestNotification()
        notifications.removeAllNotifications(followedTeamId: "personal-team")
        let store = StoreService()
        let purchased = await store.purchase()
        XCTAssertFalse(purchased)
        await store.restorePurchases()
    }

    @MainActor
    func testMockPreferencesStayOutOfStandardDefaults() {
        let suite = AppSettings.mockSuiteName
        let mock = UserDefaults(suiteName: suite)!
        mock.removePersistentDomain(forName: suite)
        let standardAppearance = UserDefaults.standard.string(forKey: "appearanceMode")
        let standardReminder = UserDefaults.standard.string(forKey: "kickoffReminder")
        let settings = AppSettings(defaults: mock)

        settings.appearanceMode = .dark
        settings.kickoffReminder = .off

        XCTAssertEqual(mock.string(forKey: "appearanceMode"), AppearanceMode.dark.rawValue)
        XCTAssertEqual(mock.string(forKey: "kickoffReminder"), KickoffReminder.off.rawValue)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "appearanceMode"), standardAppearance)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "kickoffReminder"), standardReminder)
        mock.removePersistentDomain(forName: suite)
    }

    @MainActor
    func testReminderOffReconcilesExistingCalendarAndNotificationState() async throws {
        ScreenshotFixtures.argumentsForTesting = ["-mock-data", "-screenshot-empty"]
        defer { ScreenshotFixtures.argumentsForTesting = nil }
        let container = SportsCalendarSyncApp.makeModelContainer()
        let game = TrackedGame(
            espnEventId: "fixture-1", followedTeamId: "team-1", leagueSlug: Competition.epl.slug,
            homeTeamName: "Home", awayTeamName: "Away", kickoff: Date().addingTimeInterval(3600),
            broadcasts: ["NBC"], status: "STATUS_SCHEDULED"
        )
        game.calendarEventId = "owned-event"
        container.mainContext.insert(game)
        try container.mainContext.save()

        let preferences = UserDefaults(suiteName: "ReminderOffReconciliationTests")!
        preferences.removePersistentDomain(forName: "ReminderOffReconciliationTests")
        preferences.set(KickoffReminder.off.rawValue, forKey: "kickoffReminder")
        let calendar = FakeCalendarScheduling()
        let notifications = FakeReminderNotifications()
        let result = await TeamManager(preferences: preferences).reconcileReminderPreference(
            context: container.mainContext, calendar: calendar, notifications: notifications
        )

        XCTAssertTrue(result.isSuccessful)
        XCTAssertEqual(calendar.reminders, [nil])
        XCTAssertEqual(notifications.reminders, [.off])
        XCTAssertFalse(try container.mainContext.fetch(FetchDescriptor<TrackedGame>()).first!.calendarSyncPending)
        preferences.removePersistentDomain(forName: "ReminderOffReconciliationTests")
    }

    @MainActor
    func testReminderChangeKeepsPostponedAndCancelledNotificationsRemoved() async throws {
        ScreenshotFixtures.argumentsForTesting = ["-mock-data", "-screenshot-empty"]
        defer { ScreenshotFixtures.argumentsForTesting = nil }
        let container = SportsCalendarSyncApp.makeModelContainer()
        for (id, status) in [("postponed", "STATUS_POSTPONED"), ("cancelled", "STATUS_CANCELLED")] {
            let game = TrackedGame(
                espnEventId: id, followedTeamId: "team-1", leagueSlug: Competition.epl.slug,
                homeTeamName: "Home", awayTeamName: "Away", kickoff: Date().addingTimeInterval(3600),
                broadcasts: ["NBC"], status: status
            )
            game.calendarEventId = "owned-\(id)"
            container.mainContext.insert(game)
        }
        try container.mainContext.save()

        let suite = "CancelledReminderReconciliationTests"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        preferences.removePersistentDomain(forName: suite)
        preferences.set(KickoffReminder.fifteenMin.rawValue, forKey: "kickoffReminder")
        let calendar = FakeCalendarScheduling()
        let notifications = FakeReminderNotifications()

        let result = await TeamManager(preferences: preferences).reconcileReminderPreference(
            context: container.mainContext, calendar: calendar, notifications: notifications
        )

        XCTAssertTrue(result.isSuccessful)
        XCTAssertEqual(calendar.reminders, [-900, -900])
        XCTAssertEqual(notifications.reminders, [.off, .off])
        XCTAssertTrue(notifications.pendingReminders.isEmpty)
    }

    @MainActor
    func testLatestReminderWinsWhenEarlierNotificationAddIsDelayed() async throws {
        ScreenshotFixtures.argumentsForTesting = ["-mock-data", "-screenshot-empty"]
        defer { ScreenshotFixtures.argumentsForTesting = nil }
        let container = SportsCalendarSyncApp.makeModelContainer()
        let game = TrackedGame(
            espnEventId: "fixture-1", followedTeamId: "team-1", leagueSlug: Competition.epl.slug,
            homeTeamName: "Home", awayTeamName: "Away", kickoff: Date().addingTimeInterval(3600),
            broadcasts: ["NBC"], status: "STATUS_SCHEDULED"
        )
        game.calendarEventId = "owned-event"
        container.mainContext.insert(game)
        try container.mainContext.save()

        let suite = "LatestReminderWinsTests"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        preferences.removePersistentDomain(forName: suite)
        preferences.set(KickoffReminder.fifteenMin.rawValue, forKey: "kickoffReminder")
        let manager = TeamManager(preferences: preferences)
        let calendar = FakeCalendarScheduling()
        let notifications = FakeReminderNotifications()
        notifications.delayedReminder = .fifteenMin
        let firstAddStarted = expectation(description: "The earlier notification add is suspended")
        notifications.onDelay = { firstAddStarted.fulfill() }

        let earlier = Task {
            await manager.reconcileReminderPreference(
                context: container.mainContext, calendar: calendar, notifications: notifications
            )
        }
        await fulfillment(of: [firstAddStarted], timeout: 1)

        preferences.set(KickoffReminder.off.rawValue, forKey: "kickoffReminder")
        let latest = Task {
            await manager.reconcileReminderPreference(
                context: container.mainContext, calendar: calendar, notifications: notifications
            )
        }
        for _ in 0..<5 { await Task.yield() }
        notifications.resumeDelayedReconciliation()

        let earlierResult = await earlier.value
        let latestResult = await latest.value
        XCTAssertTrue(earlierResult.wasCancelled)
        XCTAssertTrue(latestResult.isSuccessful)
        XCTAssertEqual(notifications.reminders, [.fifteenMin, .off])
        XCTAssertNil(notifications.pendingReminders["game-team-1-fixture-1"])
        XCTAssertNil(calendar.reminders.last!)
    }

    @MainActor
    func testReminderOffWaitsForDelayedNormalSyncNotificationAdd() async throws {
        let center = FakeNotificationCenterMutations()
        let service = NotificationService(mutationCenter: center, checkAuthorizationOnInit: false)
        service.isAuthorized = true
        let addStarted = expectation(description: "The normal sync notification add is suspended")
        center.onDelayedAdd = { addStarted.fulfill() }

        service.scheduleGameNotification(
            homeTeam: "Home", awayTeam: "Away", leagueName: "Premier League",
            kickoff: Date().addingTimeInterval(3600), followedTeamId: "team-1",
            espnEventId: "fixture-1", reminder: .fifteenMin
        )
        await fulfillment(of: [addStarted], timeout: 1)

        let off = Task {
            await service.reconcileGameNotification(
                homeTeam: "Home", awayTeam: "Away", leagueName: "Premier League",
                kickoff: Date().addingTimeInterval(3600), followedTeamId: "team-1",
                espnEventId: "fixture-1", reminder: .off
            )
        }
        for _ in 0..<5 { await Task.yield() }
        center.resumeDelayedAdd()

        let offResult = await off.value
        XCTAssertTrue(offResult.succeeded)
        XCTAssertEqual(center.operations, ["add-start", "add-finish", "remove"])
        XCTAssertTrue(center.pendingIdentifiers.isEmpty)
    }

    @MainActor
    func testReviewScenariosExercisePendingFailureAndLongNames() throws {
        for scenario in [MockReviewScenario.datesPending, .syncFailure, .longTitles] {
            ScreenshotFixtures.argumentsForTesting = ["-mock-data"]
            let container = SportsCalendarSyncApp.makeModelContainer(mockScenario: scenario)
            let games = try container.mainContext.fetch(FetchDescriptor<TrackedGame>())
            XCTAssertFalse(games.isEmpty)
            switch scenario {
            case .datesPending:
                XCTAssertTrue(games.contains { $0.missingSince != nil && $0.broadcasts.isEmpty })
            case .syncFailure:
                XCTAssertTrue(games.contains { $0.calendarSyncPending && $0.calendarEventId == nil })
            case .longTitles:
                XCTAssertTrue(games.contains { $0.homeTeamName.count > 40 })
            default:
                XCTFail("Unexpected scenario")
            }
        }
        ScreenshotFixtures.argumentsForTesting = nil
    }
}

private final class RejectNetworkProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        XCTFail("Screenshot mode attempted a live network request")
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }
    override func stopLoading() {}
}

@MainActor
private final class FakeCalendarScheduling: CalendarFixtureScheduling {
    var isAuthorized = true
    var reminders: [TimeInterval?] = []
    var shouldFail = false

    func upsertGame(identifier: String?, fixtureIdentity: String?, homeTeam: String, awayTeam: String,
                    kickoff: Date, venue: String?, broadcasts: [String], leagueName: String,
                    status: String?, reminderOffset: TimeInterval?) -> CalendarEventWriteResult {
        reminders.append(reminderOffset)
        return shouldFail
            ? CalendarEventWriteResult(identifier: identifier, created: false, errorMessage: "calendar failure")
            : CalendarEventWriteResult(identifier: identifier ?? "owned-event", created: false, errorMessage: nil)
    }
}

@MainActor
private final class FakeReminderNotifications: ReminderNotificationScheduling {
    var reminders: [KickoffReminder] = []
    var pendingReminders: [String: KickoffReminder] = [:]
    var shouldFail = false
    var delayedReminder: KickoffReminder?
    var onDelay: (() -> Void)?
    private var delayedContinuation: CheckedContinuation<Void, Never>?

    func reconcileGameNotification(homeTeam: String, awayTeam: String, leagueName: String?, kickoff: Date,
                                   followedTeamId: String, espnEventId: String,
                                   reminder: KickoffReminder) async -> NotificationWriteResult {
        reminders.append(reminder)
        if reminder == delayedReminder {
            await withCheckedContinuation { continuation in
                delayedContinuation = continuation
                onDelay?()
            }
        }
        let identifier = "game-\(followedTeamId)-\(espnEventId)"
        if reminder == .off {
            pendingReminders.removeValue(forKey: identifier)
        } else {
            pendingReminders[identifier] = reminder
        }
        return shouldFail
            ? NotificationWriteResult(succeeded: false, errorMessage: "notification failure")
            : .success
    }

    func resumeDelayedReconciliation() {
        let continuation = delayedContinuation
        delayedContinuation = nil
        continuation?.resume()
    }
}

@MainActor
private final class FakeNotificationCenterMutations: NotificationCenterMutationHandling {
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    var pendingIdentifiers: Set<String> = []
    var operations: [String] = []
    var onDelayedAdd: (() -> Void)?
    private var delayedAddContinuation: CheckedContinuation<Void, Never>?

    func add(_ request: UNNotificationRequest) async -> Error? {
        operations.append("add-start")
        await withCheckedContinuation { continuation in
            delayedAddContinuation = continuation
            onDelayedAdd?()
        }
        pendingIdentifiers.insert(request.identifier)
        operations.append("add-finish")
        return nil
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        pendingIdentifiers.subtract(identifiers)
        operations.append("remove")
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }

    func resumeDelayedAdd() {
        let continuation = delayedAddContinuation
        delayedAddContinuation = nil
        continuation?.resume()
    }
}
