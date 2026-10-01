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
    private let preferences: UserDefaults
    private var reminderReconciliationGeneration = 0
    private var reminderReconciliationTail: Task<SyncResult, Never>?

    init(preferences: UserDefaults? = nil) {
        self.preferences = preferences ?? AppSettings.preferenceDefaults()
    }

    /// Resolve the current kickoff-reminder preference from the same isolated
    /// store used by AppSettings.
    private var currentReminder: KickoffReminder {
        let raw = preferences.string(forKey: "kickoffReminder") ?? KickoffReminder.thirtyMin.rawValue
        return KickoffReminder(rawValue: raw) ?? .thirtyMin
    }

    private var currentReminderOffset: TimeInterval? {
        currentReminder.offsetSeconds
    }

    /// Repair pre-time-zone-fix notifications locally, without Calendar writes
    /// or an ESPN request. Unchanged fixtures also need this upgrade repair.
    func repairLegacyNotifications(
        context: ModelContext,
        notifications: NotificationService
    ) async -> SyncResult {
        var result = SyncResult()
        do {
            let games = try context.fetch(FetchDescriptor<TrackedGame>())
            let write = await notifications.repairLegacyGameNotifications(
                fixtures: games.map { snapshot(from: $0) },
                reminder: currentReminder
            )
            if let error = write.errorMessage, !write.succeeded {
                result.failures.append(error)
            }
        } catch {
            result.failures.append("Stored fixtures could not be loaded to repair kickoff reminders.")
        }
        return result
    }

    /// Immediately rewrite every existing app-owned calendar alarm and pending
    /// notification after the reminder preference changes.
    @discardableResult
    func reconcileReminderPreference(
        context: ModelContext,
        calendar: CalendarFixtureScheduling,
        notifications: ReminderNotificationScheduling? = nil
    ) async -> SyncResult {
        let reminder = currentReminder
        reminderReconciliationGeneration += 1
        let generation = reminderReconciliationGeneration
        let predecessor = reminderReconciliationTail
        let operation = Task { @MainActor [weak self] in
            _ = await predecessor?.value
            guard let self else {
                var result = SyncResult()
                result.wasCancelled = true
                return result
            }
            guard generation == self.reminderReconciliationGeneration else {
                var result = SyncResult()
                result.wasCancelled = true
                return result
            }
            let result = await self.performReminderReconciliation(
                reminder: reminder,
                context: context,
                calendar: calendar,
                notifications: notifications
            )
            guard generation == self.reminderReconciliationGeneration else {
                var superseded = result
                superseded.wasCancelled = true
                return superseded
            }
            return result
        }
        reminderReconciliationTail = operation
        return await operation.value
    }

    private func performReminderReconciliation(
        reminder: KickoffReminder,
        context: ModelContext,
        calendar: CalendarFixtureScheduling,
        notifications: ReminderNotificationScheduling?
    ) async -> SyncResult {
        var result = SyncResult()
        let games: [TrackedGame]
        do {
            games = try context.fetch(FetchDescriptor<TrackedGame>())
        } catch {
            result.failures = ["Stored fixtures could not be loaded for reminder update."]
            return result
        }
        result.teamsAttempted = games.count

        for game in games {
            guard let league = Competition(rawValue: game.leagueSlug) else {
                result.failures.append("A stored fixture has an unsupported competition and could not be updated.")
                continue
            }
            if calendar.isAuthorized {
                let write = calendar.upsertGame(
                    identifier: game.calendarEventId,
                    fixtureIdentity: "\(game.leagueSlug)|\(game.followedTeamId)|\(game.espnEventId)",
                    homeTeam: game.homeTeamName,
                    awayTeam: game.awayTeamName,
                    kickoff: game.kickoff,
                    venue: game.venue,
                    broadcasts: game.broadcasts,
                    leagueName: league.displayName,
                    status: game.status,
                    reminderOffset: reminder.offsetSeconds
                )
                game.calendarEventId = write.identifier ?? game.calendarEventId
                game.calendarSyncPending = !write.succeeded
                if let error = write.errorMessage { result.failures.append(error) }
                if !write.succeeded { result.calendarWritesPending += 1 }
            } else {
                game.calendarSyncPending = true
                result.calendarWritesPending += 1
            }

            if let notifications {
                let notificationResult = await notifications.reconcileGameNotification(
                    homeTeam: game.homeTeamName,
                    awayTeam: game.awayTeamName,
                    leagueName: league.displayName,
                    kickoff: game.kickoff,
                    followedTeamId: game.followedTeamId,
                    espnEventId: game.espnEventId,
                    reminder: notificationReminder(for: game, selected: reminder)
                )
                if let error = notificationResult.errorMessage, !notificationResult.succeeded {
                    result.failures.append(error)
                }
            }
            result.updated += 1
        }

        do {
            try context.save()
        } catch {
            result.failures.append("Reminder changes could not be saved locally.")
        }
        if result.failures.isEmpty && result.calendarWritesPending == 0 {
            result.teamsSucceeded = result.teamsAttempted
        }
        return result
    }

    private func notificationReminder(
        for game: TrackedGame,
        selected reminder: KickoffReminder
    ) -> KickoffReminder {
        guard let status = game.status?.uppercased() else { return reminder }
        return status.contains("POSTPONED") || status.contains("CANCELED") || status.contains("CANCELLED")
            ? .off
            : reminder
    }

    /// Follow a team: persist + immediately fetch & mirror schedule to Calendar.
    @discardableResult
    func follow(
        espnTeam: ESPNTeam,
        league: League,
        context: ModelContext,
        espn: ESPNService,
        calendar: CalendarService,
        notifications: NotificationService? = nil
    ) async -> Bool {
        // Dedupe
        let id = espnTeam.id
        let slug = league.slug
        let descriptor = FetchDescriptor<TrackedTeam>(
            predicate: #Predicate { $0.espnId == id && $0.leagueSlug == slug }
        )
        if let existing = try? context.fetch(descriptor), !existing.isEmpty { return false }

        let team = TrackedTeam(
            espnId: espnTeam.id,
            leagueSlug: league.slug,
            name: espnTeam.displayName ?? espnTeam.name ?? "Unknown",
            shortDisplayName: espnTeam.shortDisplayName,
            abbreviation: espnTeam.abbreviation,
            logoURL: espnTeam.crestURL,
            primaryColor: espnTeam.color
        )
        context.insert(team)
        try? context.save()
        WidgetSnapshotPublisher.publish(context: context)

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
        return true
    }

    /// Follow one club in several competition feeds. ESPN may use a different team
    /// record for a cup, so resolve each competition by the club's name before syncing.
    @discardableResult
    func followAcrossCompetitions(
        espnTeam: ESPNTeam,
        sourceCompetition: Competition,
        competitions: [Competition],
        context: ModelContext,
        espn: ESPNService,
        calendar: CalendarService,
        notifications: NotificationService? = nil
    ) async -> (added: Int, failed: [Competition]) {
        var added = 0
        var failed: [Competition] = []

        for competition in competitions {
            let candidate: ESPNTeam?
            if competition == sourceCompetition {
                candidate = espnTeam
            } else if let teams = try? await espn.getTeams(league: competition) {
                candidate = teams.first(where: { $0.matchesClub(espnTeam) })
            } else {
                candidate = nil
            }

            guard let candidate else {
                failed.append(competition)
                continue
            }
            if await follow(
                espnTeam: candidate,
                league: competition,
                context: context,
                espn: espn,
                calendar: calendar,
                notifications: notifications
            ) {
                added += 1
            }
        }

        return (added, failed)
    }

    func unfollow(
        team: TrackedTeam,
        context: ModelContext,
        calendar: CalendarService,
        notifications: NotificationService? = nil
    ) {
        // Remove mirrored calendar events for this team
        let id = team.espnId
        let slug = team.leagueSlug
        let descriptor = FetchDescriptor<TrackedGame>(
            predicate: #Predicate { $0.followedTeamId == id && $0.leagueSlug == slug }
        )
        if let games = try? context.fetch(descriptor) {
            let ids = games.compactMap { $0.calendarEventId }
            calendar.removeEvents(identifiers: ids)
            games.forEach { context.delete($0) }
        }
        notifications?.removeAllNotifications(followedTeamId: id)
        context.delete(team)
        try? context.save()
        WidgetSnapshotPublisher.publish(context: context)
    }

    /// Stop syncing one competition while retaining its existing calendar events and
    /// stored fixture history. The user can still remove those events by unfollowing
    /// the entire club.
    func stopFollowingCompetition(
        team: TrackedTeam,
        context: ModelContext,
        notifications: NotificationService? = nil
    ) {
        let id = team.espnId
        let slug = team.leagueSlug
        let descriptor = FetchDescriptor<TrackedGame>(
            predicate: #Predicate { $0.followedTeamId == id && $0.leagueSlug == slug }
        )
        if let games = try? context.fetch(descriptor) {
            for game in games {
                notifications?.removeGameNotification(
                    followedTeamId: game.followedTeamId,
                    espnEventId: game.espnEventId
                )
            }
        }
        context.delete(team)
        try? context.save()
        WidgetSnapshotPublisher.publish(context: context)
    }

    /// Sync every followed team's schedule. Sync adds new fixtures and updates existing ones;
    /// it never removes fixtures. Explicit unfollow actions still remove that team's events.
    @discardableResult
    func syncAllFollowed(
        context: ModelContext,
        espn: ESPNService,
        calendar: CalendarService,
        notifications: NotificationService? = nil,
        requestCalendarAccess: Bool = true,
        weeksAhead: Int = 16,
        allowsFixtureRemoval: Bool = false
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

    /// Pull team schedule from ESPN, diff against stored games, and write/update calendar events.
    /// Existing fixtures are retained even when ESPN omits them from a response.
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
        allowsFixtureRemoval: Bool = false,
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
            homeTeamLogo: home.team.crestURL,
            awayTeamName: away.team.displayName ?? away.team.name ?? "Away",
            awayTeamLogo: away.team.crestURL,
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
        let competitionSlug = league.slug
        let descriptor = FetchDescriptor<TrackedGame>(
            predicate: #Predicate { $0.followedTeamId == teamId && $0.leagueSlug == competitionSlug }
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
        let originalKickoffs = Dictionary(uniqueKeysWithValues: existing.map { ($0.espnEventId, $0.kickoff) })
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
            if calendar.canSyncCalendar {
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
            if calendar.canSyncCalendar {
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

        if calendar.canSyncCalendar {
            for fixture in fetched where originalIds.contains(fixture.espnEventId) {
                guard let row = rowsById[fixture.espnEventId] else { continue }
                let resolvedIdentifier = calendar.resolveEventIdentifier(
                    identifier: row.calendarEventId,
                    fixtureIdentity: calendarFixtureIdentity(for: fixture),
                    kickoff: fixture.kickoff,
                    previousKickoff: originalKickoffs[fixture.espnEventId]
                )
                if let resolvedIdentifier {
                    row.calendarEventId = resolvedIdentifier
                }
                guard CalendarRepairPolicy().needsRepair(
                    syncPending: row.calendarSyncPending,
                    eventExists: resolvedIdentifier != nil
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
                guard calendar.canSyncCalendar else {
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
            WidgetSnapshotPublisher.publish(context: context)
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
            fixtureIdentity: calendarFixtureIdentity(for: fixture),
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

    private func calendarFixtureIdentity(for fixture: FixtureSnapshot) -> String {
        "\(fixture.leagueSlug)|\(fixture.followedTeamId)|\(fixture.espnEventId)"
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
