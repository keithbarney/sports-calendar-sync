import Foundation
import SwiftUI

@MainActor
final class SyncHealthStore: ObservableObject {
    @Published private(set) var lastAttempt: Date?
    @Published private(set) var lastSuccessfulSync: Date?
    @Published private(set) var nextPlannedRefresh: Date?
    @Published private(set) var lastGamesUpdated = 0
    @Published private(set) var lastAdded = 0
    @Published private(set) var lastChanged = 0
    @Published private(set) var lastRemoved = 0
    @Published private(set) var lastCalendarRepairs = 0
    @Published private(set) var calendarRepairBannerCount: Int?
    @Published private(set) var lastError: String?
    @Published private(set) var backgroundSchedulingError: String?
    @Published private(set) var backgroundRegistrationError: String?

    private enum Key {
        static let lastAttempt = "syncHealth.lastAttempt"
        static let lastSuccessfulSync = "syncHealth.lastSuccessfulSync"
        static let nextPlannedRefresh = "syncHealth.nextPlannedRefresh"
        static let lastGamesUpdated = "syncHealth.lastGamesUpdated"
        static let lastAdded = "syncHealth.lastAdded"
        static let lastChanged = "syncHealth.lastChanged"
        static let lastRemoved = "syncHealth.lastRemoved"
        static let lastCalendarRepairs = "syncHealth.lastCalendarRepairs"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lastAttempt = defaults.object(forKey: Key.lastAttempt) as? Date
        lastSuccessfulSync = defaults.object(forKey: Key.lastSuccessfulSync) as? Date
        nextPlannedRefresh = defaults.object(forKey: Key.nextPlannedRefresh) as? Date
        lastGamesUpdated = defaults.integer(forKey: Key.lastGamesUpdated)
        lastAdded = defaults.integer(forKey: Key.lastAdded)
        lastChanged = defaults.integer(forKey: Key.lastChanged)
        lastRemoved = defaults.integer(forKey: Key.lastRemoved)
        lastCalendarRepairs = defaults.integer(forKey: Key.lastCalendarRepairs)
        // Troubleshooting is intentionally session-only. A stale failure should not
        // become permanent Settings content after the underlying issue is gone.
        defaults.removeObject(forKey: "syncHealth.lastError")
        defaults.removeObject(forKey: "syncHealth.backgroundSchedulingError")
        defaults.removeObject(forKey: "syncHealth.backgroundRegistrationError")
    }

    func recordAttempt(at date: Date) {
        lastAttempt = date
        defaults.set(date, forKey: Key.lastAttempt)
    }

    func recordCompletion(_ result: SyncResult, at date: Date) {
        if result.isSuccessful {
            lastSuccessfulSync = date
            lastGamesUpdated = result.gamesChanged
            lastAdded = result.added
            lastChanged = result.updated
            lastRemoved = result.removed
            lastCalendarRepairs = result.calendarRepairs
            calendarRepairBannerCount = result.calendarRepairs > 0 ? result.calendarRepairs : nil
            lastError = nil

            defaults.set(date, forKey: Key.lastSuccessfulSync)
            defaults.set(result.gamesChanged, forKey: Key.lastGamesUpdated)
            defaults.set(result.added, forKey: Key.lastAdded)
            defaults.set(result.updated, forKey: Key.lastChanged)
            defaults.set(result.removed, forKey: Key.lastRemoved)
            defaults.set(result.calendarRepairs, forKey: Key.lastCalendarRepairs)
        } else {
            calendarRepairBannerCount = nil
            let message: String
            if result.wasCancelled {
                message = "The refresh did not finish before iOS stopped it. Your existing fixtures were kept."
            } else if result.calendarWritesPending > 0 {
                let eventLabel = result.calendarWritesPending == 1 ? "event" : "events"
                let verb = result.calendarWritesPending == 1 ? "needs" : "need"
                message = "\(result.calendarWritesPending) calendar \(eventLabel) still \(verb) repair. Enable Calendar access, then choose Sync Calendar Now."
            } else if let first = result.failures.first {
                message = first
            } else {
                message = "The refresh could not be completed. Your existing fixtures were kept."
            }
            lastError = message
        }
    }

    func recordScheduledRefresh(_ date: Date) {
        nextPlannedRefresh = date
        backgroundSchedulingError = nil
        defaults.set(date, forKey: Key.nextPlannedRefresh)
    }

    func recordRegistrationFailure(_ message: String) {
        backgroundRegistrationError = message
    }

    func recordRegistrationSuccess() {
        backgroundRegistrationError = nil
    }

    func recordSchedulingFailure(_ message: String) {
        nextPlannedRefresh = nil
        backgroundSchedulingError = message
        defaults.removeObject(forKey: Key.nextPlannedRefresh)
    }

    func dismissCalendarRepairBanner() {
        calendarRepairBannerCount = nil
    }

    func dismissLastError() {
        lastError = nil
    }

    func dismissBackgroundSchedulingError() {
        backgroundSchedulingError = nil
    }

    func dismissBackgroundRegistrationError() {
        backgroundRegistrationError = nil
    }
}
