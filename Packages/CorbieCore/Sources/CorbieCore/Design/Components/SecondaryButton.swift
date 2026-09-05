import SwiftUI

public struct SecondaryButton: View {
    private let title: String
    private let accessibilityLabel: String?
    private let action: () -> Void

    public init(title: String, accessibilityLabel: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(CorbiePillButtonStyle(variant: .outlined))
        .accessibilityLabel(Text(accessibilityLabel ?? title))
    }
}

#if DEBUG
struct SecondaryButtonGallery: View {
    var body: some View {
        VStack(spacing: CorbieSpacing.m) {
            SecondaryButton(title: "Not now") {}
            SecondaryButton(title: "Not now") {}
                .disabled(true)
        }
        .padding(CorbieSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CorbieColorPalette.bg)
    }
}

#if canImport(UIKit)
#Preview("SecondaryButton light") {
    SecondaryButtonGallery().preferredColorScheme(.light)
}

#Preview("SecondaryButton dark") {
    SecondaryButtonGallery().preferredColorScheme(.dark)
}
#endif
#endif
