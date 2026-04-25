import SwiftUI

struct LucideIcon: View {
    let name: String
    var size: CGFloat = 24

    var body: some View {
        Image("Icons/\(name)")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
