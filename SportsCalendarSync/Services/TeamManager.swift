import Foundation
import SwiftData
import SwiftUI
import os

private let logger = Logger(subsystem: "com.keithbarney.sportssync", category: "TeamManager")

/// Centralized follow/unfollow + schedule-sync for teams.
/// Mirrors `MediaManager` from the TV & Movie Calendar Sync project.
@MainActor
final class TeamManager: ObservableObject {
    @Published var isSyncing = false
    /// Human-readable summary of the last sync, for on-device debugging.
    @Published var lastSyncSummary: String = ""
    private var activeSyncKeys: Set<String> = []

    /// Resolve the user's current kickoff-reminder preference from UserDefaults
    /// (shared storage with `@AppStorage("kickoffReminder")` in AppSettings).
    private var currentReminder: KickoffReminder {
        let raw = UserDefaults.standard.string(forKey: "kickoffReminder") ?? KickoffReminder.thirtyMin.rawValue
        return KickoffReminder(rawValue: raw) ?? .thirtyMin
    }

    private var currentReminderOffset: TimeInterval? {
        currentReminder.offsetSeconds
    }

    /// Follow a team: persist + immediately fetch & mirror schedule to Calendar.
    func follow(
        espnTeam: ESPNTeam,
        league: League,
        context: ModelContext,
        espn: ESPNService,
        calendar: CalendarService,
        notifications: NotificationService? = nil
    ) async {
        // Dedupe
        let id = espnTeam.id
        let slug = league.slug
        let descriptor = FetchDescriptor<TrackedTeam>(
            predicate: #Predicate { $0.espnId == id && $0.leagueSlug == slug }
        )
        if let existing = try? context.fetch(descriptor), !existing.isEmpty { return }

        let team = TrackedTeam(
            espnId: espnTeam.id,
            leagueSlug: league.slug,
            name: espnTeam.displayName ?? espnTeam.name ?? "Unknown",
            shortDisplayName: espnTeam.shortDisplayName,
            abbreviation: espnTeam.abbreviation,
            logoURL: espnTeam.logos?.first?.href,
            primaryColor: espnTeam.color
        )
        context.insert(team)
        try? context.save()

        // Ensure we have calendar access BEFORE trying to write events —
        // otherwise `CalendarService.addGame` silently no-ops.
        if !calendar.isAuthorized {
            _ = await calendar.requestAccess()
        }

        // Push notifications are additive to the calendar alarm — request once on follow.
        if let notifications, !notifications.isAuthorized {
            _ = await notifications.requestAccess()
        }

        _ = await syncSchedule(
            for: team,
            context: context,
            espn: espn,
            calendar: calendar,
            league: league,
            notifications: notifications
        )
    }

    func unfollow(
        team: TrackedTeam,
        context: ModelContext,
        calendar: CalendarService,
        notifications: NotificationService? = nil
    ) {
        // Remove mirrored calendar events for this team
        let id = team.espnId
        let descriptor = FetchDescriptor<TrackedGame>(
            predicate: #Predicate { $0.followedTeamId == id }
        )
        if let games = try? context.fetch(descriptor) {
            let ids = games.compactMap { $0.calendarEventId }
            calendar.removeEvents(identifiers: ids)
            games.forEach { context.delete($0) }
        }
        notifications?.removeAllNotifications(followedTeamId: id)
        context.delete(team)
        try? context.save()
    }

