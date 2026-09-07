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
#if canImport(UIKit)
#Preview("SecondaryButton") {
    PreviewThemes {
        VStack(spacing: CorbieSpacing.m) {
            SecondaryButton(title: "Not now") {}
            SecondaryButton(title: "Not now") {}
                .disabled(true)
        }
    }
}
#endif
#endif
