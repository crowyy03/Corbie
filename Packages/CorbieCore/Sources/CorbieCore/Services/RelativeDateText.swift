import Foundation

public enum TaskSubtitleActor: Sendable, Equatable {
    case you
    case partner(String?)
    case nobody
}

public enum TaskSubtitleAction: String, Sendable, Equatable, CaseIterable {
    case took
    case set
    case done
    case free
}

public struct TaskSubtitle: Sendable, Equatable {
    public let who: TaskSubtitleActor
    public let action: TaskSubtitleAction
    public let relativeDay: String?
    public let dueText: String?
    public let dueDaysAway: Int?
    public let isOverdue: Bool

    public init(
        who: TaskSubtitleActor,
        action: TaskSubtitleAction,
        relativeDay: String?,
        dueText: String?,
        dueDaysAway: Int?,
        isOverdue: Bool
    ) {
        self.who = who
        self.action = action
        self.relativeDay = relativeDay
        self.dueText = dueText
        self.dueDaysAway = dueDaysAway
        self.isOverdue = isOverdue
    }
}

public struct RelativeDateText: Sendable {
    public let locale: Locale
    public let calendar: Calendar

    public init(locale: Locale = .current, calendar: Calendar = .current) {
        self.locale = locale
        var configured = calendar
        configured.locale = locale
        self.calendar = configured
    }

    public func relativeDay(for date: Date, now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        let from = calendar.startOfDay(for: now)
        let to = calendar.startOfDay(for: date)
        return formatter.localizedString(for: to, relativeTo: from)
    }

    public func dueText(for date: Date, now: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        formatter.setLocalizedDateFormatFromTemplate(sameYear ? "MMMd" : "yMMMd")
        return formatter.string(from: date)
    }

    public func daysAway(from now: Date, to date: Date) -> Int? {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day
    }

    public func subtitle(
        for task: TaskDTO,
        viewerMemberId: UUID?,
        partnerName: String?,
        now: Date
    ) -> TaskSubtitle {
        let who: TaskSubtitleActor
        let action: TaskSubtitleAction
        let stamp: Date?
        if task.isDone {
            who = subtitleActor(for: task.doneByMemberId, viewerMemberId: viewerMemberId, partnerName: partnerName)
            action = .done
            stamp = task.doneAt
        } else if let assignee = task.assigneeMemberId {
            who = subtitleActor(for: assignee, viewerMemberId: viewerMemberId, partnerName: partnerName)
            action = task.takenAt == nil ? .set : .took
            stamp = task.takenAt ?? task.createdAt
        } else {
            who = .nobody
            action = .free
            stamp = task.createdAt
        }
        let dueDaysAway = task.dueAt.flatMap { daysAway(from: now, to: $0) }
        return TaskSubtitle(
            who: who,
            action: action,
            relativeDay: stamp.map { relativeDay(for: $0, now: now) },
            dueText: task.dueAt.map { dueText(for: $0, now: now) },
            dueDaysAway: dueDaysAway,
            isOverdue: task.isDone == false && (dueDaysAway ?? 0) < 0
        )
    }

    private func subtitleActor(
        for memberId: UUID?,
        viewerMemberId: UUID?,
        partnerName: String?
    ) -> TaskSubtitleActor {
        guard let memberId else { return .nobody }
        if let viewerMemberId, memberId == viewerMemberId { return .you }
        return .partner(partnerName)
    }
}
