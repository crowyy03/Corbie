import SwiftUI

public struct FieldRow<Content: View>: View {
    private let label: String
    private let hint: String?
    private let content: Content

    public init(label: String, hint: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.hint = hint
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            SectionCaps(text: label)
            content
            if let hint {
                Text(hint)
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

public struct TextFieldRow: View {
    private let label: String
    private let placeholder: String
    private let hint: String?
    @Binding private var text: String

    public init(label: String, placeholder: String, hint: String? = nil, text: Binding<String>) {
        self.label = label
        self.placeholder = placeholder
        self.hint = hint
        _text = text
    }

    public var body: some View {
        FieldRow(label: label, hint: hint) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text)
                .padding(.horizontal, CorbieSpacing.s)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
                        .fill(CorbieColorPalette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
                        .strokeBorder(CorbieColorPalette.border, lineWidth: CorbieMetrics.hairline)
                )
                .accessibilityLabel(Text(label))
        }
    }
}

#if DEBUG
struct FieldRowGallery: View {
    @State private var title = ""

    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.l) {
            TextFieldRow(
                label: "Title",
                placeholder: "Dinner at home",
                hint: "shows up on both phones",
                text: $title
            )
            FieldRow(label: "Priority", hint: "must, want, someday") {
                Text(verbatim: "Want")
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text)
            }
        }
        .padding(CorbieSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(CorbieColorPalette.bg)
    }
}

#if canImport(UIKit)
#Preview("FieldRow light") {
    FieldRowGallery().preferredColorScheme(.light)
}

#Preview("FieldRow dark") {
    FieldRowGallery().preferredColorScheme(.dark)
}
#endif
#endif
