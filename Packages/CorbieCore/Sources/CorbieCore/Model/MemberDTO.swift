import Foundation

public struct MemberDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var spaceId: UUID?
    public var appleUserId: String?
    public var displayName: String?
    public var colorKey: String?
    public var birthdayMonth: Int?
    public var birthdayDay: Int?
    public var joinedAt: Date?
    public var lastSeenAt: Date?
    public var notificationPrefs: NotificationPrefs

    public init(
        id: UUID,
        spaceId: UUID? = nil,
        appleUserId: String? = nil,
        displayName: String? = nil,
        colorKey: String? = nil,
        birthdayMonth: Int? = nil,
        birthdayDay: Int? = nil,
        joinedAt: Date? = nil,
        lastSeenAt: Date? = nil,
        notificationPrefs: NotificationPrefs = .allEnabled
    ) {
        self.id = id
        self.spaceId = spaceId
        self.appleUserId = appleUserId
        self.displayName = displayName
        self.colorKey = colorKey
        self.birthdayMonth = birthdayMonth
        self.birthdayDay = birthdayDay
        self.joinedAt = joinedAt
        self.lastSeenAt = lastSeenAt
        self.notificationPrefs = notificationPrefs
    }

    public init(_ member: Member) {
        self.init(
            id: member.id ?? UUID(),
            spaceId: member.space?.id,
            appleUserId: member.appleUserId,
            displayName: member.displayName,
            colorKey: member.colorKey,
            birthdayMonth: member.birthdayMonth?.intValue,
            birthdayDay: member.birthdayDay?.intValue,
            joinedAt: member.joinedAt,
            lastSeenAt: member.lastSeenAt,
            notificationPrefs: member.notificationPrefs
        )
    }

    public var hasBirthday: Bool { birthdayMonth != nil && birthdayDay != nil }
}