    /// Sync every followed team's schedule. Useful after granting calendar access the first time,
    /// or after the user manually taps "Sync fixtures" in Profile.
    @discardableResult
    func syncAllFollowed(
        context: ModelContext,
        espn: ESPNService,
        calendar: CalendarService,
        notifications: NotificationService? = nil,
        requestCalendarAccess: Bool = true,
        weeksAhead: Int = 16,
        allowsFixtureRemoval: Bool = true
    ) async -> SyncResult {
        isSyncing = true
        defer { isSyncing = false }

        if requestCalendarAccess, !calendar.isAuthorized {
            _ = await calendar.requestAccess()
        }

        let teams: [TrackedTeam]
        do {
            teams = try context.fetch(FetchDescriptor<TrackedTeam>())
        } catch {
            var result = SyncResult()
            result.failures = ["Followed teams could not be loaded. Open the app and try again."]
            return result
        }

        var aggregate = SyncResult()
        let grouped = Dictionary(grouping: teams.compactMap { team in
            team.league.map { ($0, team) }
        }, by: { $0.0 })

        for (league, members) in grouped {
            if Task.isCancelled {
                aggregate.wasCancelled = true
                break
            }

            let teamIds = Set(members.map { $0.1.espnId })
            let futureResult: UpcomingFixturesFetchResult
            do {
                futureResult = try await espn.getUpcomingFixturesResult(
                    league: league,
                    teamIds: teamIds,
                    weeksAhead: weeksAhead
                )
            } catch is CancellationError {
                aggregate.wasCancelled = true
                break
            } catch {
                futureResult = UpcomingFixturesFetchResult(
                    eventsByTeamId: [:],
                    isComplete: false,
                    failures: [error.localizedDescription]
                )
            }

            for (_, team) in members {
                if Task.isCancelled {
                    aggregate.wasCancelled = true
                    break
                }
                let teamResult = await syncSchedule(
                    for: team,
                    context: context,
                    espn: espn,
                    calendar: calendar,
                    league: league,
                    notifications: notifications,
                    prefetchedFuture: futureResult.eventsByTeamId[team.espnId] ?? [],
                    futureIsComplete: futureResult.isComplete,
                    futureFailures: futureResult.failures,
                    allowsFixtureRemoval: allowsFixtureRemoval,
                    managesSyncState: false
                )
                aggregate.merge(teamResult)
            }
        }
        return aggregate
    }

    /// Pull team schedule from ESPN, diff against stored games, write/update/remove calendar events.
    @discardableResult
    func syncSchedule(
        for team: TrackedTeam,
        context: ModelContext,
        espn: ESPNService,
        calendar: CalendarService,
        league: League,
        notifications: NotificationService? = nil,
        prefetchedFuture: [ESPNEvent]? = nil,
        futureIsComplete: Bool = true,
        futureFailures: [String] = [],
        allowsFixtureRemoval: Bool = true,
        managesSyncState: Bool = true
    ) async -> SyncResult {
        let syncKey = "\(league.slug):\(team.espnId)"
        guard activeSyncKeys.insert(syncKey).inserted else {
            var result = SyncResult()
            result.teamsAttempted = 1
            result.failures = ["\(team.name) is already being refreshed. Try again when that refresh finishes."]
            return result
        }
        defer { activeSyncKeys.remove(syncKey) }

        if managesSyncState { isSyncing = true }
        defer { if managesSyncState { isSyncing = false } }

        print("[SYNC] start team=\(team.espnId) league=\(league.slug)")

        var future: [ESPNEvent] = []
        var past: [ESPNEvent] = []
        var futureComplete = futureIsComplete
        var pastComplete = false
        var failures = futureFailures

        if let prefetchedFuture {
            future = prefetchedFuture
        } else {
            do {
                let result = try await espn.getUpcomingFixturesResult(
                    league: league,
                    teamIds: [team.espnId]
                )
                future = result.eventsByTeamId[team.espnId] ?? []
                futureComplete = result.isComplete
                failures.append(contentsOf: result.failures)
            } catch is CancellationError {
                var result = SyncResult()
                result.teamsAttempted = 1
                result.wasCancelled = true
                return result
            } catch {
                futureComplete = false
                failures.append(error.localizedDescription)
            }
        }
        print("[SYNC] future=\(future.count) complete=\(futureComplete)")

        do {
            past = try await espn.getSchedule(league: league, teamId: team.espnId, useCache: false)
            pastComplete = true
            print("[SYNC] past=\(past.count)")
        } catch is CancellationError {
            var result = SyncResult()
            result.teamsAttempted = 1
            result.wasCancelled = true
            return result
        } catch {
            print("[SYNC] past FAILED: \(error)")
            failures.append(error.localizedDescription)
        }

        var merged: [String: ESPNEvent] = [:]
        for event in past + future { merged[event.id] = event }
        let events = Array(merged.values)
        print("[SYNC] merged=\(events.count) auth=\(calendar.isAuthorized)")

        let snapshots = events.compactMap {
            fixtureSnapshot(from: $0, followedTeamId: team.espnId, league: league, espn: espn)
        }
        let malformedCount = events.count - snapshots.count
        if malformedCount > 0 {
            failures.append("\(team.name) returned \(malformedCount) incomplete fixture record(s); existing games were kept.")
        }

        var result = applyReconciliation(
            fetched: snapshots,
            allowsRemoval: allowsFixtureRemoval && futureComplete && pastComplete && malformedCount == 0,
            team: team,
            league: league,
            context: context,
            calendar: calendar,
            notifications: notifications
        )
        result.teamsAttempted = 1
        result.failures.append(contentsOf: failures.map {
            "\(team.name): \($0)"
        })
        if result.failures.isEmpty {
            result.teamsSucceeded = 1
        }

        lastSyncSummary = "\(team.name) · future=\(future.count) past=\(past.count) changed=\(result.gamesChanged) repairs=\(result.calendarRepairs) auth=\(calendar.isAuthorized ? "y" : "n")"
        print("[SYNC] DONE \(lastSyncSummary)")
        return result
    }

