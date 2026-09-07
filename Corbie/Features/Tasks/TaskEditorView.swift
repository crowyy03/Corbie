import CorbieCore
import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: TaskEditorViewModel

    private let calendar: Calendar

    init(model: TaskEditorViewModel, calendar: Calendar = .current) {
        _model = State(initialValue: model)
        self.calendar = calendar
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    TextFieldRow(
                        label: String(localized: "tasks.editor.field.what"),
                        placeholder: String(localized: "tasks.editor.field.what.placeholder"),
                        text: $model.title
                    )

                    FieldRow(label: String(localized: "tasks.editor.field.who"), hint: model.assigneeHint) {
                        SegmentedPicker(selection: $model.assignee, options: model.assigneeOptions) { option in
                            label(for: option)
                        }
                    }

                    FieldRow(label: String(localized: "tasks.editor.field.due")) {
                        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                            HStack(spacing: CorbieSpacing.s) {
                                Text("tasks.editor.due.toggle")
                                    .corbieBody()
                                    .foregroundStyle(CorbieColorPalette.text)
                                Spacer(minLength: 0)
                                Toggle(isOn: $model.hasDueDate) { EmptyView() }
                                    .labelsHidden()
                                    .tint(CorbieColorPalette.ice)
                            }
                            .frame(minHeight: CorbieMetrics.minimumTapTarget)
                            .contentShape(Rectangle())
                            .onTapGesture { model.hasDueDate.toggle() }
                            .accessibilityElement(children: .combine)
                            if model.hasDueDate {
                                DatePicker(
                                    selection: $model.dueDate,
                                    displayedComponents: .date
                                ) {
                                    Text("tasks.editor.due.date")
                                        .corbieBody()
                                        .foregroundStyle(CorbieColorPalette.text)
                                }
                                .datePickerStyle(.compact)
                                .tint(CorbieColorPalette.ice)
                                .frame(minHeight: CorbieMetrics.minimumTapTarget)
                            }
                        }
                    }

                    FieldRow(
                        label: String(localized: "tasks.editor.field.repeat"),
                        hint: model.repeatOption == .weekdays
                            ? String(localized: "tasks.editor.repeat.weekdays.hint")
                            : nil
                    ) {
                        VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                            Picker(selection: $model.repeatOption) {
                                ForEach(TaskRepeatOption.allCases) { option in
                                    Text(label(for: option)).tag(option)
                                }
                            } label: {
                                Text("tasks.editor.field.repeat")
                            }
                            .pickerStyle(.menu)
                            .tint(CorbieColorPalette.text)
                            if model.repeatOption == .weekdays {
                                weekdayPicker
                            }
                        }
                    }

                    FieldRow(label: String(localized: "tasks.editor.field.note")) {
                        TextField(
                            String(localized: "tasks.editor.note.placeholder"),
                            text: $model.note,
                            axis: .vertical
                        )
                        .textFieldStyle(.plain)
                        .lineLimit(3...6)
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .padding(CorbieSpacing.s)
                        .frame(minHeight: CorbieMetrics.controlHeight, alignment: .top)
                        .corbieFieldBox()
                        .accessibilityLabel(Text("tasks.editor.field.note"))
                    }

                    Card {
                        Text("tasks.editor.info")
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.text2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(CorbieSpacing.l)
            }
            .background(CorbieColorPalette.bg)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(model.isEditing ? "tasks.editor.title.edit" : "tasks.editor.title.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.action.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("tasks.editor.action.save") {
                        Task {
                            if await model.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(model.canSave == false)
                }
            }
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: CorbieSpacing.xxs) {
            ForEach(orderedWeekdays, id: \.self) { weekday in
                Button {
                    model.toggleWeekday(weekday)
                } label: {
                    Chip(label: symbol(for: weekday), isSelected: model.weekdays.contains(weekday))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(fullSymbol(for: weekday)))
                .accessibilityAddTraits(model.weekdays.contains(weekday) ? [.isSelected, .isButton] : .isButton)
            }
        }
    }

    private var orderedWeekdays: [Int] {
        (0..<7).map { offset in (calendar.firstWeekday - 1 + offset) % 7 + 1 }
    }

    private func symbol(for weekday: Int) -> String {
        calendar.veryShortWeekdaySymbols[weekday - 1]
    }

    private func fullSymbol(for weekday: Int) -> String {
        calendar.weekdaySymbols[weekday - 1]
    }

    private func label(for option: TaskAssigneeOption) -> String {
        switch option {
        case .nobody:
            return String(localized: "tasks.editor.who.nobody")
        case .me:
            return String(localized: "tasks.editor.who.me")
        case .partner:
            return model.partnerName
        }
    }

    private func label(for option: TaskRepeatOption) -> String {
        switch option {
        case .none:
            return String(localized: "tasks.editor.repeat.none")
        case .daily:
            return String(localized: "tasks.editor.repeat.daily")
        case .weekly:
            return String(localized: "tasks.editor.repeat.weekly")
        case .everyTwoWeeks:
            return String(localized: "tasks.editor.repeat.everytwoweeks")
        case .monthly:
            return String(localized: "tasks.editor.repeat.monthly")
        case .quarterly:
            return String(localized: "tasks.editor.repeat.quarterly")
        case .weekdays:
            return String(localized: "tasks.editor.repeat.weekdays")
        }
    }
}

#if DEBUG
#Preview {
    let environment = AppEnvironment.preview()
    return TaskEditorView(
        model: TaskEditorViewModel(
            task: nil,
            context: TasksContext(spaceId: UUID(), memberId: UUID(), partnerId: UUID(), partnerName: "Sofia"),
            repository: environment.repositories.tasks,
            notifications: TaskDueNotifications(scheduler: environment.notifications),
            analytics: environment.analytics
        )
    )
}
#endif
