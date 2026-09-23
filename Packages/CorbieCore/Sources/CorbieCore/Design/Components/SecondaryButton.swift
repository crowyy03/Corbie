import SwiftUI

public struct SecondaryButton: View {
    private let title: String
    private let systemImage: String?
    private let accessibilityLabel: String?
    private let action: () -> Void

    public init(
        title: String,
        systemImage: String? = nil,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
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
            SecondaryButton(title: "Done", systemImage: "checkmark") {}
                .disabled(true)
        }
    }
}
#endif
#endif
