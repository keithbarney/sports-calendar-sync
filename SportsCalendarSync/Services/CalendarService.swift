import EventKit
import os
import SwiftUI

private let logger = Logger(subsystem: "com.keithbarney.sportssync", category: "CalendarService")

struct CalendarEventWriteResult {
    let identifier: String?
    let created: Bool
    let errorMessage: String?

    var succeeded: Bool { identifier != nil && errorMessage == nil }
}

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
    /// `reminderOffset` is a negative TimeInterval (seconds before kickoff) or nil for no alarm.
    func addGame(
        homeTeam: String,
        awayTeam: String,
        kickoff: Date,
        venue: String?,
        broadcasts: [String],
        leagueName: String,
        reminderOffset: TimeInterval? = -1800
    ) -> String? {
        upsertGame(
            identifier: nil,
            fixtureIdentity: nil,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            kickoff: kickoff,
            venue: venue,
            broadcasts: broadcasts,
            leagueName: leagueName,
            status: nil,
            reminderOffset: reminderOffset
        ).identifier
    }

    /// Creates or fully refreshes the EventKit event. A stale identifier is repaired by
    /// creating a replacement, which covers user-deleted events and calendar recreation.
    func upsertGame(
        identifier: String?,
        fixtureIdentity: String?,
        homeTeam: String,
        awayTeam: String,
        kickoff: Date,
        venue: String?,
        broadcasts: [String],
        leagueName: String,
        status: String?,
        reminderOffset: TimeInterval?
    ) -> CalendarEventWriteResult {
        guard isAuthorized, let calendar = appCalendar else {
            return CalendarEventWriteResult(
                identifier: nil,
                created: false,
                errorMessage: "Calendar access is unavailable. Enable Calendar in Settings to repair fixture events."
            )
        }

        let existing = event(for: identifier)
        let event = existing ?? EKEvent(eventStore: store)
        let statusText = displayStatus(status)
        event.title = statusText.map { "\(homeTeam) vs. \(awayTeam) — \($0)" }
            ?? "\(homeTeam) vs. \(awayTeam)"
        event.startDate = kickoff
        event.endDate = kickoff.addingTimeInterval(defaultMatchDurationSeconds)
        event.calendar = calendar
        event.location = venue

        var notes = leagueName
        if let statusText {
            notes += "\n\nStatus: \(statusText)"
        }
        if !broadcasts.isEmpty {
            notes += "\n\nBroadcast: \(broadcasts.joined(separator: ", "))"
        }
        event.notes = notes
        if let fixtureIdentity {
            event.url = fixtureURL(for: fixtureIdentity)
        }
        event.alarms?.forEach { event.removeAlarm($0) }
        if let reminderOffset, statusText == nil {
            event.addAlarm(EKAlarm(relativeOffset: reminderOffset))
        }

        do {
            try store.save(event, span: .thisEvent)
            return CalendarEventWriteResult(
                identifier: event.calendarItemIdentifier,
                created: existing == nil,
                errorMessage: nil
            )
        } catch {
            logger.error("Failed to save event: \(error.localizedDescription)")
            return CalendarEventWriteResult(
                identifier: identifier,
                created: false,
                errorMessage: "Calendar could not save a fixture. Open the app and tap Resync Calendar."
            )
        }
    }

    /// Resolves a persisted EventKit identifier, then falls back to the app's unique fixture marker.
    /// Never infer ownership from a title or kickoff time: a user may have their own look-alike
    /// event in a calendar named Sports, and the app must not adopt or delete it.
    func resolveEventIdentifier(
        identifier: String?,
        fixtureIdentity: String,
        kickoff: Date,
        previousKickoff: Date? = nil
    ) -> String? {
        if let event = event(for: identifier) {
            tag(event, with: fixtureIdentity)
            return event.calendarItemIdentifier
        }
        guard let calendar = appCalendar else { return nil }

        let expectedURL = fixtureURL(for: fixtureIdentity)
        let window: TimeInterval = 5 * 60
        let dates = [kickoff, previousKickoff].compactMap { $0 }
        for date in dates {
            let predicate = store.predicateForEvents(
                withStart: date.addingTimeInterval(-window),
                end: date.addingTimeInterval(window),
                calendars: [calendar]
            )
            if let event = store.events(matching: predicate).first(where: { $0.url == expectedURL }) {
                tag(event, with: fixtureIdentity)
                return event.calendarItemIdentifier
            }
        }

        return nil
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

    @discardableResult
    func removeEvent(identifier: String) -> Bool {
        guard let event = event(for: identifier) else { return true }
        do {
            try store.remove(event, span: .thisEvent)
            return true
        } catch {
            logger.error("Failed to remove event: \(error.localizedDescription)")
            return false
        }
    }

    func removeEvents(identifiers: [String]) {
        identifiers.forEach { removeEvent(identifier: $0) }
    }

    private func displayStatus(_ status: String?) -> String? {
        guard let status = status?.uppercased() else { return nil }
        if status.contains("POSTPONED") { return "Postponed" }
        if status.contains("CANCELED") || status.contains("CANCELLED") { return "Cancelled" }
        return nil
    }

    private func event(for identifier: String?) -> EKEvent? {
        guard let identifier else { return nil }
        if let item = store.calendarItem(withIdentifier: identifier) as? EKEvent {
            return item
        }
        // Older app versions persisted `eventIdentifier`; retain it as a migration fallback.
        return store.event(withIdentifier: identifier)
    }

    private func fixtureURL(for identity: String) -> URL? {
        var components = URLComponents()
        components.scheme = "sportscalendarsync"
        components.host = "fixture"
        components.queryItems = [URLQueryItem(name: "id", value: identity)]
        return components.url
    }

    private func tag(_ event: EKEvent, with fixtureIdentity: String) {
        let marker = fixtureURL(for: fixtureIdentity)
        guard event.url != marker else { return }
        event.url = marker
        try? store.save(event, span: .thisEvent)
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
