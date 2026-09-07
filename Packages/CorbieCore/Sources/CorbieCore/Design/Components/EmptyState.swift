import SwiftUI

public struct EmptyStateAction {
    public let title: String
    public let accessibilityLabel: String?
    public let handler: () -> Void

    public init(title: String, accessibilityLabel: String? = nil, handler: @escaping () -> Void) {
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.handler = handler
    }
}

public struct EmptyState: View {
    private let systemImage: String
    private let title: String
    private let subtitle: String?
    private let monoNote: String?
    private let cta: EmptyStateAction?

    @Environment(\.palette) private var palette

    public init(
        systemImage: String,
        title: String,
        subtitle: String? = nil,
        monoNote: String? = nil,
        cta: EmptyStateAction? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.monoNote = monoNote
        self.cta = cta
    }

    public var body: some View {
        VStack(spacing: CorbieSpacing.s) {
            Image(systemName: systemImage)
                .font(.system(size: CorbieMetrics.emptyStateIconSize, weight: .light))
                .foregroundStyle(palette.text2)
                .accessibilityHidden(true)
                .padding(.bottom, CorbieSpacing.xxs)

            Text(title)
                .corbieBody()
                .fontWeight(.semibold)
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.center)

            if let subtitle {
                Text(subtitle)
                    .corbieCaption()
                    .foregroundStyle(palette.text2)
                    .multilineTextAlignment(.center)
            }

            if let monoNote {
                Text(monoNote)
                    .corbieMono()
                    .foregroundStyle(palette.text2)
                    .multilineTextAlignment(.center)
                    .padding(.top, CorbieSpacing.xxs)
            }

            if let cta {
                PrimaryButton(title: cta.title, accessibilityLabel: cta.accessibilityLabel, action: cta.handler)
                    .padding(.top, CorbieSpacing.s)
            }
        }
        .padding(.horizontal, CorbieSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#if canImport(UIKit)
#Preview("EmptyState") {
    PreviewThemes {
        EmptyState(
            systemImage: "checklist",
            title: "A to-do list for two. Anyone can take a task, or hand it over.",
            subtitle: "Nothing here yet.",
            monoNote: "nobody's the boss here",
            cta: EmptyStateAction(title: "Add a task") {}
        )
    }
}
#endif
#endif
