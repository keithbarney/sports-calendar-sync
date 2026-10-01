import Foundation

extension Competition {
    /// Bundled competition badges with automatic Light/Dark asset variants.
    /// Playoff feeds share their domestic league's identity.
    var logoAssetName: String? {
        switch self {
        case .bundesligaPlayoff: return Competition.bundesliga.logoAssetName
        case .bundesliga2Playoff: return Competition.bundesliga2.logoAssetName
        case .ligue1Playoff: return Competition.ligue1.logoAssetName
        case .ligue2Playoff: return Competition.ligue2.logoAssetName
        case .germanSuperCup, .tropheeDesChampions, .communityShield,
             .intercontinentalCup, .clubFriendlies:
            // No usable badge in the checked provider catalog; don't show its
            // generic team placeholder as though it were a competition logo.
            return nil
        default: return "competition-" + slug.replacingOccurrences(of: ".", with: "-")
        }
    }
}
