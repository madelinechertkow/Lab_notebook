import SwiftUI

struct EmptyStateView: View {
    @EnvironmentObject var theme: ThemeStore

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 36))
                .foregroundStyle(theme.textTertiary)
            Text("Select a note or create a new one")
                .font(theme.bodyFont(14))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.editorBackground)
    }
}
