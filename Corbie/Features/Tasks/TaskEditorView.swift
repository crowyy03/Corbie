import CorbieCore
import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: TaskEditorViewModel
    @State private var isSearchingPlace = false
    @State private var isCreatingFolder = false

    private let calendar: Calendar

    init(model: TaskEditorViewModel, opensPlaceSearch: Bool = false, calendar: Calendar = .current) {
        _model = State(initialValue: model)
        _isSearchingPlace = State(initialValue: opensPlaceSearch)
        self.calendar = calendar
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    TextFieldRow(
                        label: String(localized: "tasks.editor.field.what"),
                        placeholder: model.titlePlaceholder,
                        text: $model.title
                    )

                    FieldRow(label: String(localized: "tasks.editor.field.folder")) {
                        folderPicker
                    }

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
                            .frame(minHeight: CorbieMetrics.minimumTapTarget)
                            if model.repeatOption == .weekdays {
                                weekdayPicker
                            }
                        }
                    }

                    FieldRow(label: String(localized: "tasks.editor.field.place")) {
                        placeRow
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
                    .fontWeight(.semibold)
                    .disabled(model.canSave == false)
                }
            }
            .sheet(isPresented: $isSearchingPlace) {
                PlaceSearchView(
                    title: String(localized: "place.search.title"),
                    placeholder: String(localized: "place.search.placeholder")
                ) { place in
                    model.place = place
                }
            }
            .sheet(isPresented: $isCreatingFolder) {
                FolderEditorView(model: model.makeFolderEditorModel()) { folder in
                    model.folderId = folder.id
                    Task { await model.loadFolders() }
                }
            }
            .task {
                await model.loadFolders()
            }
        }
    }

    private var folderPicker: some View {
        Menu {
            Button {
                model.folderId = nil
            } label: {
                Text("tasks.editor.folder.none")
            }
            ForEach(model.folders) { folder in
                Button(folder.title) {
                    model.folderId = folder.id
                }
            }
            Divider()
            Button {
                isCreatingFolder = true
            } label: {
                Text("tasks.editor.folder.new")
            }
        } label: {
            HStack(spacing: CorbieSpacing.xs) {
                Text(model.folderTitle)
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(CorbieColorPalette.text2)
            }
            .padding(.horizontal, CorbieSpacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
            .corbieFieldBox()
        }
        .accessibilityLabel(Text("tasks.editor.field.folder"))
        .accessibilityValue(Text(model.folderTitle))
    }

    private var placeRow: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            if let place = model.place {
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text(place.name)
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                    if let address = place.address, address.isEmpty == false {
                        Text(address)
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.text2)
                    }
                }
                .padding(.horizontal, CorbieSpacing.s)
                .padding(.vertical, CorbieSpacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
                .corbieFieldBox()
            }
            HStack(spacing: CorbieSpacing.xs) {
                Button {
                    isSearchingPlace = true
                } label: {
                    Chip(label: model.place == nil
                        ? String(localized: "tasks.editor.place.add")
                        : String(localized: "tasks.editor.place.change"))
                }
                .buttonStyle(.plain)
                if model.place != nil {
                    Button {
                        model.place = nil
                    } label: {
                        Chip(label: String(localized: "tasks.editor.place.remove"))
                    }
                    .buttonStyle(.plain)
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
        case .monthly:
            return String(localized: "tasks.editor.repeat.monthly")
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
