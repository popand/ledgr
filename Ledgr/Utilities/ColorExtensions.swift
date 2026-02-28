import SwiftUI

extension Color {
    // Primary brand colors (from Dribbble reference)
    static let ledgrPrimary = Color(hex: 0x0724D5)
    static let ledgrAccent = Color(hex: 0x253BC1)
    static let ledgrDark = Color(hex: 0x131D22)

    // Backgrounds
    static let ledgrBackground = Color(hex: 0xF2F3F5)
    static let ledgrCardBackground = Color.white

    // Text
    static let ledgrSecondaryText = Color(hex: 0x847C8A)
    static let ledgrSubtleText = Color(hex: 0xA1B1D4)

    // Semantic
    static let ledgrSuccess = Color(hex: 0x22C55E)
    static let ledgrWarning = Color(hex: 0xF59E0B)
    static let ledgrError = Color(hex: 0xEF4444)

    // Category colors
    static let categoryFood = Color(hex: 0xFF6B35)
    static let categoryTravel = Color(hex: 0x3B82F6)
    static let categoryOffice = Color(hex: 0x8B5CF6)
    static let categoryEntertainment = Color(hex: 0xEC4899)
    static let categoryUtilities = Color(hex: 0x06B6D4)
    static let categoryHealth = Color(hex: 0xEF4444)
    static let categoryShopping = Color(hex: 0x6366F1)
    static let categoryOther = Color(hex: 0x9CA3AF)

    // Gradients
    static let ledgrGradient = LinearGradient(
        colors: [Color(hex: 0x0724D5), Color(hex: 0x253BC1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ledgrGradientDark = LinearGradient(
        colors: [Color(hex: 0x131D22), Color(hex: 0x1A2A35)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Legacy alias
    static let ledgrGreen = ledgrPrimary

    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Card Style Modifier

struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.ledgrCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func cardStyle(padding: CGFloat = 16, cornerRadius: CGFloat = 20) -> some View {
        modifier(CardStyle(padding: padding, cornerRadius: cornerRadius))
    }
}
