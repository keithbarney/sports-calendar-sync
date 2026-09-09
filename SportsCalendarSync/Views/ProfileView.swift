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
                Picker("Reminder", selection: $appSettings.kickoffReminder) {
                    ForEach(KickoffReminder.allCases, id: \.self) { reminder in
                        Label(reminder.rawValue, systemImage: reminder.sfSymbol).tag(reminder)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            // MARK: - Calendar Sync
            Section("Calendar Sync") {
                SyncRefreshSummary(
                    lastRefresh: syncHealth.lastSuccessfulSync.map { formatted($0, fallback: "") }
                )

                if let repairs = syncHealth.calendarRepairBannerCount {
                    SyncFeedbackBanner(
                        tone: .success,
                        title: "Calendar repaired",
                        message: "Repaired \(repairs) event\(repairs == 1 ? "" : "s") during the latest sync.",
                        dismiss: syncHealth.dismissCalendarRepairBanner
                    )
                }
                if let guidance = capabilityRepairGuidance {
                    SyncFeedbackBanner(
                        tone: .warning,
                        title: capabilityRepairTitle,
                        message: guidance
                    )
                    if showsSystemSettingsRepairAction {
                        Button("Open iOS Settings", action: openSettings)
                    }
                }
                if let lastError = syncHealth.lastError {
                    SyncFeedbackBanner(
                        tone: .warning,
                        title: "Sync needs attention",
                        message: lastError,
                        dismiss: syncHealth.dismissLastError
                    )
                }
                if let schedulingError = syncHealth.backgroundSchedulingError {
                    SyncFeedbackBanner(
                        tone: .warning,
                        title: "Automatic refresh unavailable",
                        message: schedulingError,
                        dismiss: syncHealth.dismissBackgroundSchedulingError
                    )
                }
                if let registrationError = syncHealth.backgroundRegistrationError {
                    SyncFeedbackBanner(
                        tone: .warning,
                        title: "Automatic refresh unavailable",
                        message: registrationError,
                        dismiss: syncHealth.dismissBackgroundRegistrationError
                    )
                }

                Button {
                    Task {
                        let result = await automaticRefresh.manualRefresh()
                        if let result, result.isSuccessful {
                            toastManager.show(result.manualRefreshMessage)
                        } else if let result, result.calendarWritesPending > 0 {
                            toastManager.show("Fixtures downloaded — Calendar needs repair")
                        } else {
                            toastManager.show("Refresh incomplete — existing games were kept")
                        }
                    }
                } label: {
                    HStack(spacing: SettingsRowLayout.iconTextSpacing) {
                        SettingsRowIcon(
                            systemImage: "arrow.triangle.2.circlepath",
                            tint: Color.accentColor
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(automaticRefresh.isRefreshing ? "Syncing Calendar" : "Sync Calendar Now")
                            Text("Refresh fixtures and repair calendar events")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if automaticRefresh.isRefreshing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(automaticRefresh.isRefreshing)
                .accessibilityLabel(automaticRefresh.isRefreshing ? "Syncing Calendar" : "Sync Calendar Now")
                .accessibilityHint("Refresh fixtures and repair calendar events")
            }

            // MARK: - Appearance
            Section("Appearance") {
                Picker("Appearance", selection: $appSettings.appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.sfSymbol).tag(mode)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            // MARK: - Permissions
            Section {
                LabeledContent("Calendar", value: calendarPermissionState.label)
                LabeledContent("Notifications", value: notificationPermissionState.label)
                if calendarPermissionState == .notDetermined {
                    Button("Enable Calendar Access", action: handleCalendarTap)
                }
                if notificationPermissionState == .notDetermined {
                    Button("Enable Notifications", action: handleNotificationTap)
                }
                Button("Open iOS Settings", action: openSettings)
            } header: {
                Text("Permissions")
            } footer: {
                Text("Manage calendar and notification access in iOS Settings.")
            }

            Section("About") {
                LabeledContent("Version", value: "\(Bundle.main.marketingVersion) (\(Bundle.main.buildNumber))")
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
            return "Calendar access is off. Enable it in Settings, then choose Sync Calendar Now."
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

    private var capabilityRepairTitle: String {
        calendarService.isAuthorized ? "Background refresh unavailable" : "Calendar access needed"
    }

    private var showsSystemSettingsRepairAction: Bool {
        !calendarService.isAuthorized || UIApplication.shared.backgroundRefreshStatus == .denied
    }

    private func formatted(_ date: Date?, fallback: String) -> String {
        guard let date else { return fallback }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct SyncRefreshSummary: View {
    let lastRefresh: String?

    var body: some View {
        HStack(spacing: SettingsRowLayout.iconTextSpacing) {
            SettingsRowIcon(
                systemImage: "clock.arrow.circlepath",
                tint: .secondary
            )
            VStack(alignment: .leading, spacing: 3) {
                Text("Last successful refresh")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(lastRefresh ?? "No completed sync yet")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SyncFeedbackBanner: View {
    enum Tone {
        case success
        case warning

        var icon: String {
            switch self {
            case .success: return "wrench.and.screwdriver"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            }
        }
    }

    let tone: Tone
    let title: String
    let message: String
    let dismiss: (() -> Void)?

    init(tone: Tone, title: String, message: String, dismiss: (() -> Void)? = nil) {
        self.tone = tone
        self.title = title
        self.message = message
        self.dismiss = dismiss
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: tone.icon)
                .foregroundStyle(tone.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            if let dismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss \(title)")
            }
        }
        .accessibilityElement(children: dismiss == nil ? .combine : .contain)
    }
}

// MARK: - Permission Row

private enum SettingsRowLayout {
    static let iconSize: CGFloat = 24
    static let iconTextSpacing: CGFloat = 23
}

private struct SettingsRowIcon: View {
    let systemImage: String
    var tint: Color? = nil

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 20))
            .frame(width: SettingsRowLayout.iconSize, height: SettingsRowLayout.iconSize)
            .foregroundStyle(tint ?? .primary)
            .accessibilityHidden(true)
    }
}

enum PermissionState {
    case granted, notDetermined, denied

    var label: String {
        switch self {
        case .granted: return "Allowed"
        case .notDetermined: return "Not requested"
        case .denied: return "Off"
        }
    }
}
