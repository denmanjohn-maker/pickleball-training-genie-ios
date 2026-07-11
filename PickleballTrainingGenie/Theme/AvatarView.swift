import SwiftUI

/// Code-defined pickleball-themed avatars: an SF Symbol over a neon gradient disc.
/// Stored on the profile as "builtin:<rawValue>"; custom photos use avatarId "custom".
enum BuiltInAvatar: String, CaseIterable, Identifiable {
    case paddlePro
    case dinkWizard
    case kitchenKing
    case rallyStar
    case smashBolt
    case courtComet
    case spinMaster
    case netNinja
    case sunbeltSlicer
    case trophyHunter

    var id: String { rawValue }

    var avatarId: String { "builtin:\(rawValue)" }

    var displayName: String {
        switch self {
        case .paddlePro: return "Paddle Pro"
        case .dinkWizard: return "Dink Wizard"
        case .kitchenKing: return "Kitchen King"
        case .rallyStar: return "Rally Star"
        case .smashBolt: return "Smash Bolt"
        case .courtComet: return "Court Comet"
        case .spinMaster: return "Spin Master"
        case .netNinja: return "Net Ninja"
        case .sunbeltSlicer: return "Sunbelt Slicer"
        case .trophyHunter: return "Trophy Hunter"
        }
    }

    var symbolName: String {
        switch self {
        case .paddlePro: return "figure.pickleball"
        case .dinkWizard: return "wand.and.stars"
        case .kitchenKing: return "crown.fill"
        case .rallyStar: return "star.fill"
        case .smashBolt: return "bolt.fill"
        case .courtComet: return "flame.fill"
        case .spinMaster: return "hurricane"
        case .netNinja: return "figure.racquetball"
        case .sunbeltSlicer: return "sun.max.fill"
        case .trophyHunter: return "trophy.fill"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .paddlePro: return [.neonMagenta, .cosmicPurple]
        case .dinkWizard: return [.cosmicPurple, .neonCyan]
        case .kitchenKing: return [.solarGold, .cometRed]
        case .rallyStar: return [.neonCyan, .cosmicPurple]
        case .smashBolt: return [.solarGold, .neonMagenta]
        case .courtComet: return [.cometRed, .solarGold]
        case .spinMaster: return [.neonCyan, .neonMagenta]
        case .netNinja: return [.cosmicPurple, .cometRed]
        case .sunbeltSlicer: return [.solarGold, .neonCyan]
        case .trophyHunter: return [.neonMagenta, .solarGold]
        }
    }

    static func from(avatarId: String?) -> BuiltInAvatar? {
        guard let avatarId, avatarId.hasPrefix("builtin:") else { return nil }
        return BuiltInAvatar(rawValue: String(avatarId.dropFirst("builtin:".count)))
    }
}

/// Renders the user's avatar: a custom photo when one is set, a built-in
/// pickleball avatar when selected, or the Genie artwork as the fallback.
struct AvatarView: View {
    let avatarId: String?
    var customImage: UIImage?
    var size: CGFloat = 100

    var body: some View {
        Group {
            if avatarId == "custom", let customImage {
                Image(uiImage: customImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let builtIn = BuiltInAvatar.from(avatarId: avatarId) {
                BuiltInAvatarView(avatar: builtIn, size: size)
            } else {
                Image("Genie")
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            }
        }
        .overlay(
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.neonMagenta.opacity(0.7), .neonCyan.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1.5, size / 50)
                )
        )
        .shadow(color: .neonMagenta.opacity(0.45), radius: size / 8, x: 0, y: size / 16)
    }
}

struct BuiltInAvatarView: View {
    let avatar: BuiltInAvatar
    var size: CGFloat = 100

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: avatar.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: avatar.symbolName)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        Color.deepSpace.ignoresSafeArea()
        VStack(spacing: 20) {
            AvatarView(avatarId: nil, size: 100)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5)) {
                ForEach(BuiltInAvatar.allCases) { avatar in
                    BuiltInAvatarView(avatar: avatar, size: 56)
                }
            }
        }
        .padding()
    }
}
