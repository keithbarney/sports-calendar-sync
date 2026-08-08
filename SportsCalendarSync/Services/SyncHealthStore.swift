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
        static let lastError = "syncHealth.lastError"
        static let backgroundSchedulingError = "syncHealth.backgroundSchedulingError"
        static let backgroundRegistrationError = "syncHealth.backgroundRegistrationError"
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
        lastError = defaults.string(forKey: Key.lastError)
        backgroundSchedulingError = defaults.string(forKey: Key.backgroundSchedulingError)
        backgroundRegistrationError = defaults.string(forKey: Key.backgroundRegistrationError)
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
            lastError = nil

            defaults.set(date, forKey: Key.lastSuccessfulSync)
            defaults.set(result.gamesChanged, forKey: Key.lastGamesUpdated)
            defaults.set(result.added, forKey: Key.lastAdded)
            defaults.set(result.updated, forKey: Key.lastChanged)
            defaults.set(result.removed, forKey: Key.lastRemoved)
            defaults.set(result.calendarRepairs, forKey: Key.lastCalendarRepairs)
            defaults.removeObject(forKey: Key.lastError)
        } else {
            let message: String
            if result.wasCancelled {
                message = "The refresh did not finish before iOS stopped it. Your existing fixtures were kept."
            } else if result.calendarWritesPending > 0 {
                message = "\(result.calendarWritesPending) calendar event(s) still need repair. Enable Calendar access and tap Resync Calendar."
            } else if let first = result.failures.first {
                message = first
            } else {
                message = "The refresh could not be completed. Your existing fixtures were kept."
            }
            lastError = message
            defaults.set(message, forKey: Key.lastError)
        }
    }

    func recordScheduledRefresh(_ date: Date) {
        nextPlannedRefresh = date
        backgroundSchedulingError = nil
        defaults.set(date, forKey: Key.nextPlannedRefresh)
        defaults.removeObject(forKey: Key.backgroundSchedulingError)
    }

    func recordRegistrationFailure(_ message: String) {
        backgroundRegistrationError = message
        defaults.set(message, forKey: Key.backgroundRegistrationError)
    }

    func recordSchedulingFailure(_ message: String) {
        nextPlannedRefresh = nil
        backgroundSchedulingError = message
        defaults.removeObject(forKey: Key.nextPlannedRefresh)
        defaults.set(message, forKey: Key.backgroundSchedulingError)
    }
}
