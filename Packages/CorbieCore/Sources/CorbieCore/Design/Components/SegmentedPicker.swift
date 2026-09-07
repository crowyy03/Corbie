import SwiftUI

public struct SegmentedPicker<Option: Hashable>: View {
    @Binding private var selection: Option

    private let options: [Option]
    private let label: (Option) -> String

    @Environment(\.palette) private var palette

    public init(selection: Binding<Option>, options: [Option], label: @escaping (Option) -> String) {
        _selection = selection
        self.options = options
        self.label = label
    }

    public var body: some View {
        HStack(spacing: CorbieSpacing.xxs) {
            ForEach(options, id: \.self) { option in
                segment(option)
            }
        }
        .padding(CorbieSpacing.xxs)
        .background(Capsule(style: .continuous).fill(palette.surface))
        .overlay(Capsule(style: .continuous).strokeBorder(palette.border, lineWidth: CorbieMetrics.hairline))
    }

    private func segment(_ option: Option) -> some View {
        let isSelected = option == selection
        return Button {
            selection = option
        } label: {
            Text(label(option))
                .corbieCaption()
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? palette.ctaText : palette.text2)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(minHeight: CorbieMetrics.segmentHeight)
                .background(Capsule(style: .continuous).fill(isSelected ? palette.accent : .clear))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label(option)))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#if DEBUG
private struct SegmentedPickerPreview: View {
    @State private var selection = "all"

    var body: some View {
        SegmentedPicker(selection: $selection, options: ["all", "mine", "free"]) { option in
            option.capitalized
        }
    }
}

#if canImport(UIKit)
#Preview("SegmentedPicker") {
    PreviewThemes {
        SegmentedPickerPreview()
    }
}
#endif
#endif
