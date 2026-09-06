import Foundation

public enum BusyRangeSource: String, Sendable, Equatable, CaseIterable {
    case device
    case corbie
}

public struct BusyRange: Sendable, Equatable, Hashable {
    public let memberId: UUID
    public let start: Date
    public let end: Date

    public init(memberId: UUID, start: Date, end: Date) {
        self.memberId = memberId
        self.start = start
        self.end = end
    }
}

public enum BusyIntervals {
    public static func merged(_ intervals: [DateInterval]) -> [DateInterval] {
        let ordered = intervals.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        var merged: [DateInterval] = []
        for interval in ordered {
            guard let last = merged.last else {
                merged.append(interval)
                continue
            }
            if interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        return merged
    }
}

public struct WorkingHours: Sendable, Equatable {
    public static let standard = WorkingHours(startHour: 8, endHour: 23)

    public let startHour: Int
    public let endHour: Int

    public init(startHour: Int, endHour: Int) {
        self.startHour = min(max(startHour, 0), 23)
        self.endHour = min(max(endHour, 0), 23)
    }
}

public struct FreeSlotFilters: Sendable, Equatable {
    public static let eveningStartHour = 18
    public static let defaultMinimumDuration: TimeInterval = 60 * 60

    public let eveningsOnly: Bool
    public let weekendsOnly: Bool
    public let minimumDuration: TimeInterval

    public init(
        eveningsOnly: Bool = false,
        weekendsOnly: Bool = false,
        minimumDuration: TimeInterval = FreeSlotFilters.defaultMinimumDuration
    ) {
        self.eveningsOnly = eveningsOnly
        self.weekendsOnly = weekendsOnly
        self.minimumDuration = minimumDuration
    }
}

public struct FreeSlotParticipant: Sendable, Equatable {
    public let memberId: UUID
    public let sharesBusyTimes: Bool

    public init(memberId: UUID, sharesBusyTimes: Bool) {
        self.memberId = memberId
        self.sharesBusyTimes = sharesBusyTimes
    }
}

public struct FreeSlot: Sendable, Equatable, Identifiable {
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let partnerLabel: String?

    public var id: Date { start }
    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public init(start: Date, end: Date, isAllDay: Bool, partnerLabel: String?) {
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.partnerLabel = partnerLabel
    }
}

public enum FreeSlotResult: Sendable, Equatable {
    case slots([FreeSlot])
    case partnerHasNoData
    case viewerHasNoData
    case none
}
