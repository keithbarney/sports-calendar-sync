import Foundation

enum SyncTrigger: String, Codable, Equatable {
    case launch
    case foreground
    case background
    case manual
    case permissionGranted

    var isAutomatic: Bool {
        switch self {
        case .launch, .foreground, .background:
            return true
        case .manual, .permissionGranted:
            return false
        }
    }
}

struct SyncResult: Equatable {
    var teamsAttempted = 0
    var teamsSucceeded = 0
    var added = 0
    var updated = 0
    var removed = 0
    var calendarRepairs = 0
    var calendarWritesPending = 0
    var failures: [String] = []
    var wasCancelled = false

    var gamesChanged: Int {
        added + updated + removed
    }

    var isSuccessful: Bool {
        !wasCancelled && failures.isEmpty && teamsAttempted == teamsSucceeded && calendarWritesPending == 0
    }

    var manualRefreshMessage: String {
        if calendarRepairs > 0 {
            return "Calendar repaired — \(calendarRepairs) event\(calendarRepairs == 1 ? "" : "s")"
        }
        if gamesChanged == 0 {
            return "Calendar is up to date"
        }
        return "Sync complete — \(gamesChanged) game\(gamesChanged == 1 ? "" : "s") changed"
    }

    mutating func merge(_ other: SyncResult) {
        teamsAttempted += other.teamsAttempted
        teamsSucceeded += other.teamsSucceeded
        added += other.added
        updated += other.updated
        removed += other.removed
        calendarRepairs += other.calendarRepairs
        calendarWritesPending += other.calendarWritesPending
        failures.append(contentsOf: other.failures)
        wasCancelled = wasCancelled || other.wasCancelled
    }
}

struct RefreshPolicy: Equatable {
    var minimumAutomaticInterval: TimeInterval = 15 * 60
    var backgroundRefreshInterval: TimeInterval = 6 * 60 * 60

    func shouldRefresh(trigger: SyncTrigger, lastAttempt: Date?, now: Date) -> Bool {
        guard trigger.isAutomatic else { return true }
        guard let lastAttempt else { return true }
        return now.timeIntervalSince(lastAttempt) >= minimumAutomaticInterval
    }

    func nextBackgroundRefresh(after date: Date) -> Date {
        date.addingTimeInterval(backgroundRefreshInterval)
    }
}

struct FixtureSnapshot: Equatable {
    let espnEventId: String
    let followedTeamId: String
    let leagueSlug: String
    let homeTeamName: String
    let homeTeamLogo: String?
    let awayTeamName: String
    let awayTeamLogo: String?
    let kickoff: Date
    let venue: String?
    let broadcasts: [String]
    let status: String?

    var title: String {
        "\(homeTeamName) vs. \(awayTeamName)"
    }

    var isPostponedOrCancelled: Bool {
        guard let status = status?.uppercased() else { return false }
        return status.contains("POSTPONED") || status.contains("CANCELED") || status.contains("CANCELLED")
    }
}

struct StoredFixtureSnapshot: Equatable {
    let fixture: FixtureSnapshot
    let calendarEventId: String?
    let missingSince: Date?
}

struct FixtureReconciliationPlan: Equatable {
    var inserts: [FixtureSnapshot] = []
    var updates: [FixtureSnapshot] = []
    var clearsMissingMarker: [String] = []
    var marksMissing: [String: Date] = [:]
    var removals: [StoredFixtureSnapshot] = []
}

struct FixtureReconciler {
    var removalGracePeriod: TimeInterval = 24 * 60 * 60

    func makePlan(
        existing: [StoredFixtureSnapshot],
        fetched: [FixtureSnapshot],
        allowsRemoval: Bool,
        now: Date
    ) -> FixtureReconciliationPlan {
        var plan = FixtureReconciliationPlan()
        var existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.fixture.espnEventId, $0) })

        for fixture in fetched {
            guard let stored = existingById.removeValue(forKey: fixture.espnEventId) else {
                plan.inserts.append(fixture)
                continue
            }

            if stored.fixture != fixture {
                plan.updates.append(fixture)
            }
            if stored.missingSince != nil {
                plan.clearsMissingMarker.append(fixture.espnEventId)
            }
        }

        guard allowsRemoval else { return plan }

        for stored in existingById.values {
            guard let missingSince = stored.missingSince else {
                plan.marksMissing[stored.fixture.espnEventId] = now
                continue
            }
            if now.timeIntervalSince(missingSince) >= removalGracePeriod {
                plan.removals.append(stored)
            }
        }

        return plan
    }
}

struct CalendarRepairPolicy {
    func needsRepair(syncPending: Bool, eventExists: Bool) -> Bool {
        syncPending || !eventExists
    }
}
