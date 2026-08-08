import XCTest
@testable import SportsCalendarSync

final class FixtureReconcilerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testNewFixtureIsInserted() {
        let fixture = makeFixture(id: "new")

        let plan = FixtureReconciler().makePlan(
            existing: [],
            fetched: [fixture],
            allowsRemoval: true,
            now: now
        )

        XCTAssertEqual(plan.inserts, [fixture])
        XCTAssertTrue(plan.updates.isEmpty)
        XCTAssertTrue(plan.removals.isEmpty)
    }

    func testKickoffMetadataAndPostponementChangesAreUpdated() {
        let original = makeFixture(id: "match")
        let changed = makeFixture(
            id: "match",
            kickoff: original.kickoff.addingTimeInterval(3_600),
            venue: "New Ground",
            broadcasts: ["ESPN"],
            status: "STATUS_POSTPONED"
        )

        let plan = FixtureReconciler().makePlan(
            existing: [stored(original)],
            fetched: [changed],
            allowsRemoval: true,
            now: now
        )

        XCTAssertEqual(plan.updates, [changed])
        XCTAssertTrue(plan.removals.isEmpty)
        XCTAssertTrue(changed.isPostponedOrCancelled)
    }

    func testPartialFetchNeverMarksOrRemovesMissingFixtures() {
        let existing = stored(
            makeFixture(id: "keep"),
            missingSince: now.addingTimeInterval(-172_800)
        )

        let plan = FixtureReconciler().makePlan(
            existing: [existing],
            fetched: [],
            allowsRemoval: false,
            now: now
        )

        XCTAssertTrue(plan.marksMissing.isEmpty)
        XCTAssertTrue(plan.removals.isEmpty)
    }

    func testFirstAuthoritativeAbsenceStartsGracePeriod() {
        let fixture = makeFixture(id: "missing")

        let plan = FixtureReconciler().makePlan(
            existing: [stored(fixture)],
            fetched: [],
            allowsRemoval: true,
            now: now
        )

        XCTAssertEqual(plan.marksMissing[fixture.espnEventId], now)
        XCTAssertTrue(plan.removals.isEmpty)
    }

    func testRemovedFixtureIsDeletedAfterGracePeriod() {
        let fixture = makeFixture(id: "removed")
        let existing = stored(
            fixture,
            calendarEventId: "event-kit-id",
            missingSince: now.addingTimeInterval(-86_400)
        )

        let plan = FixtureReconciler().makePlan(
            existing: [existing],
            fetched: [],
            allowsRemoval: true,
            now: now
        )

        XCTAssertEqual(plan.removals, [existing])
        XCTAssertTrue(plan.marksMissing.isEmpty)
    }

    func testReappearingFixtureClearsMissingMarker() {
        let fixture = makeFixture(id: "returned")
        let existing = stored(fixture, missingSince: now.addingTimeInterval(-3_600))

        let plan = FixtureReconciler().makePlan(
            existing: [existing],
            fetched: [fixture],
            allowsRemoval: true,
            now: now
        )

        XCTAssertEqual(plan.clearsMissingMarker, [fixture.espnEventId])
        XCTAssertTrue(plan.removals.isEmpty)
    }

    func testPendingCalendarWriteRetriesEvenWhenOldEventStillExists() {
        let policy = CalendarRepairPolicy()

        XCTAssertTrue(policy.needsRepair(syncPending: true, eventExists: true))
        XCTAssertTrue(policy.needsRepair(syncPending: false, eventExists: false))
        XCTAssertFalse(policy.needsRepair(syncPending: false, eventExists: true))
    }

    private func makeFixture(
        id: String,
        kickoff: Date? = nil,
        venue: String? = "Stadium",
        broadcasts: [String] = [],
        status: String? = "STATUS_SCHEDULED"
    ) -> FixtureSnapshot {
        FixtureSnapshot(
            espnEventId: id,
            followedTeamId: "team",
            leagueSlug: "eng.1",
            homeTeamName: "Home",
            homeTeamLogo: nil,
            awayTeamName: "Away",
            awayTeamLogo: nil,
            kickoff: kickoff ?? now.addingTimeInterval(86_400),
            venue: venue,
            broadcasts: broadcasts,
            status: status
        )
    }

    private func stored(
        _ fixture: FixtureSnapshot,
        calendarEventId: String? = nil,
        missingSince: Date? = nil
    ) -> StoredFixtureSnapshot {
        StoredFixtureSnapshot(
            fixture: fixture,
            calendarEventId: calendarEventId,
            missingSince: missingSince
        )
    }
}
