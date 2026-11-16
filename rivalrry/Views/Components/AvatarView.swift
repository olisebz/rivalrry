import SwiftUI
import UIKit

/// Round avatar: photo, or initials in the player's color on a muted background (design.md §2.4, §2.5).
struct AvatarView: View {
    let player: Player
    var size: CGFloat = 40

    var body: some View {
        let color = Color(hex: player.colorHex)
        Group {
            if let photo = player.photo, let image = UIImage(data: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(player.initials)
                    .font(size >= 64 ? .system(size: 22, weight: .semibold) : .headline)
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(color.opacity(0.15))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

extension Color {
    /// Color from a hex string like "15803D" or "#15803D".
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(digits, radix: 16) ?? 0x6E6E73
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}
