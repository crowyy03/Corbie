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

    public init(
        taskAssigned: Bool = true,
        taskTakenOrHandedBack: Bool = true,
        taskDueToday: Bool = true,
        eventSoon: Bool = true,
        dateRadar: Bool = true,
        partnerAddedWish: Bool = true,
        goalUpdates: Bool = true,
        capsuleUpdates: Bool = true,
        voteUpdates: Bool = true
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
    }

    public static let allEnabled = NotificationPrefs()
}
