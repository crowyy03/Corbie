import CorbieCore
import Foundation
import Observation

enum TaskAssigneeOption: String, CaseIterable, Identifiable, Hashable, Sendable {
    case nobody
    case me
    case partner

    var id: String { rawValue }

    var analyticsAssignee: AnalyticsAssignee {
        switch self {
        case .nobody: return .nobody
        case .me: return .me
        case .partner: return .partner
        }
    }
}

enum TaskRepeatOption: String, CaseIterable, Identifiable, Hashable, Sendable {
    case none
    case daily
    case weekly
    case everyTwoWeeks
    case monthly
    case quarterly
    case weekdays

    var id: String { rawValue }

    init(_ recurrence: Recurrence) {
        switch recurrence {
        case .none: self = .none
        case .daily: self = .daily
        case .weekly: self = .weekly
        case .everyTwoWeeks: self = .everyTwoWeeks
        case .monthly: self = .monthly
        case .quarterly: self = .quarterly
        case .weekdays: self = .weekdays
        }
    }
}

@MainActor
@Observable
final class TaskEditorViewModel {
    var title: String
    var note: String
    var assignee: TaskAssigneeOption
    var hasDueDate: Bool
    var dueDate: Date
    var repeatOption: TaskRepeatOption
    var weekdays: Set<Int>
    private(set) var isSaving = false

    @ObservationIgnored var onError: ((any Error) -> Void)?

    @ObservationIgnored let existingTask: TaskDTO?
    @ObservationIgnored private let context: TasksContext
    @ObservationIgnored private let repository: any TaskRepository
    @ObservationIgnored private let notifications: TaskDueNotifications
    @ObservationIgnored private let analytics: any AnalyticsRecording
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: @Sendable () -> Date

    init(
        task: TaskDTO?,
        context: TasksContext,
        repository: any TaskRepository,
        notifications: TaskDueNotifications,
        analytics: any AnalyticsRecording,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        existingTask = task
        self.context = context
        self.repository = repository
        self.notifications = notifications
        self.analytics = analytics
        self.calendar = calendar
        self.now = now
        title = task?.title ?? ""
        note = task?.note ?? ""
        assignee = TaskEditorViewModel.option(for: task?.assigneeMemberId, context: context)
        hasDueDate = task?.dueAt != nil
        dueDate = task?.dueAt ?? calendar.startOfDay(for: now())
        repeatOption = TaskRepeatOption(task?.recurrence ?? .none)
        if case let .weekdays(days) = task?.recurrence ?? .none {
            weekdays = Set(days)
        } else {
            weekdays = []
        }
    }

    var isEditing: Bool { existingTask != nil }

    var isPaired: Bool { context.partnerId != nil }

    var partnerName: String { context.partnerName ?? String(localized: "member.name.partner") }

    var assigneeOptions: [TaskAssigneeOption] {
        isPaired ? TaskAssigneeOption.allCases : [.nobody, .me]
    }

    var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && isSaving == false
    }

    var assigneeHint: String {
        switch assignee {
        case .nobody:
            return String(localized: "tasks.editor.who.hint.nobody")
        case .me:
            return String(localized: "tasks.editor.who.hint.me")
        case .partner:
            return String(format: String(localized: "tasks.editor.who.hint.partner"), partnerName)
        }
    }

    var recurrence: Recurrence {
        switch repeatOption {
        case .none:
            return .none
        case .daily:
            return .daily
        case .weekly:
            return .weekly
        case .everyTwoWeeks:
            return .everyTwoWeeks
        case .monthly:
            return .monthly
        case .quarterly:
            return .quarterly
        case .weekdays:
            return weekdays.isEmpty ? .none : .weekdays(weekdays.sorted())
        }
    }

    func toggleWeekday(_ weekday: Int) {
        if weekdays.contains(weekday) {
            weekdays.remove(weekday)
        } else {
            weekdays.insert(weekday)
        }
    }

    func save() async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false, isSaving == false else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            let saved = try await store(title: trimmedTitle)
            await notifications.sync(task: saved, prefs: context.prefs, now: now())
            return true
        } catch {
            onError?(error)
            return false
        }
    }

    private func store(title: String) async throws -> TaskDTO {
        let dueAt = hasDueDate ? calendar.startOfDay(for: dueDate) : nil
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if var task = existingTask {
            task.title = title
            task.note = trimmedNote.isEmpty ? nil : trimmedNote
            task.assigneeMemberId = assigneeMemberId
            task.dueAt = dueAt
            task.recurrence = recurrence
            return try await repository.update(task)
        }
        guard let spaceId = context.spaceId else {
            throw CorbieError.notFound("space for a new task")
        }
        let created = try await repository.create(
            TaskDraft(
                spaceId: spaceId,
                title: title,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                assigneeMemberId: assigneeMemberId,
                dueAt: dueAt,
                recurrence: recurrence,
                createdByMemberId: context.memberId
            )
        )
        analytics.record(.taskCreated(assignee: assignee.analyticsAssignee))
        return created
    }

    private var assigneeMemberId: UUID? {
        switch assignee {
        case .nobody: return nil
        case .me: return context.memberId
        case .partner: return context.partnerId
        }
    }

    private static func option(for assigneeId: UUID?, context: TasksContext) -> TaskAssigneeOption {
        guard let assigneeId else { return .nobody }
        if assigneeId == context.memberId { return .me }
        if assigneeId == context.partnerId { return .partner }
        return .nobody
    }
}
