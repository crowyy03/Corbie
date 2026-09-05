import CorbieCore
import SwiftUI

struct EventEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: EventEditorViewModel
    @State private var isSearchingLocation = false

    @MainActor
    init(target: EventEditorTarget, people: [PersonDTO], calendar: Calendar) {
        _model = State(initialValue: EventEditorViewModel(target: target, people: people, calendar: calendar))
    }

    var body: some View {
        @Bindable var model = model

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    TextFieldRow(
                        label: String(localized: "calendar.editor.title"),
                        placeholder: String(localized: "calendar.editor.title.placeholder"),
                        text: $model.title
                    )

                    Toggle(isOn: $model.isAllDay) {
                        Text("calendar.editor.allday")
                            .corbieBody()
                            .foregroundStyle(CorbieColorPalette.text)
                    }
                    .tint(CorbieColorPalette.ice)
                    .frame(minHeight: CorbieMetrics.minimumTapTarget)

                    datePicker(
                        label: String(localized: "calendar.editor.start"),
                        selection: $model.start,
                        onChange: model.startChanged
                    )
                    datePicker(
                        label: String(localized: "calendar.editor.end"),
                        selection: $model.end,
                        onChange: model.endChanged
                    )

                    kindPicker
                    if model.showsPersonPicker {
                        personPicker
                    }
                    locationRow
                    noteRow
                    remindersRow

                    Text("calendar.editor.info")
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
                .padding(CorbieSpacing.l)
            }
            .background(CorbieColorPalette.bg)
            .navigationTitle(
                model.isEditing
                    ? String(localized: "calendar.editor.title.edit")
                    : String(localized: "calendar.editor.title.new")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.action.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.action.save")) {
                        save()
                    }
                    .disabled(model.canSave == false)
                }
            }
            .sheet(isPresented: $isSearchingLocation) {
                LocationSearchView { place in
                    model.place = place
                }
            }
        }
    }

    private func datePicker(label: String, selection: Binding<Date>, onChange: @escaping () -> Void) -> some View {
        FieldRow(label: label) {
            DatePicker(
                label,
                selection: selection,
                displayedComponents: model.isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(CorbieColorPalette.ice)
            .accessibilityLabel(Text(label))
            .onChange(of: selection.wrappedValue) {
                onChange()
            }
        }
    }

    private var kindPicker: some View {
        @Bindable var model = model

        return FieldRow(label: String(localized: "calendar.editor.kind")) {
            Picker(selection: $model.kind) {
                ForEach(EventKind.allCases, id: \.self) { kind in
                    Text(model.formatting.kindLabel(kind)).tag(kind)
                }
            } label: {
                Text("calendar.editor.kind")
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(CorbieColorPalette.ice)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(Text("calendar.editor.kind"))
        }
    }

    @ViewBuilder
    private var personPicker: some View {
        @Bindable var model = model

        if model.people.isEmpty {
            FieldRow(
                label: String(localized: "calendar.editor.person"),
                hint: String(localized: "calendar.editor.person.empty")
            ) {
                Text("calendar.person.none")
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text2)
            }
        } else {
            FieldRow(label: String(localized: "calendar.editor.person")) {
                Picker(selection: $model.personId) {
                    Text("calendar.person.none").tag(UUID?.none)
                    ForEach(model.people) { person in
                        Text(person.name).tag(UUID?.some(person.id))
                    }
                } label: {
                    Text("calendar.editor.person")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(CorbieColorPalette.ice)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(Text("calendar.editor.person"))
            }
        }
    }

    private var locationRow: some View {
        FieldRow(label: String(localized: "calendar.editor.location")) {
            HStack(spacing: CorbieSpacing.s) {
                Button {
                    isSearchingLocation = true
                } label: {
                    VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                        Text(model.place?.name ?? String(localized: "calendar.location.add"))
                            .corbieBody()
                            .foregroundStyle(
                                model.place == nil ? CorbieColorPalette.text2 : CorbieColorPalette.text
                            )
                            .multilineTextAlignment(.leading)
                        if let address = model.place?.address {
                            Text(address)
                                .corbieMono()
                                .foregroundStyle(CorbieColorPalette.text2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: CorbieMetrics.minimumTapTarget, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if model.place != nil {
                    Button {
                        model.place = nil
                    } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(CorbieColorPalette.text2)
                            .frame(
                                width: CorbieMetrics.minimumTapTarget,
                                height: CorbieMetrics.minimumTapTarget
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("calendar.location.clear"))
                }
            }
        }
    }

    private var noteRow: some View {
        @Bindable var model = model

        return FieldRow(
            label: String(localized: "calendar.editor.note"),
            hint: String(localized: "calendar.editor.note.hint")
        ) {
            TextField(
                String(localized: "calendar.editor.note.placeholder"),
                text: $model.note,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .corbieBody()
            .foregroundStyle(CorbieColorPalette.text)
            .lineLimit(3...6)
            .padding(CorbieSpacing.s)
            .background(
                RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
                    .fill(CorbieColorPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
                    .strokeBorder(CorbieColorPalette.border, lineWidth: CorbieMetrics.hairline)
            )
            .accessibilityLabel(Text("calendar.editor.note"))
        }
    }

    private var remindersRow: some View {
        FieldRow(
            label: String(localized: "calendar.editor.reminders"),
            hint: String(localized: "calendar.editor.reminders.hint")
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CorbieSpacing.xs) {
                    ForEach(ReminderOffset.allCases, id: \.self) { offset in
                        Button {
                            model.toggle(offset)
                        } label: {
                            Chip(
                                label: model.formatting.reminderLabel(offset),
                                isSelected: model.reminders.contains(offset)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func save() {
        Task {
            guard await model.save(environment) else { return }
            dismiss()
        }
    }
}

#Preview {
    EventEditorView(target: .create(Date()), people: [], calendar: .current)
        .environment(AppEnvironment.preview())
}
