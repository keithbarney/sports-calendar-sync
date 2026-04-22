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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                section(title: "Appearance") {
                    VStack(spacing: 0) {
                        ForEach(AppearanceMode.allCases) { mode in
                            SettingsRow(
                                icon: icon(for: mode),
                                label: mode.label,
                                isSelected: appSettings.appearanceMode == mode
                            ) {
                                appSettings.appearanceMode = mode
                            }
                        }
                    }
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }

                section(title: "Teams (\(followed.count))") {
                    if followed.isEmpty {
                        Text("Not following any teams yet.")
                            .font(.subheadline)
                            .foregroundStyle(.textSecondary)
                            .padding(.horizontal, 16)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(followed) { team in
                                SettingsRow(
                                    icon: "sparkles",
                                    label: "\(team.name) — \(team.league?.shortName ?? "")",
                                    isSelected: false
                                )
                            }
                        }
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    }
                }

                section(title: "Calendar") {
                    VStack(spacing: 0) {
                        if !calendar.isAuthorized {
                            SettingsRow(icon: "calendar-plus", label: "Grant calendar access") {
                                Task {
                                    let granted = await calendar.requestAccess()
                                    if granted { await syncAll() }
                                }
                            }
                        } else {
                            SettingsRow(
                                icon: isSyncing ? "sparkles" : "calendar-check",
                                label: isSyncing ? "Syncing fixtures…" : "Sync all fixtures now"
                            ) {
                                Task { await syncAll() }
                            }
                            SettingsRow(icon: "trash-2", label: "Remove all calendar events") {
                                let n = calendar.removeAllEvents()
                                toast.show("Removed \(n) events", icon: "minus.circle.fill", isDestructive: true)
                            }
                        }
                    }
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }

                section(title: "About") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sports Calendar Sync")
                            .font(.system(size: 16))
                            .foregroundStyle(.textPrimary)
                        Text("Version 1.0")
                            .font(.system(size: 12))
                            .foregroundStyle(.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.background)
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .sectionHeader()
                .padding(.horizontal, 16)
            content()
        }
    }

    private func icon(for mode: AppearanceMode) -> String {
        switch mode {
        case .system: return "contrast"
        case .light:  return "sun"
        case .dark:   return "moon"
        }
    }

    private func syncAll() async {
        isSyncing = true
        defer { isSyncing = false }
        await teamManager.syncAllFollowed(context: context, espn: espn, calendar: calendar)
        toast.show("Synced \(followed.count) team(s)")
    }
}
