import CorbieCore
import SwiftUI

private struct PlansFieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, CorbieSpacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
            .corbieFieldBox()
    }
}

extension View {
    func plansFieldBackground() -> some View {
        modifier(PlansFieldBackground())
    }

    func plansListRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(
                EdgeInsets(
                    top: CorbieSpacing.xs,
                    leading: CorbieSpacing.l,
                    bottom: CorbieSpacing.xs,
                    trailing: CorbieSpacing.l
                )
            )
    }
}

struct PlansSectionHeader: View {
    @Environment(\.palette) private var palette

    let text: String

    var body: some View {
        SectionCaps(text: text)
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.vertical, CorbieSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.bg)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

struct PlansAmountField: View {
    @Environment(\.palette) private var palette

    let label: String
    let hint: String?
    @Binding var amount: Double

    init(label: String, hint: String? = nil, amount: Binding<Double>) {
        self.label = label
        self.hint = hint
        _amount = amount
    }

    var body: some View {
        FieldRow(label: label, hint: hint) {
            TextField(label, value: $amount, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .corbieBody()
                .foregroundStyle(palette.text)
                .plansFieldBackground()
                .accessibilityLabel(Text(label))
        }
    }
}

struct PlansCurrencyField: View {
    @Environment(\.palette) private var palette

    let label: String
    let currencies: [String]
    @Binding var selection: String

    var body: some View {
        FieldRow(label: label) {
            Picker(label, selection: $selection) {
                ForEach(currencies, id: \.self) { code in
                    Text(code).tag(code)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(palette.text)
            .plansFieldBackground()
            .accessibilityLabel(Text(label))
        }
    }
}

struct PlansNoteField: View {
    @Environment(\.palette) private var palette

    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        FieldRow(label: label) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.plain)
                .corbieBody()
                .foregroundStyle(palette.text)
                .padding(.vertical, CorbieSpacing.xs)
                .plansFieldBackground()
                .accessibilityLabel(Text(label))
        }
    }
}

struct PlansChipsField<Value: Hashable>: View {
    let label: String
    let values: [Value]
    let title: (Value) -> String
    @Binding var selection: Value

    var body: some View {
        FieldRow(label: label) {
            ScrollView(.horizontal) {
                HStack(spacing: CorbieSpacing.xs) {
                    ForEach(values, id: \.self) { value in
                        Button {
                            selection = value
                        } label: {
                            Chip(label: title(value), isSelected: value == selection)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, CorbieMetrics.hairline)
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct PlansDateField: View {
    @Environment(\.palette) private var palette

    let label: String
    let range: PartialRangeFrom<Date>?
    @Binding var date: Date

    init(label: String, range: PartialRangeFrom<Date>? = nil, date: Binding<Date>) {
        self.label = label
        self.range = range
        _date = date
    }

    var body: some View {
        FieldRow(label: label) {
            Group {
                if let range {
                    DatePicker(label, selection: $date, in: range, displayedComponents: .date)
                } else {
                    DatePicker(label, selection: $date, displayedComponents: .date)
                }
            }
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(palette.accent)
            .plansFieldBackground()
            .accessibilityLabel(Text(label))
        }
    }
}

struct PlansInfoBlock: View {
    @Environment(\.palette) private var palette

    let text: String

    var body: some View {
        Text(text)
            .corbieMono()
            .foregroundStyle(palette.text2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CorbieSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
                    .fill(palette.elevated)
            )
    }
}

struct PlansEditorScaffold<Content: View>: View {
    @Environment(\.palette) private var palette

    private let title: String
    private let saveTitle: String
    private let canSave: Bool
    private let onCancel: () -> Void
    private let onSave: () -> Void
    private let content: Content

    init(
        title: String,
        saveTitle: String,
        canSave: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.saveTitle = saveTitle
        self.canSave = canSave
        self.onCancel = onCancel
        self.onSave = onSave
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    content
                }
                .padding(CorbieSpacing.l)
            }
            .background(palette.bg)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.action.cancel"), action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(saveTitle, action: onSave)
                        .fontWeight(.semibold)
                        .disabled(canSave == false)
                }
            }
        }
    }
}
