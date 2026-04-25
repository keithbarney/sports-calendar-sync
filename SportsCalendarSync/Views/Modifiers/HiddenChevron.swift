import SwiftUI

struct HiddenChevronNavigationLink<Destination: View, Label: View>: View {
    let destination: () -> Destination
    @ViewBuilder let label: () -> Label

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            label()
        }
        .buttonStyle(.plain)
    }
}
