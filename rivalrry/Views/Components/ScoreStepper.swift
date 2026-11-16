import SwiftUI

/// Counter with round – / + buttons (design.md §6.8). Tapping the number opens the keyboard.
struct ScoreStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...99
    var font: Font = .rvScoreLarge
    var label: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            stepButton("minus", label: "Decrease \(label)") { value = max(range.lowerBound, value - 1) }
                .disabled(value <= range.lowerBound)

            TextField("0", value: $value, format: .number)
                .keyboardType(.numberPad)
                .font(font)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.rvTextPrimary)
                .frame(minWidth: 52)
                .fixedSize()
                .contentTransition(.numericText())
                .accessibilityLabel(label)
                .onChange(of: value) { _, newValue in
                    let clamped = min(max(newValue, range.lowerBound), range.upperBound)
                    if clamped != newValue { value = clamped }
                }

            stepButton("plus", label: "Increase \(label)") { value = min(range.upperBound, value + 1) }
                .disabled(value >= range.upperBound)
        }
        .sensoryFeedback(.selection, trigger: value)
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3)) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.rvTextPrimary)
                .frame(width: 36, height: 36)
                .background(Color.rvSurface, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Grey full-width button (design.md §6.1 "Secondary"), e.g. "Add Set".
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(Color.rvTextPrimary)
            .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.3), value: configuration.isPressed)
    }
}
