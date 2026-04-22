import SwiftUI
import SwiftData

struct ProfileView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var toast: ToastManager
    @EnvironmentObject var teamManager: TeamManager
    @EnvironmentObject var espn: ESPNService
    @Environment(\.modelContext) private var context
    @Query private var followed: [TrackedTeam]
    @State private var isSyncing = false

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Appearance", selection: Binding(
                        get: { appSettings.appearanceMode },
                        set: { appSettings.appearanceMode = $0 }
                    )) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Followed teams (\(followed.count))") {
                    if followed.isEmpty {
                        Text("No teams yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(followed) { team in
                            HStack {
                                Text(team.name)
                                Spacer()
                                if let league = team.league {
                                    Text(league.shortName).foregroundStyle(.secondary).font(.caption)
                                }
                            }
                        }
                    }
                }

                Section("Calendar") {
                    if !calendar.isAuthorized {
                        Button("Grant calendar access") {
                            Task {
                                let granted = await calendar.requestAccess()
                                if granted {
                                    await syncAll()
                                }
                            }
                        }
                    } else {
                        Text("Sports calendar connected")
                            .foregroundStyle(.secondary)
                        Button {
                            Task { await syncAll() }
                        } label: {
                            HStack {
                                Text(isSyncing ? "Syncing fixtures…" : "Sync all fixtures now")
                                if isSyncing {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isSyncing)

                        Button(role: .destructive) {
                            let n = calendar.removeAllEvents()
                            toast.show("Removed \(n) events", style: .success)
                        } label: {
                            Text("Remove all calendar events")
                        }
                    }
                }

                Section("About") {
                    Text("Sports Calendar Sync")
                    Text("Version 1.0").foregroundStyle(.secondary).font(.caption)
                }
            }
            .navigationTitle("Profile")
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func syncAll() async {
        isSyncing = true
        defer { isSyncing = false }
        await teamManager.syncAllFollowed(context: context, espn: espn, calendar: calendar)
        toast.show("Synced \(followed.count) team(s)", style: .success)
    }
}
