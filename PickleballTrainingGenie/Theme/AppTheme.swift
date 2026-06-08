import SwiftUI

extension Color {
    static let pickleballDarkGreen = Color(red: 0.11, green: 0.37, blue: 0.13)
    static let pickleballLightGreen = Color(red: 0.56, green: 0.93, blue: 0.56)
}

struct PickleballGradient: View {
    var body: some View {
        LinearGradient(
            colors: [Color.pickleballDarkGreen, Color.pickleballGreen.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct PickleballCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .pickleballGreen.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func pickleballCard() -> some View {
        modifier(PickleballCardBackground())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .pickleballYellow

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.black)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(color)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.pickleballGreen)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.pickleballGreen.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.pickleballGreen, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

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
        case 5.0...: return .purple
        case 4.0..<5.0: return .red
        case 3.5..<4.0: return .orange
        default: return .blue
        }
    }

    var body: some View {
        Text("DUPR \(level.duprString()) · \(label)")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(8)
    }
}

struct CategoryBadge: View {
    let category: String

    var body: some View {
        Text(category)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.pickleballDarkGreen)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.pickleballGreen.opacity(0.15))
            .cornerRadius(8)
    }
}

struct PickleballHeaderView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.racquetball")
                .font(.title2)
                .foregroundColor(.pickleballYellow)
            Text("Pickleball Genie")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

extension Decimal {
    func duprString() -> String {
        let n = NSDecimalNumber(decimal: self)
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: n) ?? n.stringValue
    }
}
