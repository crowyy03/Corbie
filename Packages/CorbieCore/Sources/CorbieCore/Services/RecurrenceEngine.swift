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

    public static func occurrences(
        recurrence: Recurrence,
        dueAt: Date?,
        completedAt: Date,
        count: Int,
        calendar: Calendar = .current
    ) -> [Date] {
        guard count > 0 else { return [] }
        var result: [Date] = []
        var completion = completedAt
        var due = dueAt
        while result.count < count {
            guard let next = nextOccurrence(
                recurrence: recurrence,
                dueAt: due,
                completedAt: completion,
                calendar: calendar
            ) else { break }
            result.append(next)
            due = next
            completion = next
        }
        return result
    }
}
