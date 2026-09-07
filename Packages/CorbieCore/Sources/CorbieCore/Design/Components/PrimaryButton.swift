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
#if canImport(UIKit)
#Preview("PrimaryButton") {
    PreviewThemes {
        VStack(spacing: CorbieSpacing.m) {
            PrimaryButton(title: "Continue") {}
            PrimaryButton(title: "Continue") {}
                .disabled(true)
        }
    }
}
#endif
#endif