    private func fixtureSnapshot(
        from event: ESPNEvent,
        followedTeamId: String,
        league: League,
        espn: ESPNService
    ) -> FixtureSnapshot? {
        guard let competition = event.competitions.first,
              let home = competition.competitors.first(where: { $0.homeAway == "home" }),
              let away = competition.competitors.first(where: { $0.homeAway == "away" }),
              let kickoff = espn.parseDate(event.date) else { return nil }

        return FixtureSnapshot(
            espnEventId: event.id,
            followedTeamId: followedTeamId,
            leagueSlug: league.slug,
            homeTeamName: home.team.displayName ?? home.team.name ?? "Home",
            homeTeamLogo: home.team.logos?.first?.href,
            awayTeamName: away.team.displayName ?? away.team.name ?? "Away",
            awayTeamLogo: away.team.logos?.first?.href,
            kickoff: kickoff,
            venue: competition.venue?.fullName,
            broadcasts: competition.broadcasts?.flatMap { $0.names ?? [] } ?? [],
            status: event.status?.type?.name
        )
    }

    private func applyReconciliation(
        fetched: [FixtureSnapshot],
        allowsRemoval: Bool,
        team: TrackedTeam,
        league: League,
        context: ModelContext,
        calendar: CalendarService,
        notifications: NotificationService?
    ) -> SyncResult {
        var result = SyncResult()
        let teamId = team.espnId
        let descriptor = FetchDescriptor<TrackedGame>(
            predicate: #Predicate { $0.followedTeamId == teamId }
        )
        let existing: [TrackedGame]
        do {
            existing = try context.fetch(descriptor)
        } catch {
            result.failures.append("Stored fixtures could not be loaded.")
            return result
        }

        var rowsById = Dictionary(uniqueKeysWithValues: existing.map { ($0.espnEventId, $0) })
        let originalIds = Set(rowsById.keys)
        let stored = existing.map { row in
            StoredFixtureSnapshot(
                fixture: snapshot(from: row),
                calendarEventId: row.calendarEventId,
                missingSince: row.missingSince
            )
        }
        let plan = FixtureReconciler().makePlan(
            existing: stored,
            fetched: fetched,
            allowsRemoval: allowsRemoval,
            now: Date()
        )

        for fixture in plan.inserts {
            let row = TrackedGame(
                espnEventId: fixture.espnEventId,
                followedTeamId: fixture.followedTeamId,
                leagueSlug: fixture.leagueSlug,
                homeTeamName: fixture.homeTeamName,
                homeTeamLogo: fixture.homeTeamLogo,
                awayTeamName: fixture.awayTeamName,
                awayTeamLogo: fixture.awayTeamLogo,
                kickoff: fixture.kickoff,
                venue: fixture.venue,
                broadcasts: fixture.broadcasts,
                status: fixture.status
            )
            if calendar.isAuthorized {
                let write = writeCalendarEvent(fixture, identifier: nil, league: league, calendar: calendar)
                row.calendarEventId = write.identifier
                row.calendarSyncPending = !write.succeeded
                if let error = write.errorMessage { result.failures.append(error) }
            } else {
                row.calendarSyncPending = true
            }
            context.insert(row)
            rowsById[fixture.espnEventId] = row
            updateNotification(for: fixture, league: league, notifications: notifications)
            result.added += 1
        }

        for fixture in plan.updates {
            guard let row = rowsById[fixture.espnEventId] else { continue }
            apply(fixture, to: row)
            if calendar.isAuthorized {
                let write = writeCalendarEvent(
                    fixture,
                    identifier: row.calendarEventId,
                    league: league,
                    calendar: calendar
                )
                if write.created { result.calendarRepairs += 1 }
                row.calendarEventId = write.identifier
                row.calendarSyncPending = !write.succeeded
                if let error = write.errorMessage { result.failures.append(error) }
            } else {
                row.calendarSyncPending = true
            }
            updateNotification(for: fixture, league: league, notifications: notifications)
            result.updated += 1
        }

        for id in plan.clearsMissingMarker {
            rowsById[id]?.missingSince = nil
        }
        for (id, date) in plan.marksMissing {
            rowsById[id]?.missingSince = date
        }

        if calendar.isAuthorized {
            for fixture in fetched where originalIds.contains(fixture.espnEventId) {
                guard let row = rowsById[fixture.espnEventId] else { continue }
                let eventExists = calendar.containsEvent(identifier: row.calendarEventId)
                guard CalendarRepairPolicy().needsRepair(
                    syncPending: row.calendarSyncPending,
                    eventExists: eventExists
                ) else { continue }
                let write = writeCalendarEvent(
                    fixture,
                    identifier: row.calendarEventId,
                    league: league,
                    calendar: calendar
                )
                row.calendarEventId = write.identifier
                row.calendarSyncPending = !write.succeeded
                if write.succeeded {
                    result.calendarRepairs += 1
                } else if let error = write.errorMessage {
                    result.failures.append(error)
                }
            }
        }

        let fetchedIDs = Set(fetched.map(\.espnEventId))
        result.calendarWritesPending = rowsById.values.filter {
            fetchedIDs.contains($0.espnEventId) && $0.calendarSyncPending
        }.count

        for stored in plan.removals {
            guard let row = rowsById[stored.fixture.espnEventId] else { continue }
            if let eventId = row.calendarEventId {
                guard calendar.isAuthorized else {
                    result.calendarWritesPending += 1
                    continue
                }
                guard calendar.removeEvent(identifier: eventId) else {
                    result.failures.append(
                        "Calendar could not remove an outdated fixture. Open the app and tap Resync Calendar."
                    )
                    continue
                }
            }
            notifications?.removeGameNotification(
                followedTeamId: team.espnId,
                espnEventId: row.espnEventId
            )
            context.delete(row)
            result.removed += 1
        }

        do {
            try context.save()
        } catch {
            result.failures.append("Fixture changes could not be saved locally.")
        }
        return result
    }

