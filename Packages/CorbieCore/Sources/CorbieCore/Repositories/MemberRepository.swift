import Foundation

public struct MemberDraft: Sendable, Equatable {
    public var appleUserId: String?
    public var displayName: String?
    public var colorKey: String?
    public var birthdayMonth: Int?
    public var birthdayDay: Int?

    public init(
        appleUserId: String? = nil,
        displayName: String? = nil,
        colorKey: String? = nil,
        birthdayMonth: Int? = nil,
        birthdayDay: Int? = nil
    ) {
        self.appleUserId = appleUserId
        self.displayName = displayName
        self.colorKey = colorKey
        self.birthdayMonth = birthdayMonth
        self.birthdayDay = birthdayDay
    }
}

public protocol MemberRepository: Sendable {
    func upsertCurrentMember(appleUserId: String, spaceId: UUID, draft: MemberDraft) async throws -> MemberDTO
    func member(id: UUID) async throws -> MemberDTO?
    func member(appleUserId: String) async throws -> MemberDTO?
    func members(spaceId: UUID) async throws -> [MemberDTO]
    func partner(of memberId: UUID, spaceId: UUID) async throws -> MemberDTO?
    func update(_ member: MemberDTO) async throws -> MemberDTO
    func updatePrefs(memberId: UUID, prefs: NotificationPrefs) async throws -> MemberDTO
    func touchLastSeen(memberId: UUID, at date: Date) async throws
    func setSharesBusyTimes(memberId: UUID, shares: Bool) async throws -> MemberDTO
    func markUsVisited(memberId: UUID, at date: Date) async throws -> MemberDTO
    func markRecapSeen(memberId: UUID, at date: Date) async throws -> MemberDTO
    func delete(id: UUID) async throws
}

extension MemberRepository {
    public func touchLastSeen(memberId: UUID) async throws {
        try await touchLastSeen(memberId: memberId, at: Date())
    }

    @discardableResult
    public func markUsVisited(memberId: UUID) async throws -> MemberDTO {
        try await markUsVisited(memberId: memberId, at: Date())
    }

    @discardableResult
    public func markRecapSeen(memberId: UUID) async throws -> MemberDTO {
        try await markRecapSeen(memberId: memberId, at: Date())
    }
}
