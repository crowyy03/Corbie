import SwiftUI

public struct SectionCaps: View {
    private let text: String

    @Environment(\.palette) private var palette

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .corbieSectionCaps()
            .foregroundStyle(palette.text2)
            .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
#if canImport(UIKit)
#Preview("SectionCaps") {
    PreviewThemes {
        VStack(alignment: .leading, spacing: CorbieSpacing.s) {
            SectionCaps(text: "Today")
            SectionCaps(text: "Coming up")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
#endif
