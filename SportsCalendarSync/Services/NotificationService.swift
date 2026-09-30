import UserNotifications
import SwiftUI

struct NotificationWriteResult: Equatable {
    let succeeded: Bool
    let errorMessage: String?

    static let success = NotificationWriteResult(succeeded: true, errorMessage: nil)
}

@MainActor
protocol ReminderNotificationScheduling: AnyObject {
    func reconcileGameNotification(
        homeTeam: String,
        awayTeam: String,
        leagueName: String?,
        kickoff: Date,
        followedTeamId: String,
        espnEventId: String,
        reminder: KickoffReminder
    ) async -> NotificationWriteResult
}

@MainActor
protocol NotificationCenterMutationHandling: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func add(_ request: UNNotificationRequest) async -> Error?
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func pendingNotificationRequests() async -> [UNNotificationRequest]
}

@MainActor
private final class SystemNotificationCenterMutations: NotificationCenterMutationHandling {
    private let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func add(_ request: UNNotificationRequest) async -> Error? {
        await withCheckedContinuation { continuation in
            center.add(request) { error in
                continuation.resume(returning: error)
            }
        }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }
}

/// Push notifications for upcoming kickoffs. Calendar events still get their own alarm via
/// `CalendarService` — this is the *additional* push reminder mentioned in CLAUDE.md.
@MainActor
final class NotificationService: ObservableObject, ReminderNotificationScheduling {
    @Published var isAuthorized = false
    private let mutationCenter: NotificationCenterMutationHandling
    private var mutationTail: Task<Void, Never>?

    init(
        mutationCenter: NotificationCenterMutationHandling? = nil,
        checkAuthorizationOnInit: Bool = true
    ) {
        self.mutationCenter = mutationCenter ?? SystemNotificationCenterMutations()
        if checkAuthorizationOnInit { checkAuthorization() }
    }

    func checkAuthorization() {
        Task { await refreshAuthorization() }
    }

    func refreshAuthorization() async {
        #if DEBUG
        if ScreenshotFixtures.isEnabled { return }
        #endif
        isAuthorized = await mutationCenter.authorizationStatus() == .authorized
    }

    func requestAccess() async -> Bool {
        #if DEBUG
        if ScreenshotFixtures.isEnabled { return false }
        #endif
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
        #if DEBUG
        if ScreenshotFixtures.isEnabled { return }
        #endif
        guard let request = makeRequest(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            leagueName: leagueName,
            kickoff: kickoff,
            followedTeamId: followedTeamId,
            espnEventId: espnEventId,
            reminder: reminder
        ) else { return }
        enqueueMutation { [mutationCenter] in
            _ = await mutationCenter.add(request)
        }
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
        #if DEBUG
        if ScreenshotFixtures.isEnabled { return }
        #endif
        let id = Self.identifier(followedTeamId: followedTeamId, espnEventId: espnEventId)
        let request = makeRequest(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            leagueName: leagueName,
            kickoff: kickoff,
            followedTeamId: followedTeamId,
            espnEventId: espnEventId,
            reminder: reminder
        )
        enqueueMutation { [mutationCenter] in
            mutationCenter.removePendingNotificationRequests(withIdentifiers: [id])
            if let request {
                _ = await mutationCenter.add(request)
            }
        }
    }

    /// Reconcile one app-owned pending request and report failures from the
    /// asynchronous UserNotifications API. Off always removes the request.
    func reconcileGameNotification(
        homeTeam: String,
        awayTeam: String,
        leagueName: String?,
        kickoff: Date,
        followedTeamId: String,
        espnEventId: String,
        reminder: KickoffReminder
    ) async -> NotificationWriteResult {
        #if DEBUG
        if ScreenshotFixtures.isEnabled { return .success }
        #endif
        let id = Self.identifier(followedTeamId: followedTeamId, espnEventId: espnEventId)
        let request = makeRequest(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            leagueName: leagueName,
            kickoff: kickoff,
            followedTeamId: followedTeamId,
            espnEventId: espnEventId,
            reminder: reminder
        )

        return await performMutation { [mutationCenter] in
            mutationCenter.removePendingNotificationRequests(withIdentifiers: [id])
            guard let request else { return .success }
            return await mutationCenter.add(request).map {
                    NotificationWriteResult(
                        succeeded: false,
                        errorMessage: "Notifications could not be updated for \(homeTeam) vs. \(awayTeam): \($0.localizedDescription)"
                    )
                } ?? .success
        }
    }

