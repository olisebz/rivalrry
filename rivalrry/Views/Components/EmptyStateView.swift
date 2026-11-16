import SwiftUI

/// Centered empty state: large symbol, short text, one primary button (design.md §6.10).
struct EmptyStateView: View {
    let symbol: String
    let message: String
    var buttonTitle: String? = nil
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: symbol)
                .font(.system(size: 48))
                .foregroundStyle(Color.rvTextTertiary)
            Text(message)
                .font(.body)
                .foregroundStyle(Color.rvTextSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let buttonTitle {
                Button(buttonTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(symbol: "person.2",
                   message: "No rivals yet. Add a friend to start keeping score.",
                   buttonTitle: "Add Friend") {}
        .background(Color.rvBackground)
}
