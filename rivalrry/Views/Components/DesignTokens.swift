import SwiftUI

// Design tokens from docs/design.md §11.
// Colors live in Assets.xcassets, each with a light and dark variant.

extension Color {
    static let rvBackground    = Color("Background")     // #FFFFFF / #000000
    static let rvSurface       = Color("Surface")        // #F5F5F7 / #1C1C1E
    static let rvSeparator     = Color("Separator")      // #E5E5EA / #38383A
    static let rvTextPrimary   = Color("TextPrimary")    // #111111 / #F5F5F7
    static let rvTextSecondary = Color("TextSecondary")  // #6E6E73 / #98989D
    static let rvTextTertiary  = Color("TextTertiary")   // #AEAEB2 / #636366
    static let rvAccent        = Color("Accent")         // #15803D / #22C55E
    static let rvOnAccent      = Color("OnAccent")       // #FFFFFF / #000000
    static let rvDestructive   = Color("Destructive")    // #DC2626 / #EF4444
    static let rvAccentSoft    = Color("Accent").opacity(0.12)
}

extension Font {
    static let rvScoreHero  = Font.system(size: 56, weight: .bold, design: .rounded).monospacedDigit()
    static let rvScoreLarge = Font.system(size: 34, weight: .bold, design: .rounded).monospacedDigit()
}

enum Spacing {
    static let xs: CGFloat = 4,  s: CGFloat = 8,  m: CGFloat = 16
    static let l: CGFloat = 24,  xl: CGFloat = 32, xxl: CGFloat = 48
}

enum Radius {
    static let card: CGFloat = 16, button: CGFloat = 14
}
