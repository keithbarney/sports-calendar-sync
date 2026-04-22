import SwiftUI

struct SkeletonView: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var radius: CGFloat = 4

    @State private var shimmer = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.surfaceElevated)
            .frame(width: width, height: height)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.03),
                        Color.white.opacity(0.18),
                        Color.white.opacity(0.03),
                        Color.white.opacity(0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 250)
                .offset(x: shimmer ? 300 : -300)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmer = true
                }
            }
    }
}

// MARK: - Feed Row Skeleton

struct MatchRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonView(width: 44, height: 44, radius: 6)

            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(width: 160, height: 16)
                SkeletonView(width: 120, height: 14)
                SkeletonView(width: 80, height: 12)
            }

            Spacer()

            SkeletonView(width: 50, height: 14)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Team Detail Skeleton

struct TeamDetailSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Crest hero placeholder
            HStack(spacing: 16) {
                SkeletonView(width: 96, height: 96, radius: 12)
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonView(width: 160, height: 24)
                    SkeletonView(width: 90, height: 20, radius: 10)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 32) {
                // Stats row
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(spacing: 4) {
                            SkeletonView(width: 40, height: 22)
                            SkeletonView(width: 60, height: 12)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Fixtures
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonView(width: 120, height: 11)
                    ForEach(0..<4, id: \.self) { _ in
                        SkeletonView(height: 56, radius: 12)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        }
        .background(Color.background)
    }
}

// MARK: - Discover Skeleton

struct DiscoverSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            SkeletonView(height: 40, radius: 12)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            ForEach(0..<8, id: \.self) { _ in
                MatchRowSkeleton()
            }
        }
    }
}
