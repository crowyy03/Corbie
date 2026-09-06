import CorbieCore
import SwiftUI

struct PersonEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: PersonEditorViewModel

    init(mode: PersonEditorMode) {
        _model = State(initialValue: PersonEditorViewModel(mode: mode))
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    TextFieldRow(
                        label: String(localized: "people.editor.name"),
                        placeholder: String(localized: "people.editor.name.placeholder"),
                        text: $model.name
                    )
                    relationField
                    birthdayField
                    if environment.isPaired {
                        ownerField
                    }
                    noteField
                }
                .padding(.horizontal, CorbieSpacing.l)
                .padding(.vertical, CorbieSpacing.m)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CorbieColorPalette.bg)
            .navigationTitle(Text(titleKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "people.editor.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "people.editor.save")) {
                        Task {
                            if await model.save() { dismiss() }
                        }
                    }
                    .disabled(model.canSave == false)
                }
            }
        }
        .onAppear {
            model.bind(environment)
        }
    }

    private var titleKey: LocalizedStringKey {
        model.mode.person == nil ? "people.editor.title.new" : "people.editor.title.edit"
    }

    private var relationField: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            TextFieldRow(
                label: String(localized: "people.editor.relation"),
                placeholder: String(localized: "people.editor.relation.placeholder"),
                hint: String(localized: "people.editor.relation.hint"),
                text: $model.relation
            )
            if model.suggestions.isEmpty == false {
                ScrollView(.horizontal) {
                    HStack(spacing: CorbieSpacing.xs) {
                        ForEach(model.suggestions) { suggestion in
                            Button {
                                model.apply(suggestion)
                            } label: {
                                Chip(label: suggestion.title())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, CorbieSpacing.xxs)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var birthdayField: some View {
        @Bindable var model = model

        return FieldRow(
            label: String(localized: "people.editor.birthday"),
            hint: String(localized: "people.editor.birthday.hint")
        ) {
            HStack(spacing: CorbieSpacing.xs) {
                Picker(selection: $model.birthdayMonth) {
                    Text("people.editor.birthday.none").tag(Int?.none)
                    ForEach(1...12, id: \.self) { month in
                        Text(PersonBirthday.monthName(month)).tag(Int?.some(month))
                    }
                } label: {
                    Text("people.editor.birthday.month")
                }
                .pickerStyle(.menu)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)

                if let month = model.birthdayMonth {
                    Picker(selection: $model.birthdayDay) {
                        ForEach(1...PersonBirthday.dayCount(month: month), id: \.self) { day in
                            Text(day.formatted(.number)).tag(day)
                        }
                    } label: {
                        Text("people.editor.birthday.day")
                    }
                    .pickerStyle(.menu)
                    .frame(minHeight: CorbieMetrics.minimumTapTarget)
                }
                Spacer(minLength: 0)
            }
            .onChange(of: model.birthdayMonth) {
                model.normalizeDay()
            }
        }
    }

    private var ownerField: some View {
        @Bindable var model = model

        return FieldRow(label: String(localized: "people.editor.owner")) {
            SegmentedPicker(selection: $model.owner, options: PersonOwner.allCases) { owner in
                switch owner {
                case .me: return String(localized: "people.editor.owner.me")
                case .partner: return environment.partnerName
                }
            }
        }
    }

    private var noteField: some View {
        @Bindable var model = model

        return FieldRow(label: String(localized: "people.editor.note")) {
            TextField(
                String(localized: "people.editor.note.placeholder"),
                text: $model.note,
                axis: .vertical
            )
            .lineLimit(2...5)
            .textFieldStyle(.plain)
            .corbieBody()
            .foregroundStyle(CorbieColorPalette.text)
            .padding(.horizontal, CorbieSpacing.s)
            .padding(.vertical, CorbieSpacing.xs)
            .frame(minHeight: CorbieMetrics.minimumTapTarget, alignment: .topLeading)
            .corbieFieldBox()
            .accessibilityLabel(Text("people.editor.note"))
        }
    }
}

#if DEBUG
#Preview {
    PersonEditorView(mode: .new)
        .environment(AppEnvironment.preview())
}
#endif
