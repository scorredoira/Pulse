import SwiftUI

// MARK: - Spacing

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

// MARK: - Corner Radius

enum CornerRadius {
    static let small: CGFloat = 6
    static let medium: CGFloat = 10
    static let large: CGFloat = 12
}

// MARK: - Card Style

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.lg)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Pill Button Style

struct PillButtonStyle: ButtonStyle {
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .minimumScaleFactor(0.8)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .foregroundStyle(.white)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1.0), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Wide Pill Button Style

struct WidePillButtonStyle: ButtonStyle {
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .foregroundStyle(.white)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1.0), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Icon Button Style

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Color.primary.opacity(configuration.isPressed ? 0.1 : 0.05),
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        Label {
            Text(title)
                .font(.headline)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.accent)
        }
    }
}
