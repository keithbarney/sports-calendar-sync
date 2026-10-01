#if DEBUG
import SwiftUI
import SwiftData

/// Each scenario retains its own in-memory store. Personal persistence is never opened.
struct MockReviewView: View {
    @State private var scenario: MockReviewScenario = .typical
    @State private var containers: [MockReviewScenario: ModelContainer]

    init(initialContainer: ModelContainer) {
        let initialScenario = ScreenshotFixtures.launchScenario
        _scenario = State(initialValue: initialScenario)
        _containers = State(initialValue: [initialScenario: initialContainer])
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Mock data", systemImage: "testtube.2")
                Spacer()
                Picker("Review scenario", selection: Binding(
                    get: { scenario },
                    set: { selection in
                        if containers[selection] == nil {
                            containers[selection] = SportsCalendarSyncApp.makeModelContainer(
                                emptyScreenshotScenario: selection == .empty,
                                mockScenario: selection
                            )
                        }
                        scenario = selection
                    }
                )) {
                    ForEach(MockReviewScenario.allCases) { scenario in
                        Text(scenario.rawValue).tag(scenario)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("mock-scenario-picker")
            }
            .font(.subheadline)
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(.bar)
            Group {
                if CommandLine.arguments.contains("-widget-design-review") {
                    WidgetDesignReviewView()
                } else {
                    ContentView()
                }
            }
                .id(scenario.rawValue)
                .modelContainer(containers[scenario]!)
        }
    }
}
#endif
