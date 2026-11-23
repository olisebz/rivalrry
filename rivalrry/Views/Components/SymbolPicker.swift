import SwiftUI

/// SF Symbol grid instead of an emoji picker (decision 4, design.md §5). Used for custom sports and groups.
struct SymbolPicker: View {
    @Binding var selection: String
    var symbols: [String] = CustomSport.symbols

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.s) {
            ForEach(symbols, id: \.self) { symbol in
                let isSelected = selection == symbol
                Button {
                    selection = symbol
                } label: {
                    Image(systemName: symbol)
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? Color.rvAccent : Color.rvTextPrimary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(isSelected ? Color.rvAccentSoft : Color.rvSurface,
                                    in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                        .overlay {
                            if isSelected {
                                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                                    .strokeBorder(Color.rvAccent, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(symbol)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
