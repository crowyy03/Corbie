import SwiftUI

public struct Card<Content: View>: View {
    private let isHighlighted: Bool
    private let padding: CGFloat
    private let content: Content

    @Environment(\.palette) private var palette

    public init(
        isHighlighted: Bool = false,
        padding: CGFloat = CorbieSpacing.m,
        @ViewBuilder content: () -> Content
    ) {
        self.isHighlighted = isHighlighted
        self.padding = padding
        self.content = content()
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CorbieRadius.card, style: .continuous)
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    shape.fill(palette.surface)
                    if isHighlighted {
                        shape.fill(palette.accent).opacity(0.12)
                    }
                }
            }
            .overlay(shape.strokeBorder(isHighlighted ? palette.accent : palette.border, lineWidth: CorbieMetrics.hairline))
    }
}

#if DEBUG
#if canImport(UIKit)
#Preview("Card") {
    PreviewThemes {
        VStack(spacing: CorbieSpacing.m) {
            Card {
                Text(verbatim: "Plain card").corbieBody()
            }
            Card(isHighlighted: true) {
                Text(verbatim: "Highlighted card").corbieBody()
            }
        }
    }
}
#endif
#endif
