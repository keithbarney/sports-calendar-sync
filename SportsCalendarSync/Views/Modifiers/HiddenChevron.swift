import SwiftUI

struct HiddenChevronNavigationLink<Destination: View, Label: View>: View {
    let destination: () -> Destination
    @ViewBuilder let label: () -> Label

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationLink(destination: destination) {
                EmptyView()
            }
            .opacity(0)

            label()
        }
    }
}
