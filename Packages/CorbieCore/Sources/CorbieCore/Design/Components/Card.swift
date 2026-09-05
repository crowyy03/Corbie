import SwiftUI

public struct Card<Content: View>: View {
    private let showsChromeGradient: Bool
    private let content: Content

    public init(showsChromeGradient: Bool = false, @ViewBuilder content: () -> Content) {
        self.showsChromeGradient = showsChromeGradient
        self.content = content()
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CorbieRadius.card, style: .continuous)
    }

    public var body: some View {
        content
            .padding(CorbieSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    shape.fill(CorbieColorPalette.surface)
                    if showsChromeGradient {
                        shape.fill(CorbieColorPalette.chrome).opacity(0.14)
                    }
                }
            }
            .overlay(shape.strokeBorder(CorbieColorPalette.border, lineWidth: CorbieMetrics.hairline))
    }
}

#if DEBUG
struct CardGallery: View {
    var body: some View {
        VStack(spacing: CorbieSpacing.m) {
            Card {
                VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                    Text(verbatim: "Plain card")
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                    Text(verbatim: "surface, corner 20, padding 16")
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
            }
            Card(showsChromeGradient: true) {
                Text(verbatim: "Chrome card")
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text)
            }
        }
        .padding(CorbieSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CorbieColorPalette.bg)
    }
}

#if canImport(UIKit)
#Preview("Card light") {
    CardGallery().preferredColorScheme(.light)
}

#Preview("Card dark") {
    CardGallery().preferredColorScheme(.dark)
}
#endif
#endif
