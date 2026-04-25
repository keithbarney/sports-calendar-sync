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

        await syncSchedule(
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
    func syncAllFollowed(
        context: ModelContext,
        espn: ESPNService,
        calendar: CalendarService,
        notifications: NotificationService? = nil
    ) async {
        if !calendar.isAuthorized {
            _ = await calendar.requestAccess()
        }
        guard let teams = try? context.fetch(FetchDescriptor<TrackedTeam>()) else { return }
        for team in teams {
            guard let league = team.league else { continue }
            await syncSchedule(
                for: team,
                context: context,
                espn: espn,
                calendar: calendar,
                league: league,
                notifications: notifications
            )
        }
    }

    /// Pull team schedule from ESPN, diff against stored games, write/update/remove calendar events.
    func syncSchedule(
        for team: TrackedTeam,
        context: ModelContext,
        espn: ESPNService,
        calendar: CalendarService,
        league: League,
        notifications: NotificationService? = nil
    ) async {
        isSyncing = true
        defer { isSyncing = false }

        print("[SYNC] start team=\(team.espnId) league=\(league.slug)")

        var future: [ESPNEvent] = []
        var past: [ESPNEvent] = []

        do {
            future = try await espn.getUpcomingFixtures(league: league, teamId: team.espnId)
            print("[SYNC] future=\(future.count)")
        } catch {
            print("[SYNC] future FAILED: \(error)")
        }

        do {
            past = try await espn.getSchedule(league: league, teamId: team.espnId, useCache: false)
            print("[SYNC] past=\(past.count)")
        } catch {
            print("[SYNC] past FAILED: \(error)")
        }

        var merged: [String: ESPNEvent] = [:]
        for event in past + future { merged[event.id] = event }
        let events = Array(merged.values)
        print("[SYNC] merged=\(events.count) auth=\(calendar.isAuthorized)")

        var calendarWrites = 0

        let teamId = team.espnId
        let existingDescriptor = FetchDescriptor<TrackedGame>(
            predicate: #Predicate { $0.followedTeamId == teamId }
        )
        let existing: [TrackedGame] = (try? context.fetch(existingDescriptor)) ?? []
        var existingByEspnId = Dictionary(uniqueKeysWithValues: existing.map { ($0.espnEventId, $0) })

        for event in events {
            guard let competition = event.competitions.first,
                  let home = competition.competitors.first(where: { $0.homeAway == "home" }),
                  let away = competition.competitors.first(where: { $0.homeAway == "away" }),
                  let kickoff = espn.parseDate(event.date) else { continue }

            let homeName = home.team.displayName ?? home.team.name ?? "Home"
            let awayName = away.team.displayName ?? away.team.name ?? "Away"
            let broadcasts = competition.broadcasts?.flatMap { $0.names ?? [] } ?? []

            if let existingGame = existingByEspnId[event.id] {
                // Update if kickoff changed
                if existingGame.kickoff != kickoff {
                    existingGame.kickoff = kickoff
                    existingGame.lastUpdated = Date()
                    if let eventId = existingGame.calendarEventId {
                        calendar.updateGame(
                            identifier: eventId,
                            newKickoff: kickoff,
                            newTitle: "\(homeName) vs. \(awayName)"
                        )
                    }
                    notifications?.rescheduleGameNotification(
                        homeTeam: homeName,
                        awayTeam: awayName,
                        leagueName: league.displayName,
                        kickoff: kickoff,
                        followedTeamId: team.espnId,
                        espnEventId: event.id,
                        reminder: currentReminder
                    )
                }
                existingByEspnId.removeValue(forKey: event.id)
            } else {
                // New game
                let calId = calendar.addGame(
                    homeTeam: homeName,
                    awayTeam: awayName,
                    kickoff: kickoff,
                    venue: competition.venue?.fullName,
                    broadcasts: broadcasts,
                    leagueName: league.displayName,
                    reminderOffset: currentReminderOffset
                )
                if calId != nil { calendarWrites += 1 }
                let tracked = TrackedGame(
                    espnEventId: event.id,
                    followedTeamId: team.espnId,
                    leagueSlug: league.slug,
                    homeTeamName: homeName,
                    homeTeamLogo: home.team.logos?.first?.href,
                    awayTeamName: awayName,
                    awayTeamLogo: away.team.logos?.first?.href,
                    kickoff: kickoff,
                    venue: competition.venue?.fullName,
                    broadcasts: broadcasts,
                    status: event.status?.type?.name
                )
                tracked.calendarEventId = calId
                context.insert(tracked)
                notifications?.scheduleGameNotification(
                    homeTeam: homeName,
                    awayTeam: awayName,
                    leagueName: league.displayName,
                    kickoff: kickoff,
                    followedTeamId: team.espnId,
                    espnEventId: event.id,
                    reminder: currentReminder
                )
            }
        }

        // Anything left in `existingByEspnId` was removed from ESPN — clean it up.
        for (_, stale) in existingByEspnId {
            if let id = stale.calendarEventId { calendar.removeEvent(identifier: id) }
            notifications?.removeGameNotification(
                followedTeamId: team.espnId,
                espnEventId: stale.espnEventId
            )
            context.delete(stale)
        }

        try? context.save()

        lastSyncSummary = "\(team.name) · future=\(future.count) past=\(past.count) merged=\(events.count) calWrites=\(calendarWrites) auth=\(calendar.isAuthorized ? "y" : "n")"
        print("[SYNC] DONE \(lastSyncSummary)")
    }
}
