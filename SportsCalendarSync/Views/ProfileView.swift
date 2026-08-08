import SwiftUI
import EventKit
import UserNotifications
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var calendarService: CalendarService
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var toastManager: ToastManager
    @EnvironmentObject private var syncHealth: SyncHealthStore
    @EnvironmentObject private var automaticRefresh: AutomaticRefreshService
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            // MARK: - Kickoff Reminders
            Section("Kickoff Reminders") {
                ForEach(KickoffReminder.allCases, id: \.self) { reminder in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appSettings.kickoffReminder = reminder
                        }
                    } label: {
                        HStack {
                            Label(reminder.rawValue, systemImage: reminder.sfSymbol)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            if appSettings.kickoffReminder == reminder {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }

            // MARK: - Calendar Sync
            Section("Calendar Sync") {
                SyncHealthRow(
                    label: "Last successful sync",
                    value: formatted(syncHealth.lastSuccessfulSync, fallback: "Not yet")
                )
                if syncHealth.lastSuccessfulSync != nil {
                    SyncHealthRow(
                        label: "Games changed",
                        value: "\(syncHealth.lastGamesUpdated)"
                    )
                    Text(
                        "\(syncHealth.lastAdded) added · \(syncHealth.lastChanged) changed · "
                        + "\(syncHealth.lastRemoved) removed"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                }
                if let next = syncHealth.nextPlannedRefresh {
                    SyncHealthRow(
                        label: "Refresh requested after",
                        value: formatted(next, fallback: "Unknown")
                    )
                    Text("iOS chooses whether and when background refresh runs.")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                if syncHealth.lastCalendarRepairs > 0 {
                    Label(
                        "Repaired \(syncHealth.lastCalendarRepairs) calendar event\(syncHealth.lastCalendarRepairs == 1 ? "" : "s").",
                        systemImage: "wrench.and.screwdriver"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                }
                if let guidance = capabilityRepairGuidance {
                    SyncWarning(message: guidance)
                    if showsSystemSettingsRepairAction {
                        Button("Open iOS Settings", action: openSettings)
                    }
                }
                if let lastError = syncHealth.lastError {
                    SyncWarning(message: lastError)
                }
                if let schedulingError = syncHealth.backgroundSchedulingError {
                    SyncWarning(message: schedulingError)
                }
                if let registrationError = syncHealth.backgroundRegistrationError {
                    SyncWarning(message: registrationError)
                }

                Button {
                    Task {
                        let result = await automaticRefresh.manualRefresh()
                        if let result, result.isSuccessful {
                            if result.gamesChanged == 0 {
                                toastManager.show("Calendar is up to date")
                            } else {
                                toastManager.show(
                                    "Changed \(result.gamesChanged) game\(result.gamesChanged == 1 ? "" : "s")"
                                )
                            }
                        } else if let result, result.calendarWritesPending > 0 {
                            toastManager.show("Fixtures downloaded — Calendar needs repair")
                        } else {
                            toastManager.show("Refresh incomplete — existing games were kept")
                        }
                    }
                } label: {
                    HStack {
                        Label("Resync Calendar", systemImage: "arrow.triangle.2.circlepath")
                        if automaticRefresh.isRefreshing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(automaticRefresh.isRefreshing)
            }

            // MARK: - Appearance
            Section("Appearance") {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appSettings.appearanceMode = mode
                        }
                    } label: {
                        HStack {
                            Label(mode.rawValue, systemImage: mode.sfSymbol)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            if appSettings.appearanceMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }

            // MARK: - Permissions
            Section("Permissions") {
                PermissionRow(
                    title: "Calendar",
                    sfSymbol: "calendar",
                    state: calendarPermissionState,
                    action: handleCalendarTap
                )
                PermissionRow(
                    title: "Notifications",
                    sfSymbol: "bell",
                    state: notificationPermissionState,
                    action: handleNotificationTap
                )
            }

            // MARK: - About
            Section {
                HStack {
                    Text("Version")
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text("\(Bundle.main.marketingVersion) (\(Bundle.main.buildNumber))")
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .navigationTitle("Settings")
        .task { await refreshNotificationStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                calendarService.checkAuthorization()
                Task { await refreshNotificationStatus() }
            }
        }
    }

    // MARK: - Permission state

    private var calendarPermissionState: PermissionState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    private var notificationPermissionState: PermissionState {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    private func handleCalendarTap() {
        switch calendarPermissionState {
        case .granted, .denied:
            openSettings()
        case .notDetermined:
            Task {
                if await calendarService.requestAccess() {
                    await automaticRefresh.refreshIfNeeded(trigger: .permissionGranted)
                }
            }
        }
    }

    private func handleNotificationTap() {
        switch notificationPermissionState {
        case .granted, .denied:
            openSettings()
        case .notDetermined:
            Task {
                _ = await notifications.requestAccess()
                await refreshNotificationStatus()
            }
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run { notificationStatus = settings.authorizationStatus }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var capabilityRepairGuidance: String? {
        if !calendarService.isAuthorized {
            return "Calendar access is off. Enable it in Settings, then tap Resync Calendar."
        }
        switch UIApplication.shared.backgroundRefreshStatus {
        case .denied:
            return "Background App Refresh is off. Enable it in Settings for automatic updates."
        case .restricted:
            return "Background refresh is restricted on this device. Launch and manual refresh will still work."
        case .available:
            break
        @unknown default:
            break
        }
        return nil
    }

    private var showsSystemSettingsRepairAction: Bool {
        !calendarService.isAuthorized || UIApplication.shared.backgroundRefreshStatus == .denied
    }

    private func formatted(_ date: Date?, fallback: String) -> String {
        guard let date else { return fallback }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct SyncWarning: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .foregroundStyle(Color.textPrimary)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

private struct SyncHealthRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let label: String
    let value: String

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    labelText
                    valueText
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    labelText
                    Spacer()
                    valueText
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }

    private var labelText: some View {
        Text(label)
            .foregroundStyle(Color.textPrimary)
    }

    private var valueText: some View {
        Text(value)
            .foregroundStyle(Color.textSecondary)
    }
}

// MARK: - Permission Row

enum PermissionState {
    case granted, notDetermined, denied
}

private struct PermissionRow: View {
    let title: String
    let sfSymbol: String
    let state: PermissionState
    let action: () -> Void

    private var binding: Binding<Bool> {
        Binding(
            get: { state == .granted },
            set: { _ in action() }
        )
    }

    var body: some View {
        Toggle(isOn: binding) {
            Label(title, systemImage: sfSymbol)
                .foregroundStyle(Color.textPrimary)
        }
    }
}
