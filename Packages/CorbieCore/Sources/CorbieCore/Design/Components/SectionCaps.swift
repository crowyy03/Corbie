import SwiftUI

public struct SectionCaps: View {
    private let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .corbieSectionCaps()
            .foregroundStyle(CorbieColorPalette.text2)
            .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
struct SectionCapsGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.s) {
            SectionCaps(text: "Today")
            SectionCaps(text: "Coming up")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(CorbieSpacing.l)
        .background(CorbieColorPalette.bg)
    }
}

#if canImport(UIKit)
#Preview("SectionCaps light") {
    SectionCapsGallery().preferredColorScheme(.light)
}

#Preview("SectionCaps dark") {
    SectionCapsGallery().preferredColorScheme(.dark)
}
#endif
#endif
