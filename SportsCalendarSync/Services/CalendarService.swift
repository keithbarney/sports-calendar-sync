import EventKit
import os
import SwiftUI

private let logger = Logger(subsystem: "com.keithbarney.sportssync", category: "CalendarService")

@MainActor
class CalendarService: ObservableObject {
    private let store = EKEventStore()
    @Published var isAuthorized = false
    @Published var appCalendar: EKCalendar?

    private let calendarTitle = "Sports"

    /// ~105 minutes of gameplay + ~15 minute halftime buffer. Overridable per-event by caller.
    private let defaultMatchDurationSeconds: TimeInterval = 120 * 60

    init() {
        checkAuthorization()
    }

    func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        isAuthorized = status == .fullAccess
        if isAuthorized {
            findOrCreateCalendar()
        }
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            await MainActor.run {
                isAuthorized = granted
                if granted {
                    findOrCreateCalendar()
                }
            }
            return granted
        } catch {
            return false
        }
    }

    private func findOrCreateCalendar() {
        if let existing = store.calendars(for: .event).first(where: { $0.title == calendarTitle }) {
            appCalendar = existing
            return
        }

        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = calendarTitle
        calendar.cgColor = CGColor(red: 0.2, green: 0.85, blue: 0.4, alpha: 1.0) // Green

        if let defaultSource = store.defaultCalendarForNewEvents?.source {
            calendar.source = defaultSource
        } else if let localSource = store.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = localSource
        }

        do {
            try store.saveCalendar(calendar, commit: true)
            appCalendar = calendar
        } catch {
            logger.error("Failed to create calendar: \(error.localizedDescription)")
        }
    }

    // MARK: - Match events

    /// Create a calendar event for a soccer match. Returns the EKEvent identifier.
    func addGame(
        homeTeam: String,
        awayTeam: String,
        kickoff: Date,
        venue: String?,
        broadcasts: [String],
        leagueName: String
    ) -> String? {
        guard isAuthorized, let calendar = appCalendar else { return nil }

        let event = EKEvent(eventStore: store)
        event.title = "\(homeTeam) vs. \(awayTeam)"
        event.startDate = kickoff
        event.endDate = kickoff.addingTimeInterval(defaultMatchDurationSeconds)
        event.calendar = calendar
        event.location = venue

        var notes = leagueName
        if !broadcasts.isEmpty {
            notes += "\n\nBroadcast: \(broadcasts.joined(separator: ", "))"
        }
        event.notes = notes

        // 30 minutes before kickoff
        event.addAlarm(EKAlarm(relativeOffset: -1800))

        do {
            try store.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            logger.error("Failed to save event: \(error.localizedDescription)")
            return nil
        }
    }

    /// Update an existing event in place — used when ESPN reschedules / postpones a match.
    func updateGame(identifier: String, newKickoff: Date, newTitle: String) {
        guard let event = store.event(withIdentifier: identifier) else { return }
        event.title = newTitle
        event.startDate = newKickoff
        event.endDate = newKickoff.addingTimeInterval(defaultMatchDurationSeconds)
        do {
            try store.save(event, span: .thisEvent)
        } catch {
            logger.error("Failed to update event: \(error.localizedDescription)")
        }
    }

    func removeEvent(identifier: String) {
        guard let event = store.event(withIdentifier: identifier) else { return }
        do {
            try store.remove(event, span: .thisEvent)
        } catch {
            logger.error("Failed to remove event: \(error.localizedDescription)")
        }
    }

    func removeEvents(identifiers: [String]) {
        identifiers.forEach { removeEvent(identifier: $0) }
    }

    func removeAllEvents() -> Int {
        guard let calendar = appCalendar else { return 0 }

        let now = Date()
        guard let yearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now),
              let yearAhead = Calendar.current.date(byAdding: .year, value: 1, to: now) else { return 0 }

        let predicate = store.predicateForEvents(withStart: yearAgo, end: yearAhead, calendars: [calendar])
        let events = store.events(matching: predicate)
        for event in events {
            try? store.remove(event, span: .thisEvent)
        }
        logger.info("Removed all \(events.count) calendar events")
        return events.count
    }
}
