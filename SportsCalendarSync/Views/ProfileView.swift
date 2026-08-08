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
                            SettingsRowLabel(title: reminder.rawValue, systemImage: reminder.sfSymbol)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            if appSettings.kickoffReminder == reminder {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.textPrimary)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
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
                            if result.gamesChanged == 0 {
                                toastManager.show("Calendar is up to date")
                            } else {
                                toastManager.show(
                                    "Sync complete — \(result.gamesChanged) game\(result.gamesChanged == 1 ? "" : "s") changed"
                                )
                            }
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
                                .foregroundStyle(Color.textSecondary)
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
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appSettings.appearanceMode = mode
                        }
                    } label: {
                        HStack {
                            SettingsRowLabel(title: mode.rawValue, systemImage: mode.sfSymbol)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            if appSettings.appearanceMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.textPrimary)
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
                tint: Color.textSecondary
            )
            VStack(alignment: .leading, spacing: 3) {
                Text("Last successful refresh")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                Text(lastRefresh ?? "No completed sync yet")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
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
                    .foregroundStyle(Color.textPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            if let dismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textSecondary)
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

private struct SettingsRowLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: SettingsRowLayout.iconTextSpacing) {
            SettingsRowIcon(systemImage: systemImage)
            Text(title)
        }
    }
}

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
            SettingsRowLabel(title: title, systemImage: sfSymbol)
                .foregroundStyle(Color.textPrimary)
        }
    }
}
