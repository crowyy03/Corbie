import CorbieCore
import SwiftUI

struct EventDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: EventDetailViewModel
    @State private var isEditing = false
    @State private var isExporting = false
    @State private var isConfirmingDelete = false

    @MainActor
    init(eventId: UUID, calendar: Calendar) {
        _model = State(initialValue: EventDetailViewModel(eventId: eventId, calendar: calendar))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                if let event = model.event {
                    header(event)
                    details(event)
                    exportButton(event)
                    comments
                } else {
                    Text("calendar.detail.missing")
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
            }
            .padding(CorbieSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(CorbieColorPalette.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(String(localized: "common.action.edit")) {
                        isEditing = true
                    }
                    Button(String(localized: "common.action.delete"), role: .destructive) {
                        isConfirmingDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(Text("calendar.detail.actions"))
            }
        }
        .task {
            await model.load(environment)
        }
        .onReceive(NotificationCenter.default.publisher(for: WidgetReloadRequest.notificationName)) { _ in
            Task { await model.load(environment) }
        }
        .onChange(of: model.isDeleted) {
            if model.isDeleted { dismiss() }
        }
        .confirmationDialog(
            String(localized: "calendar.detail.delete.confirm"),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(String(localized: "common.action.delete"), role: .destructive) {
                Task { await model.delete(environment) }
            }
            Button(String(localized: "common.action.cancel"), role: .cancel) {}
        }
        .sheet(isPresented: $isEditing) {
            if let event = model.event {
                EventEditorView(target: .edit(event), people: model.people, calendar: model.calendar)
            }
        }
        .sheet(isPresented: $isExporting) {
            if let event = model.event {
                SystemCalendarEventEditor(event: event, store: model.systemStore) {
                    isExporting = false
                }
                .ignoresSafeArea()
            }
        }
    }

    private func header(_ event: EventDTO) -> some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            Text(event.title)
                .corbieScreenTitle()
                .foregroundStyle(CorbieColorPalette.text)
                .multilineTextAlignment(.leading)
            HStack(spacing: CorbieSpacing.xs) {
                MemberDot(color: environment.memberColor(id: event.createdByMemberId))
                Text(model.formatting.kindLabel(event.kind))
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
            }
        }
    }

    @ViewBuilder
    private func details(_ event: EventDTO) -> some View {
        Card {
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                if let entry = model.entry {
                    FieldRow(label: String(localized: "calendar.detail.when")) {
                        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                            Text(model.formatting.longDate(entry.startDay))
                                .corbieBody()
                                .foregroundStyle(CorbieColorPalette.text)
                            Text(model.formatting.schedule(for: entry))
                                .corbieMono()
                                .foregroundStyle(CorbieColorPalette.text2)
                        }
                    }
                }
                if let person = model.person {
                    FieldRow(label: String(localized: "calendar.detail.person")) {
                        Text(person.name)
                            .corbieBody()
                            .foregroundStyle(CorbieColorPalette.text)
                    }
                }
                if let locationName = event.locationName {
                    FieldRow(label: String(localized: "calendar.detail.location")) {
                        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                            Text(locationName)
                                .corbieBody()
                                .foregroundStyle(CorbieColorPalette.text)
                            if let address = event.address {
                                Text(address)
                                    .corbieMono()
                                    .foregroundStyle(CorbieColorPalette.text2)
                            }
                        }
                    }
                }
                if let note = event.note {
                    FieldRow(label: String(localized: "calendar.detail.note")) {
                        Text(note)
                            .corbieBody()
                            .foregroundStyle(CorbieColorPalette.text)
                    }
                }
                if event.reminderOffsets.isEmpty == false {
                    FieldRow(label: String(localized: "calendar.detail.reminders")) {
                        Text(reminderSummary(event))
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.text2)
                    }
                }
            }
        }
    }

    private func exportButton(_ event: EventDTO) -> some View {
        SecondaryButton(title: String(localized: "calendar.detail.export")) {
            Task {
                guard await model.requestSystemCalendarAccess() else {
                    environment.toasts.show(message: String(localized: "calendar.detail.export.denied"))
                    return
                }
                isExporting = true
            }
        }
    }

    private var comments: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.s) {
            SectionCaps(text: String(localized: "calendar.comments.title"))
            if model.comments.isEmpty {
                Text("calendar.comments.empty")
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
            } else {
                ForEach(model.comments) { comment in
                    commentCard(comment)
                }
            }
            composer
        }
    }

    private func commentCard(_ comment: EventCommentDTO) -> some View {
        Card {
            VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                HStack(spacing: CorbieSpacing.xs) {
                    MemberDot(color: environment.memberColor(id: comment.memberId))
                    Text(environment.memberName(id: comment.memberId))
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                    Spacer(minLength: CorbieSpacing.xs)
                    if let createdAt = comment.createdAt {
                        Text(model.formatting.commentTimestamp(createdAt))
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.text2)
                    }
                }
                Text(comment.text)
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text)
                    .multilineTextAlignment(.leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var composer: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            TextField(
                String(localized: "calendar.comments.placeholder"),
                text: $model.draft,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .corbieBody()
            .foregroundStyle(CorbieColorPalette.text)
            .lineLimit(2...4)
            .padding(CorbieSpacing.s)
            .background(
                RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
                    .fill(CorbieColorPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
                    .strokeBorder(CorbieColorPalette.border, lineWidth: CorbieMetrics.hairline)
            )
            .accessibilityLabel(Text("calendar.comments.placeholder"))

            HStack(spacing: CorbieSpacing.s) {
                Text(remainingText)
                    .corbieMono()
                    .foregroundStyle(
                        model.remainingCharacters < 0 ? CorbieColorPalette.warn : CorbieColorPalette.text2
                    )
                Spacer(minLength: CorbieSpacing.xs)
                PrimaryButton(title: String(localized: "calendar.comments.send")) {
                    Task { await model.addComment(environment) }
                }
                .disabled(model.canSend == false)
                .fixedSize()
            }
        }
    }

    private var remainingText: String {
        String.localizedStringWithFormat(
            String(localized: "calendar.comments.remaining"),
            model.remainingCharacters
        )
    }

    private func reminderSummary(_ event: EventDTO) -> String {
        event.reminderOffsets
            .sorted { $0.days > $1.days }
            .map(model.formatting.reminderLabel)
            .formatted(.list(type: .and))
    }
}
