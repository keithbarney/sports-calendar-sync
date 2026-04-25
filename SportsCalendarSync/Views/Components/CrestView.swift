import SwiftUI

/// Sports equivalent of ShowSync's `PosterView`. Loads team crest from ESPN's CDN.
/// Uses a square (not 2:3 poster) aspect ratio since crests are typically 1:1 and don't crop well.
struct CrestView: View {
    let url: String?
    var size: CGFloat = 44
    var fallbackIcon: String = "shield"

    var body: some View {
        AsyncImage(url: resolved) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            Rectangle()
                .fill(Color.surfaceElevated)
                .overlay {
                    LucideIcon(name: fallbackIcon, size: size * 0.4)
                        .foregroundStyle(.textTertiary)
                }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var resolved: URL? {
        guard let url else { return nil }
        return URL(string: url)
    }
}
