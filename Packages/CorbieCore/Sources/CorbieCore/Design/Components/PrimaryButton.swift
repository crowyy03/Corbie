import SwiftUI

public struct PrimaryButton: View {
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
        .buttonStyle(CorbiePillButtonStyle(variant: .filled))
        .accessibilityLabel(Text(accessibilityLabel ?? title))
    }
}

#if DEBUG
struct PrimaryButtonGallery: View {
    var body: some View {
        VStack(spacing: CorbieSpacing.m) {
            PrimaryButton(title: "Continue") {}
            PrimaryButton(title: "Continue") {}
                .disabled(true)
        }
        .padding(CorbieSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CorbieColorPalette.bg)
    }
}

#if canImport(UIKit)
#Preview("PrimaryButton light") {
    PrimaryButtonGallery().preferredColorScheme(.light)
}

#Preview("PrimaryButton dark") {
    PrimaryButtonGallery().preferredColorScheme(.dark)
}
#endif
#endif