    func removeGameNotification(followedTeamId: String, espnEventId: String) {
        #if DEBUG
        if ScreenshotFixtures.isEnabled { return }
        #endif
        let id = Self.identifier(followedTeamId: followedTeamId, espnEventId: espnEventId)
        enqueueMutation { [mutationCenter] in
            mutationCenter.removePendingNotificationRequests(withIdentifiers: [id])
        }
    }

    /// Older requests stored a floating local clock time. Rebuild only those
    /// still pending, using the stored kickoff instant rather than interpreting
    /// their clock components in the phone's current (possibly changed) zone.
    func repairLegacyGameNotifications(
        fixtures: [FixtureSnapshot],
        reminder: KickoffReminder
    ) async -> NotificationWriteResult {
        #if DEBUG
        if ScreenshotFixtures.isEnabled { return .success }
        #endif
        guard isAuthorized else { return .success }
        let fixturesByID = Dictionary(fixtures.map {
            (Self.identifier(followedTeamId: $0.followedTeamId, espnEventId: $0.espnEventId), $0)
        }, uniquingKeysWith: { first, _ in first })

        return await performMutation { [self] in
            let pending = await mutationCenter.pendingNotificationRequests()
            var result = NotificationWriteResult.success
            for existing in pending {
                guard let trigger = existing.trigger as? UNCalendarNotificationTrigger,
                      trigger.dateComponents.timeZone == nil,
                      let fixture = fixturesByID[existing.identifier] else { continue }
                let request = makeRequest(
                    homeTeam: fixture.homeTeamName,
                    awayTeam: fixture.awayTeamName,
                    leagueName: Competition(rawValue: fixture.leagueSlug)?.displayName,
                    kickoff: fixture.kickoff,
                    followedTeamId: fixture.followedTeamId,
                    espnEventId: fixture.espnEventId,
                    reminder: fixture.isPostponedOrCancelled ? .off : reminder
                )
                if let request {
                    // A matching identifier replaces the old request. Keep it
                    // pending on failure so the next foreground pass can retry.
                    if let error = await mutationCenter.add(request) {
                        result = NotificationWriteResult(
                            succeeded: false,
                            errorMessage: "A kickoff reminder could not be repaired: \(error.localizedDescription)"
                        )
                    }
                } else {
                    mutationCenter.removePendingNotificationRequests(withIdentifiers: [existing.identifier])
                }
            }
            return result
        }
    }

    /// Wipe every pending kickoff notification for a team (used on unfollow).
    func removeAllNotifications(followedTeamId: String) {
        #if DEBUG
        if ScreenshotFixtures.isEnabled { return }
        #endif
        let prefix = "game-\(followedTeamId)-"
        enqueueMutation { [mutationCenter] in
            let requests = await mutationCenter.pendingNotificationRequests()
            let ids = requests.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
            if !ids.isEmpty {
                mutationCenter.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }

    func sendTestNotification() {
        #if DEBUG
        if ScreenshotFixtures.isEnabled { return }
        #endif
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

    private func makeRequest(
        homeTeam: String,
        awayTeam: String,
        leagueName: String?,
        kickoff: Date,
        followedTeamId: String,
        espnEventId: String,
        reminder: KickoffReminder
    ) -> UNNotificationRequest? {
        guard isAuthorized, let offset = reminder.offsetSeconds else { return nil }
        let triggerDate = kickoff.addingTimeInterval(offset)
        guard triggerDate > Date() else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "\(homeTeam) vs. \(awayTeam)"
        if let leagueName { content.subtitle = leagueName }
        content.body = "Kickoff — \(reminder.rawValue)"
        content.sound = .default
        // Kickoff is an absolute instant. Pin both the calendar and time zone so
        // travel or daylight-saving changes cannot move an already queued alert.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents(
            [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(
            identifier: Self.identifier(followedTeamId: followedTeamId, espnEventId: espnEventId),
            content: content,
            trigger: trigger
        )
    }

    private func enqueueMutation(_ mutation: @escaping @MainActor () async -> Void) {
        let predecessor = mutationTail
        let operation = Task { @MainActor in
            _ = await predecessor?.value
            await mutation()
        }
        mutationTail = operation
    }

    private func performMutation(
        _ mutation: @escaping @MainActor () async -> NotificationWriteResult
    ) async -> NotificationWriteResult {
        let predecessor = mutationTail
        let operation = Task { @MainActor in
            _ = await predecessor?.value
            return await mutation()
        }
        mutationTail = Task { @MainActor in
            _ = await operation.value
        }
        return await operation.value
    }
}