    private func snapshot(from row: TrackedGame) -> FixtureSnapshot {
        FixtureSnapshot(
            espnEventId: row.espnEventId,
            followedTeamId: row.followedTeamId,
            leagueSlug: row.leagueSlug,
            homeTeamName: row.homeTeamName,
            homeTeamLogo: row.homeTeamLogo,
            awayTeamName: row.awayTeamName,
            awayTeamLogo: row.awayTeamLogo,
            kickoff: row.kickoff,
            venue: row.venue,
            broadcasts: row.broadcasts,
            status: row.status
        )
    }

    private func apply(_ fixture: FixtureSnapshot, to row: TrackedGame) {
        row.homeTeamName = fixture.homeTeamName
        row.homeTeamLogo = fixture.homeTeamLogo
        row.awayTeamName = fixture.awayTeamName
        row.awayTeamLogo = fixture.awayTeamLogo
        row.kickoff = fixture.kickoff
        row.venue = fixture.venue
        row.broadcasts = fixture.broadcasts
        row.status = fixture.status
        row.missingSince = nil
        row.lastUpdated = Date()
    }

    private func writeCalendarEvent(
        _ fixture: FixtureSnapshot,
        identifier: String?,
        league: League,
        calendar: CalendarService
    ) -> CalendarEventWriteResult {
        calendar.upsertGame(
            identifier: identifier,
            homeTeam: fixture.homeTeamName,
            awayTeam: fixture.awayTeamName,
            kickoff: fixture.kickoff,
            venue: fixture.venue,
            broadcasts: fixture.broadcasts,
            leagueName: league.displayName,
            status: fixture.status,
            reminderOffset: currentReminderOffset
        )
    }

    private func updateNotification(
        for fixture: FixtureSnapshot,
        league: League,
        notifications: NotificationService?
    ) {
        if fixture.isPostponedOrCancelled {
            notifications?.removeGameNotification(
                followedTeamId: fixture.followedTeamId,
                espnEventId: fixture.espnEventId
            )
        } else {
            notifications?.rescheduleGameNotification(
                homeTeam: fixture.homeTeamName,
                awayTeam: fixture.awayTeamName,
                leagueName: league.displayName,
                kickoff: fixture.kickoff,
                followedTeamId: fixture.followedTeamId,
                espnEventId: fixture.espnEventId,
                reminder: currentReminder
            )
        }
    }
}
