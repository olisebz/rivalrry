import SwiftUI

/// Horizontally scrolling filter chips (design.md §6.5). Active chip is inverted, never green.
struct FilterChips<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(options, id: \.value) { option in
                    let isSelected = option.value == selection
                    Button {
                        withAnimation(.spring(duration: 0.3)) { selection = option.value }
                    } label: {
                        Text(option.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isSelected ? Color.rvBackground : Color.rvTextPrimary)
                            .padding(.horizontal, Spacing.m)
                            .frame(minHeight: 36)
                            .background(isSelected ? Color.rvTextPrimary : Color.rvSurface, in: Capsule())
                            // 44 pt tap target (design.md §4.3).
                            .padding(.vertical, Spacing.xs)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, Spacing.m)
        }
    }
}
