import Foundation

public enum RecurrenceEngine {
    public static let maximumSteps = 2000

    public static func nextOccurrence(
        for task: TaskDTO,
        completedAt: Date,
        calendar: Calendar = .current
    ) -> Date? {
        nextOccurrence(
            recurrence: task.recurrence,
            dueAt: task.dueAt,
            completedAt: completedAt,
            calendar: calendar
        )
    }

    public static func nextAssignee(after current: UUID?, among members: [UUID]) -> UUID? {
        let ordered = members.sorted { $0.uuidString < $1.uuidString }
        guard ordered.count >= 2 else { return current }
        guard let current, let index = ordered.firstIndex(of: current) else { return ordered.first }
        return ordered[(index + 1) % ordered.count]
    }

    public static func nextOccurrence(
        recurrence: Recurrence,
        dueAt: Date?,
        completedAt: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard recurrence.repeats else { return nil }
        var cursor = dueAt ?? completedAt
        for _ in 0..<maximumSteps {
            guard let candidate = recurrence.nextDate(after: cursor, calendar: calendar), candidate > cursor else {
                return nil
            }
            if candidate > completedAt {
                return candidate
            }
            cursor = candidate
        }
        return nil
    }
}
