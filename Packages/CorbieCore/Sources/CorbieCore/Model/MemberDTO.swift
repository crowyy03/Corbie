import Foundation

public struct MemberDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var spaceId: UUID?
    public var appleUserHash: String?
    public var displayName: String?
    public var colorKey: String?
    public var birthdayMonth: Int?
    public var birthdayDay: Int?
    public var joinedAt: Date?
    public var lastSeenAt: Date?
    public var sharesBusyTimes: Bool
    public var lastRecapSeenAt: Date?
    public var lastUsVisitAt: Date?
    public var notificationPrefs: NotificationPrefs

    public init(
        id: UUID,
        spaceId: UUID? = nil,
        appleUserHash: String? = nil,
        displayName: String? = nil,
        colorKey: String? = nil,
        birthdayMonth: Int? = nil,
        birthdayDay: Int? = nil,
        joinedAt: Date? = nil,
        lastSeenAt: Date? = nil,
        sharesBusyTimes: Bool = false,
        lastRecapSeenAt: Date? = nil,
        lastUsVisitAt: Date? = nil,
        notificationPrefs: NotificationPrefs = .allEnabled
    ) {
        self.id = id
        self.spaceId = spaceId
        self.appleUserHash = appleUserHash
        self.displayName = displayName
        self.colorKey = colorKey
        self.birthdayMonth = birthdayMonth
        self.birthdayDay = birthdayDay
        self.joinedAt = joinedAt
        self.lastSeenAt = lastSeenAt
        self.sharesBusyTimes = sharesBusyTimes
        self.lastRecapSeenAt = lastRecapSeenAt
        self.lastUsVisitAt = lastUsVisitAt
        self.notificationPrefs = notificationPrefs
    }

    public init(_ member: Member) {
        self.init(
            id: member.id ?? UUID(),
            spaceId: member.space?.id,
            appleUserHash: member.appleUserHash,
            displayName: member.displayName,
            colorKey: member.colorKey,
            birthdayMonth: member.birthdayMonth?.intValue,
            birthdayDay: member.birthdayDay?.intValue,
            joinedAt: member.joinedAt,
            lastSeenAt: member.lastSeenAt,
            sharesBusyTimes: member.sharesBusyTimes,
            lastRecapSeenAt: member.lastRecapSeenAt,
            lastUsVisitAt: member.lastUsVisitAt,
            notificationPrefs: member.notificationPrefs
        )
    }

    public var hasBirthday: Bool { birthdayMonth != nil && birthdayDay != nil }
}
