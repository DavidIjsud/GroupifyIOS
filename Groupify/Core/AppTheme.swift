import SwiftUI

/// Shared dark-theme tokens for the Groups flow and other cross-screen UI.
///
/// Mirrors the private `Theme` in `PhotoMatchScreen` and the design tokens from
/// the fetched Groups flow, but deliberately reuses the app's existing accent
/// (`#7B61FF`) instead of the prototype's near-identical `#7C5CE6`, per the
/// project convention to reuse theme tokens rather than introduce new literals.
enum AppTheme {
    static let background = Color(red: 14/255, green: 14/255, blue: 14/255)    // #0E0E0E
    static let card = Color(red: 28/255, green: 28/255, blue: 30/255)          // #1C1C1E
    static let cardHi = Color(red: 35/255, green: 35/255, blue: 38/255)        // #232326
    static let accent = Color(red: 123/255, green: 97/255, blue: 255/255)      // #7B61FF
    static let accentSoft = Color(red: 123/255, green: 97/255, blue: 255/255).opacity(0.16)
    static let accentBorder = Color(red: 123/255, green: 97/255, blue: 255/255).opacity(0.45)
    static let accentText = Color(red: 194/255, green: 178/255, blue: 243/255) // #C2B2F3 (on dark)
    static let success = Color(red: 52/255, green: 199/255, blue: 89/255)      // #34C759
    static let danger = Color(red: 255/255, green: 69/255, blue: 58/255)       // #FF453A
    static let text = Color.white
    static let textMuted = Color(red: 142/255, green: 142/255, blue: 147/255)  // #8E8E93
    static let textDim = Color(red: 90/255, green: 90/255, blue: 95/255)       // #5A5A5F
    static let hairline = Color.white.opacity(0.08)

    static let cornerRadius: CGFloat = 16
}
