import SwiftUI

// MARK: - Synthwave palette
// Color.deepSpace, nebulaSurface, neonMagenta, neonCyan, cosmicPurple,
// cometRed, solarGold, starlight are auto-generated from Assets.xcassets

// MARK: - Typography Scale (SF Pro Display kicks in automatically at ≥ 20pt)

extension Font {
    static let ecTitle     = Font.system(size: 28, weight: .bold)
    static let ecStatValue = Font.system(size: 36, weight: .bold)
    static let ecBody      = Font.system(size: 15, weight: .regular)
}

// MARK: - Animation

enum ECAnimation {
    // Spec: stiffness 300, damping 25 → response ≈ 0.36s, dampingFraction ≈ 0.72
    static let snappyVolley = Animation.spring(response: 0.36, dampingFraction: 0.72)
}

// MARK: - Background Gradient

struct SynthwaveGradient: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.043, green: 0.024, blue: 0.153), location: 0.0),  // #0B0627 near-black indigo
                .init(color: .deepSpace, location: 0.45),
                .init(color: Color(red: 0.290, green: 0.086, blue: 0.357), location: 1.0)   // #4A165B plum nebula
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Neon Glow

struct NeonGlow: ViewModifier {
    var color: Color = .neonMagenta
    var radius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.8), radius: radius * 0.4)
            .shadow(color: color.opacity(0.35), radius: radius)
    }
}

extension View {
    func neonGlow(_ color: Color = .neonMagenta, radius: CGFloat = 8) -> some View {
        modifier(NeonGlow(color: color, radius: radius))
    }
}

// MARK: - Star Field
// Static, seeded so the sky never flickers between renders. Splash/Login only.

struct StarFieldView: View {
    var count = 70

    var body: some View {
        Canvas { ctx, size in
            var rng = SplitMix64(seed: 0xC0FFEE)
            for _ in 0..<count {
                let x = CGFloat.random(in: 0...size.width, using: &rng)
                let y = CGFloat.random(in: 0...size.height, using: &rng)
                let r = CGFloat.random(in: 0.4...1.4, using: &rng)
                let a = Double.random(in: 0.15...0.85, using: &rng)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                    with: .color(.white.opacity(a))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Card Modifier

struct SynthwaveCardBackground: ViewModifier {
    var cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 16) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background(Color.nebulaSurface)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.neonMagenta.opacity(0.55), .neonCyan.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .neonMagenta.opacity(0.15), radius: 10, x: 0, y: 4)
    }
}

extension View {
    /// Standard card — 16pt radius, neon gradient hairline + soft glow
    func pickleballCard() -> some View {
        modifier(SynthwaveCardBackground(cornerRadius: 16))
    }

    func ecCard() -> some View {
        modifier(SynthwaveCardBackground(cornerRadius: 16))
    }

    /// Dashboard banner — 24pt radius
    func ecDashboardBanner() -> some View {
        modifier(SynthwaveCardBackground(cornerRadius: 24))
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .neonMagenta

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.black)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(color)
            .cornerRadius(12)
            .neonGlow(color, radius: 10)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(ECAnimation.snappyVolley, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.neonCyan)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.neonCyan.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.neonCyan, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(ECAnimation.snappyVolley, value: configuration.isPressed)
    }
}

// MARK: - Badges

struct DUPRBadge: View {
    let level: Decimal

    private var skillLevel: SkillLevel { .nearest(to: level) }

    var label: String { skillLevel.name }

    var color: Color { skillLevel.color }

    var body: some View {
        Text("DUPR \(level.duprString()) · \(label)")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(level >= 5.0 ? .black : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(level >= 5.0 ? color : color.opacity(0.12))
            .cornerRadius(8)
    }
}

struct CategoryBadge: View {
    let category: String

    var body: some View {
        Text(category)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.neonCyan)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.neonCyan.opacity(0.15))
            .cornerRadius(8)
    }
}

struct PickleballHeaderView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.racquetball")
                .font(.title2)
                .foregroundColor(.neonMagenta)
                .neonGlow(.neonMagenta, radius: 6)
            Text("Pickleball Genie")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.neonMagenta, .neonCyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
}

// MARK: - Utilities

extension Decimal {
    func duprString() -> String {
        let n = NSDecimalNumber(decimal: self)
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: n) ?? n.stringValue
    }
}
