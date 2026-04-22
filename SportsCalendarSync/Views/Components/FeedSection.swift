import SwiftUI

struct FeedSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        Section {
            content()
        } header: {
            Text(title)
                .sectionHeader()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 4)
        }
    }
}
