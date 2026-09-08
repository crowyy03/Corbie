import SwiftUI

public struct ProgressBar: View {
    private let value: Double
    private let overspend: Double
    private let accessibilityLabel: String?
    private let accessibilityValue: String?

    @Environment(\.palette) private var palette

    public init(
        value: Double,
        overspend: Double = 0,
        accessibilityLabel: String? = nil,
        accessibilityValue: String? = nil
    ) {
        self.value = value
        self.overspend = overspend
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
    }

    private var clampedOverspend: Double {
        max(overspend, 0)
    }

    private var scale: Double {
        1 + clampedOverspend
    }

    private var reachedFraction: Double {
        min(max(value, 0), 1) / scale
    }

    private var overspendFraction: Double {
        clampedOverspend / scale
    }

    public var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(palette.accent)
                    .frame(width: proxy.size.width * reachedFraction)
                Rectangle()
                    .fill(palette.warn)
                    .frame(width: proxy.size.width * overspendFraction)
                Spacer(minLength: 0)
            }
        }
        .frame(height: CorbieMetrics.progressBarHeight)
        .background(palette.border)
        .clipShape(Capsule(style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel ?? ""))
        .accessibilityValue(Text(accessibilityValue ?? ""))
    }
}

#if DEBUG
#if canImport(UIKit)
#Preview("ProgressBar") {
    PreviewThemes {
        VStack(spacing: CorbieSpacing.l) {
            ProgressBar(value: 0.35)
            ProgressBar(value: 1)
            ProgressBar(value: 1, overspend: 0.4)
        }
    }
}
#endif
#endif
