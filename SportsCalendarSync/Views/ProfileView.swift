import SwiftUI
import SwiftData
import EventKit
import UserNotifications
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var calendarService: CalendarService
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var toastManager: ToastManager
    @EnvironmentObject private var teamManager: TeamManager
    @EnvironmentObject private var espn: ESPNService
    @Environment(\.modelContext) private var context
    @Query(sort: \TrackedTeam.name) private var teams: [TrackedTeam]
    @Environment(\.scenePhase) private var scenePhase
    @State private var isSyncing = false
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

            // MARK: - Actions
            if calendarService.isAuthorized {
                Section {
                    Button {
                        isSyncing = true
                        Task {
                            await teamManager.syncAllFollowed(
                                context: context,
                                espn: espn,
                                calendar: calendarService,
                                notifications: notifications
                            )
                            isSyncing = false
                            toastManager.show("Synced \(teams.count) team\(teams.count == 1 ? "" : "s")")
                        }
                    } label: {
                        HStack {
                            Label("Resync Calendar", systemImage: "arrow.triangle.2.circlepath")
                            if isSyncing {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSyncing)
                }
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
            Task { _ = await calendarService.requestAccess() }
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
