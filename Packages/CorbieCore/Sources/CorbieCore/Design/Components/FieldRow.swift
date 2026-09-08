import SwiftUI

public struct FieldBoxModifier: ViewModifier {
    @Environment(\.palette) private var palette

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
                    .strokeBorder(palette.border, lineWidth: CorbieMetrics.hairline)
            )
    }
}

public extension View {
    func corbieFieldBox() -> some View {
        modifier(FieldBoxModifier())
    }
}

public struct FieldRow<Content: View>: View {
    private let label: String
    private let hint: String?
    private let content: Content

    @Environment(\.palette) private var palette

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
                    .foregroundStyle(palette.text2)
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

    @Environment(\.palette) private var palette

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
                .foregroundStyle(palette.text)
                .padding(.horizontal, CorbieSpacing.s)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
                .corbieFieldBox()
                .accessibilityLabel(Text(label))
        }
    }
}

#if DEBUG
private struct FieldRowPreview: View {
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
                Text(verbatim: "Want").corbieBody()
            }
        }
    }
}

#if canImport(UIKit)
#Preview("FieldRow") {
    PreviewThemes {
        FieldRowPreview()
    }
}
#endif
#endif
