import SwiftUI

// MARK: - Backwards-compatible aliases
// Color.neonVolt, kitchenGreen, courtBlue, etc. are auto-generated from Assets.xcassets

extension Color {
    // Updated to courtBlue values so existing .pickleballDarkGreen refs pick up the new branding tone
    static let pickleballDarkGreen  = Color(red: 0.114, green: 0.306, blue: 0.847) // was dark green → courtBlue
    static let pickleballLightGreen = Color(red: 0.133, green: 0.773, blue: 0.369) // was light green → kitchenGreen
}

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

// MARK: - Gradient

struct PickleballGradient: View {
    var body: some View {
        LinearGradient(
            colors: [Color.graphiteBlack, Color.courtBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Card Modifier

struct PickleballCardBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    var cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 16) {
        self.cornerRadius = cornerRadius
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color(red: 0.165, green: 0.165, blue: 0.165)  // #2A2A2A
            : Color(red: 0.886, green: 0.910, blue: 0.941)  // #E2E8F0
    }

    func body(content: Content) -> some View {
        content
            .background(Color(.systemBackground))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1.5)
            )
    }
}

extension View {
    /// Standard card — 16pt radius, crisp 1.5pt border (no shadow)
    func pickleballCard() -> some View {
        modifier(PickleballCardBackground(cornerRadius: 16))
    }

    func ecCard() -> some View {
        modifier(PickleballCardBackground(cornerRadius: 16))
    }

    /// Dashboard banner — 24pt radius
    func ecDashboardBanner() -> some View {
        modifier(PickleballCardBackground(cornerRadius: 24))
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .neonVolt

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.black)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(color)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(ECAnimation.snappyVolley, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.kitchenGreen)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.kitchenGreen.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.kitchenGreen, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(ECAnimation.snappyVolley, value: configuration.isPressed)
    }
}

// MARK: - Badges

struct DUPRBadge: View {
    let level: Decimal

    var label: String {
        switch level {
        case 5.0...: return "Pro"
        case 4.0..<5.0: return "Advanced"
        case 3.5..<4.0: return "Intermediate"
        default: return "Beginner"
        }
    }

    var color: Color {
        switch level {
        case 5.0...: return .neonVolt
        case 4.0..<5.0: return .outRed
        case 3.5..<4.0: return .warningAmber
        default: return .courtBlue
        }
    }

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
            .foregroundColor(.kitchenGreen)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.kitchenGreen.opacity(0.15))
            .cornerRadius(8)
    }
}

struct PickleballHeaderView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.racquetball")
                .font(.title2)
                .foregroundColor(.neonVolt)
            Text("Pickleball Genie")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
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
