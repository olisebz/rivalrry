import SwiftUI

/// Full-width green main button (design.md §6.1). At most one per screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(isEnabled ? Color.rvOnAccent : Color.rvTextTertiary)
            .background(isEnabled ? Color.rvAccent : Color.rvSurface,
                        in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.3), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: Spacing.m) {
        Button("Save Match") {}
            .buttonStyle(PrimaryButtonStyle())
        Button("Save Match") {}
            .buttonStyle(PrimaryButtonStyle())
            .disabled(true)
    }
    .padding(Spacing.m)
    .background(Color.rvBackground)
}
