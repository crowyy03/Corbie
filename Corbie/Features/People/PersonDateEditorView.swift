import CorbieCore
import SwiftUI

struct PersonDateEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: PersonDateEditorViewModel

    init(personId: UUID, mode: PersonDateEditorMode) {
        _model = State(initialValue: PersonDateEditorViewModel(personId: personId, mode: mode))
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    TextFieldRow(
                        label: String(localized: "people.date.title"),
                        placeholder: String(localized: "people.date.title.placeholder"),
                        text: $model.title
                    )
                    dayField
                    remindersField
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
        model.mode.date == nil ? "people.date.editor.title.new" : "people.date.editor.title.edit"
    }

    private var dayField: some View {
        @Bindable var model = model

        return FieldRow(
            label: String(localized: "people.date.when"),
            hint: String(localized: "people.date.year.hint")
        ) {
            HStack(spacing: CorbieSpacing.xs) {
                Picker(selection: $model.month) {
                    ForEach(1...12, id: \.self) { month in
                        Text(PersonBirthday.monthName(month)).tag(month)
                    }
                } label: {
                    Text("people.editor.birthday.month")
                }
                .pickerStyle(.menu)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)

                Picker(selection: $model.day) {
                    ForEach(1...PersonBirthday.dayCount(month: model.month), id: \.self) { day in
                        Text(day.formatted(.number)).tag(day)
                    }
                } label: {
                    Text("people.editor.birthday.day")
                }
                .pickerStyle(.menu)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)

                Picker(selection: $model.year) {
                    Text("people.editor.birthday.year.none").tag(Int?.none)
                    ForEach(PersonBirthday.yearOptions(), id: \.self) { year in
                        Text(year.formatted(.number.grouping(.never))).tag(Int?.some(year))
                    }
                } label: {
                    Text("people.editor.birthday.year")
                }
                .pickerStyle(.menu)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)

                Spacer(minLength: 0)
            }
            .onChange(of: model.month) {
                model.normalizeDay()
            }
        }
    }

    private var remindersField: some View {
        @Bindable var model = model

        return FieldRow(
            label: String(localized: "people.date.reminders"),
            hint: String(localized: "people.date.reminders.hint")
        ) {
            Toggle(isOn: $model.remindersEnabled) {
                Text("people.date.reminders")
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text)
            }
            .tint(CorbieColorPalette.ice)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
        }
    }
}

#if DEBUG
#Preview {
    PersonDateEditorView(personId: UUID(), mode: .new)
        .environment(AppEnvironment.preview())
}
#endif
