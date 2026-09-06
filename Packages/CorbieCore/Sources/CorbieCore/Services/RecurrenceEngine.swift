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
