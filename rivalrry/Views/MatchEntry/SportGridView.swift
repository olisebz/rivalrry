import SwiftUI

/// Simple 3-column grid of sports, no "Recent", no categories (decision 3).
/// S2b picks one sport, S0 picks several favorites.
struct SportGridView: View {
    let sports: [SportType]
    let isSelected: (SportType) -> Bool
    let toggle: (SportType) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.s) {
            ForEach(sports) { sport in
                SportTile(sport: sport, isSelected: isSelected(sport)) {
                    withAnimation(.spring(duration: 0.3)) { toggle(sport) }
                }
            }
        }
        .padding(.horizontal, Spacing.m)
    }
}

extension SportGridView {
    /// Single choice (S2b).
    init(sports: [SportType], selection: Binding<SportType?>) {
        self.init(sports: sports,
                  isSelected: { selection.wrappedValue == $0 },
                  toggle: { selection.wrappedValue = $0 })
    }
}

/// Sport tile (design.md §6.7). Selected: accent border, accentSoft background, accent symbol.
struct SportTile: View {
    let sport: SportType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.s) {
                Image(systemName: sport.symbolName)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? Color.rvAccent : Color.rvTextPrimary)
                    .frame(height: 32)
                Text(sport.displayName)
                    .font(.subheadline)
                    .foregroundStyle(Color.rvTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(Spacing.s)
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(isSelected ? Color.rvAccentSoft : Color.rvSurface,
                        in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(Color.rvAccent, lineWidth: 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
