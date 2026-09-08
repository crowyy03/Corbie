#if DEBUG
import SwiftUI

struct PreviewThemes<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(CorbieTheme.allCases) { theme in
                    content
                        .padding(CorbieSpacing.l)
                        .frame(maxWidth: .infinity)
                        .background(theme.palette.bg)
                        .corbieTheme(theme)
                        .environment(\.colorScheme, theme.isDark ? .dark : .light)
                }
            }
        }
    }
}
#endif
