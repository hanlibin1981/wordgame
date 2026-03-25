import SwiftUI

// MARK: - Colors
extension Color {
    // Primary colors
    static let primaryBlue = Color(hex: "2563EB")
    static let successGreen = Color(hex: "22C55E")
    static let errorRed = Color(hex: "EF4444")
    static let warningOrange = Color(hex: "F59E0B")

    // Background colors
    static let backgroundMain = Color(hex: "F8FAFC")
    static let cardBackground = Color.white

    // Initialize from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6:  // RGB
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:  // ARGB
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

// MARK: - Design System Fonts
/// Scaled fonts for the word game.
/// Base size = system default × 1.6 (34×2×0.8 = 54.4pt ≈ largeTitle).
/// The 1.6× scale was chosen so that:
///   - largeTitle ≈ 54pt (清晰展示单词)
///   - titles remain readable without dominating the screen
///   - captions are still legible on small screens
enum DesignFont {
    /// Shared scale factor: system default × 1.6
    /// Computation: base_point_size × 2 × 0.8 = base_point_size × 1.6
    private static let scale: CGFloat = 1.6

    // Large titles — game question word display
    static let largeTitle = Font.system(size: 34 * scale, weight: .bold)
    static let title       = Font.system(size: 28 * scale, weight: .bold)
    static let title2     = Font.system(size: 24 * scale, weight: .bold)
    static let title3     = Font.system(size: 20 * scale, weight: .semibold)

    // Section / card headings
    static let headline   = Font.system(size: 18 * scale, weight: .semibold)
    static let subheadline = Font.system(size: 15 * scale, weight: .regular)

    // Body text — meaning, sentences, labels
    static let body       = Font.system(size: 17 * scale, weight: .regular)
    static let callout    = Font.system(size: 16 * scale, weight: .regular)

    // Captions, hints, metadata
    static let caption    = Font.system(size: 12 * scale, weight: .regular)
    static let caption2   = Font.system(size: 11 * scale, weight: .regular)

    // Question option buttons
    static let option     = Font.system(size: 17 * scale, weight: .medium)

    // Tab bar labels (system-provided)
}
