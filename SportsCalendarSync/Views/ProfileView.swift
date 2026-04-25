import SwiftUI
import SwiftData

struct ProfileView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var calendarService: CalendarService
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var toastManager: ToastManager
    @EnvironmentObject private var teamManager: TeamManager
    @EnvironmentObject private var espn: ESPNService
    @Environment(\.modelContext) private var context
    @Query(sort: \TrackedTeam.name) private var teams: [TrackedTeam]
    @State private var isSyncing = false

    var body: some View {
        Form {
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
    }
}
