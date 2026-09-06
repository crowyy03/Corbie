import Foundation

public struct NotificationPrefs: Codable, Sendable, Equatable, Hashable {
    public var taskAssigned: Bool
    public var taskTakenOrHandedBack: Bool
    public var taskDueToday: Bool
    public var eventSoon: Bool
    public var dateRadar: Bool
    public var partnerAddedWish: Bool
    public var goalUpdates: Bool
    public var capsuleUpdates: Bool
    public var voteUpdates: Bool
    public var weeklyRecap: Bool

    public init(
        taskAssigned: Bool = true,
        taskTakenOrHandedBack: Bool = true,
        taskDueToday: Bool = true,
        eventSoon: Bool = true,
        dateRadar: Bool = true,
        partnerAddedWish: Bool = true,
        goalUpdates: Bool = true,
        capsuleUpdates: Bool = true,
        voteUpdates: Bool = true,
        weeklyRecap: Bool = true
    ) {
        self.taskAssigned = taskAssigned
        self.taskTakenOrHandedBack = taskTakenOrHandedBack
        self.taskDueToday = taskDueToday
        self.eventSoon = eventSoon
        self.dateRadar = dateRadar
        self.partnerAddedWish = partnerAddedWish
        self.goalUpdates = goalUpdates
        self.capsuleUpdates = capsuleUpdates
        self.voteUpdates = voteUpdates
        self.weeklyRecap = weeklyRecap
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func flag(_ key: CodingKeys) throws -> Bool {
            try container.decodeIfPresent(Bool.self, forKey: key) ?? true
        }
        self.init(
            taskAssigned: try flag(.taskAssigned),
            taskTakenOrHandedBack: try flag(.taskTakenOrHandedBack),
            taskDueToday: try flag(.taskDueToday),
            eventSoon: try flag(.eventSoon),
            dateRadar: try flag(.dateRadar),
            partnerAddedWish: try flag(.partnerAddedWish),
            goalUpdates: try flag(.goalUpdates),
            capsuleUpdates: try flag(.capsuleUpdates),
            voteUpdates: try flag(.voteUpdates),
            weeklyRecap: try flag(.weeklyRecap)
        )
    }

    public static let allEnabled = NotificationPrefs()
}
