import UserNotifications
import XCTest
@testable import SportsCalendarSync

/// Explicitly opt-in physical-device checks. Normal test runs skip these.
/// Only the dedicated delivery-check notification is read or changed; no
/// followed teams, fixture stores, or EventKit events are created.
@MainActor
final class LiveReminderDeliveryTests: XCTestCase {
    private struct Match: Decodable {
        let eventID: String
        let home: String
        let away: String
        let league: String
        let kickoff: String
    }

    private func match() throws -> (Match, Date) {
        guard let payload = ProcessInfo.processInfo.environment["SPORTS_REMINDER_CHECK_PAYLOAD"] else {
            throw XCTSkip("Requires an explicitly authorized live notification check")
        }
        let match = try JSONDecoder().decode(Match.self, from: Data(payload.utf8))
        let kickoff = try XCTUnwrap(ISO8601DateFormatter().date(from: match.kickoff))
        return (match, kickoff)
    }

    func testScheduleRealMatchNotification() async throws {
        let (match, kickoff) = try match()
        XCTAssertGreaterThan(kickoff.addingTimeInterval(-1800), Date(), "The reminder must still be in the future")
        let service = NotificationService(checkAuthorizationOnInit: false)
        await service.refreshAuthorization()
        XCTAssertTrue(service.isAuthorized, "Enable Sports notifications on the test phone before scheduling")
        guard service.isAuthorized else { return }
        let result = await service.reconcileGameNotification(
            homeTeam: match.home, awayTeam: match.away, leagueName: match.league + " (reminder test)",
            kickoff: kickoff, followedTeamId: "delivery-check", espnEventId: match.eventID, reminder: .thirtyMin
        )
        XCTAssertTrue(result.succeeded, result.errorMessage ?? "")
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let request = try XCTUnwrap(pending.first { $0.identifier == "game-delivery-check-\(match.eventID)" })
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.nextTriggerDate(), kickoff.addingTimeInterval(-1800))
        XCTAssertEqual(trigger.dateComponents.timeZone?.secondsFromGMT(), 0)
        try await writeReport(match: match, kickoff: kickoff)
    }

    func testInspectRealMatchNotification() async throws {
        let (match, kickoff) = try match()
        try await writeReport(match: match, kickoff: kickoff)
    }

    private func writeReport(match: Match, kickoff: Date) async throws {
        let center = UNUserNotificationCenter.current()
        let id = "game-delivery-check-\(match.eventID)"
        let pending = await center.pendingNotificationRequests().filter { $0.identifier == id }
        let delivered = await center.deliveredNotifications().filter { $0.request.identifier == id }
        let formatter = ISO8601DateFormatter()
        let report: [String: Any] = [
            "identifier": id,
            "match": "\(match.home) vs. \(match.away)",
            "kickoffUTC": formatter.string(from: kickoff),
            "expectedAlertUTC": formatter.string(from: kickoff.addingTimeInterval(-1800)),
            "checkedAtUTC": formatter.string(from: Date()),
            "deviceTimeZone": TimeZone.current.identifier,
            "version": Bundle.main.marketingVersion,
            "build": Bundle.main.buildNumber,
            "pending": pending.map { request -> [String: String] in
                let trigger = request.trigger as? UNCalendarNotificationTrigger
                return ["nextTriggerUTC": trigger?.nextTriggerDate().map { formatter.string(from: $0) } ?? "none",
                        "timeZone": trigger?.dateComponents.timeZone?.identifier ?? "none"]
            },
            "delivered": delivered.map { ["deliveredAtUTC": formatter.string(from: $0.date)] }
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try data.write(to: directory.appendingPathComponent("reminder-delivery-check.json"), options: .atomic)
        print("[REMINDER-CHECK] " + String(decoding: data, as: UTF8.self))
    }
}
