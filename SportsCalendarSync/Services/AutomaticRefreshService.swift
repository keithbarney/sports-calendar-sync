import BackgroundTasks
import Foundation
import SwiftData
import SwiftUI

protocol BackgroundRefreshScheduling {
    @discardableResult
    func register(identifier: String, handler: @escaping (BGTask) -> Void) -> Bool
    func replaceRequest(identifier: String, earliestBeginDate: Date) throws
}

final class SystemBackgroundRefreshScheduler: BackgroundRefreshScheduling {
    @discardableResult
    func register(identifier: String, handler: @escaping (BGTask) -> Void) -> Bool {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: nil,
            launchHandler: handler
        )
    }

    func replaceRequest(identifier: String, earliestBeginDate: Date) throws {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = earliestBeginDate
        try BGTaskScheduler.shared.submit(request)
    }
}

@MainActor
enum BackgroundRefreshRequestCoordinator {
    @discardableResult
    static func scheduleNext(
        identifier: String,
        policy: RefreshPolicy,
        scheduler: BackgroundRefreshScheduling,
        health: SyncHealthStore,
        now: Date
    ) -> Date? {
        let next = policy.nextBackgroundRefresh(after: now)
        do {
            try scheduler.replaceRequest(
                identifier: identifier,
                earliestBeginDate: next
            )
            health.recordScheduledRefresh(next)
            return next
        } catch {
            health.recordSchedulingFailure(
                "iOS could not schedule a background refresh request. Launch and manual refresh still work."
            )
            return nil
        }
    }
}

@MainActor
final class AutomaticRefreshService: ObservableObject {
    static let backgroundTaskIdentifier = "com.keithbarney.sportssync.fixture-refresh"

    @Published private(set) var isRefreshing = false

    private let teamManager: TeamManager
    private let espn: ESPNService
    private let calendar: CalendarService
    private let notifications: NotificationService
    private let modelContainer: ModelContainer
    private let health: SyncHealthStore
    private let policy: RefreshPolicy
    private let scheduler: BackgroundRefreshScheduling
    private let now: () -> Date
    private var currentRefresh: Task<SyncResult, Never>?

    init(
        teamManager: TeamManager,
        espn: ESPNService,
        calendar: CalendarService,
        notifications: NotificationService,
        modelContainer: ModelContainer,
        health: SyncHealthStore,
        policy: RefreshPolicy = RefreshPolicy(),
        scheduler: BackgroundRefreshScheduling = SystemBackgroundRefreshScheduler(),
        now: @escaping () -> Date = Date.init
    ) {
        self.teamManager = teamManager
        self.espn = espn
        self.calendar = calendar
        self.notifications = notifications
        self.modelContainer = modelContainer
        self.health = health
        self.policy = policy
        self.scheduler = scheduler
        self.now = now

        let registered = scheduler.register(identifier: Self.backgroundTaskIdentifier) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let operation = Task { @MainActor [weak self] in
                guard let self else {
                    refreshTask.setTaskCompleted(success: false)
                    return
                }
                await self.handleBackgroundRefresh(refreshTask)
            }
            refreshTask.expirationHandler = {
                operation.cancel()
                Task { @MainActor [weak self] in
                    self?.cancelCurrentRefresh()
                }
            }
        }
        if !registered {
            health.recordRegistrationFailure(
                "iOS did not accept background refresh registration. Foreground and manual refresh still work."
            )
        }
    }

    func scheduleNextRefresh() {
        BackgroundRefreshRequestCoordinator.scheduleNext(
            identifier: Self.backgroundTaskIdentifier,
            policy: policy,
            scheduler: scheduler,
            health: health,
            now: now()
        )
    }

    @discardableResult
    func refreshIfNeeded(trigger: SyncTrigger) async -> SyncResult? {
        scheduleNextRefresh()
        let attemptDate = now()

        guard policy.shouldRefresh(
            trigger: trigger,
            lastAttempt: health.lastAttempt,
            now: attemptDate
        ) else {
            return nil
        }

        if let currentRefresh {
            return await currentRefresh.value
        }

        health.recordAttempt(at: attemptDate)
        isRefreshing = true

        let context = modelContainer.mainContext
        let isBackground = trigger == .background
        let operation = Task { @MainActor [teamManager, espn, calendar, notifications] in
            await teamManager.syncAllFollowed(
                context: context,
                espn: espn,
                calendar: calendar,
                notifications: notifications,
                requestCalendarAccess: false,
                weeksAhead: isBackground ? 4 : 16,
                allowsFixtureRemoval: !isBackground
            )
        }
        currentRefresh = operation
        let result = await operation.value
        currentRefresh = nil
        isRefreshing = false
        health.recordCompletion(result, at: now())
        scheduleNextRefresh()
        return result
    }

    @discardableResult
    func manualRefresh() async -> SyncResult? {
        if !calendar.isAuthorized {
            _ = await calendar.requestAccess()
        }
        return await refreshIfNeeded(trigger: .manual)
    }

    func cancelCurrentRefresh() {
        currentRefresh?.cancel()
    }

    private func handleBackgroundRefresh(_ task: BGAppRefreshTask) async {
        scheduleNextRefresh()
        let result = await refreshIfNeeded(trigger: .background)
        task.expirationHandler = nil
        task.setTaskCompleted(success: result?.isSuccessful ?? true)
    }
}
