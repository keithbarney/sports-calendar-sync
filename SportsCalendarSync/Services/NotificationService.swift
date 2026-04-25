import UserNotifications
import SwiftUI

/// Push notifications for upcoming kickoffs. Calendar events still get their own alarm via
/// `CalendarService` — this is the *additional* push reminder mentioned in CLAUDE.md.
@MainActor
final class NotificationService: ObservableObject {
    @Published var isAuthorized = false

    init() {
        checkAuthorization()
    }

    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            return false
        }
    }

    /// Schedule a push notification for a single fixture.
    /// Identifier shape: `game-<followedTeamId>-<espnEventId>` so per-team removal is cheap.
    func scheduleGameNotification(
        homeTeam: String,
        awayTeam: String,
        leagueName: String?,
        kickoff: Date,
        followedTeamId: String,
        espnEventId: String,
        reminder: KickoffReminder = .thirtyMin
    ) {
        guard isAuthorized, let offset = reminder.offsetSeconds else { return }

        let triggerDate = kickoff.addingTimeInterval(offset)
        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(homeTeam) vs. \(awayTeam)"
        if let leagueName {
            content.subtitle = leagueName
        }
        content.body = reminder == .off ? "Kickoff" : "Kickoff — \(reminder.rawValue)"
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let id = Self.identifier(followedTeamId: followedTeamId, espnEventId: espnEventId)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Cancel + reschedule (no native "update" API for pending requests).
    func rescheduleGameNotification(
        homeTeam: String,
        awayTeam: String,
        leagueName: String?,
        kickoff: Date,
        followedTeamId: String,
        espnEventId: String,
        reminder: KickoffReminder = .thirtyMin
    ) {
        removeGameNotification(followedTeamId: followedTeamId, espnEventId: espnEventId)
        scheduleGameNotification(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            leagueName: leagueName,
            kickoff: kickoff,
            followedTeamId: followedTeamId,
            espnEventId: espnEventId,
            reminder: reminder
        )
    }

    func removeGameNotification(followedTeamId: String, espnEventId: String) {
        let id = Self.identifier(followedTeamId: followedTeamId, espnEventId: espnEventId)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Wipe every pending kickoff notification for a team (used on unfollow).
    func removeAllNotifications(followedTeamId: String) {
        let prefix = "game-\(followedTeamId)-"
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Sports"
        content.body = "Notifications are working"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static func identifier(followedTeamId: String, espnEventId: String) -> String {
        "game-\(followedTeamId)-\(espnEventId)"
    }
}
