import CoreData
import Foundation

public struct CoreDataMemberRepository: MemberRepository {
    private let access: CoreDataAccess

    public init(stack: CoreDataStack) {
        access = CoreDataAccess(stack: stack)
    }

    public func upsertCurrentMember(appleUserId: String, spaceId: UUID, draft: MemberDraft) async throws -> MemberDTO {
        let hash = AppleUserHash.value(appleUserId)
        return try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: spaceId, in: context)
            let existing: [Member] = try ManagedFetch.all(
                Member.entityName,
                predicate: NSPredicate(format: "appleUserHash == %@", hash),
                in: context
            )
            let member: Member
            if let found = existing.first {
                member = found
            } else {
                member = Member(context: context)
                context.assign(member, toStoreOf: space)
            }
            member.appleUserHash = hash
            member.space = space
            if let displayName = draft.displayName { member.displayName = displayName }
            if let colorKey = draft.colorKey { member.colorKey = colorKey }
            if let month = draft.birthdayMonth { member.birthdayMonth = NSNumber(value: month) }
            if let day = draft.birthdayDay { member.birthdayDay = NSNumber(value: day) }
            if member.joinedAt == nil { member.joinedAt = Date() }
            return MemberDTO(member)
        }
    }

    public func member(id: UUID) async throws -> MemberDTO? {
        try await access.read { context in
            let member: Member? = try ManagedFetch.first(Member.entityName, id: id, in: context)
            return member.map(MemberDTO.init)
        }
    }

    public func member(appleUserId: String) async throws -> MemberDTO? {
        let hash = AppleUserHash.value(appleUserId)
        return try await access.read { context in
            let members: [Member] = try ManagedFetch.all(
                Member.entityName,
                predicate: NSPredicate(format: "appleUserHash == %@", hash),
                in: context
            )
            return members.first.map(MemberDTO.init)
        }
    }

    public func members(spaceId: UUID) async throws -> [MemberDTO] {
        try await access.read { context in
            let members: [Member] = try ManagedFetch.all(
                Member.entityName,
                predicate: ManagedFetch.spaceRelation(spaceId),
                sort: [NSSortDescriptor(key: "joinedAt", ascending: true)],
                in: context
            )
            return members.map(MemberDTO.init)
        }
    }

    public func partner(of memberId: UUID, spaceId: UUID) async throws -> MemberDTO? {
        try await members(spaceId: spaceId).first { $0.id != memberId }
    }

    public func update(_ member: MemberDTO) async throws -> MemberDTO {
        try await access.write { context in
            let entity: Member = try ManagedFetch.require(Member.entityName, id: member.id, in: context)
            entity.displayName = member.displayName
            entity.colorKey = member.colorKey
            entity.birthdayMonth = member.birthdayMonth.map(NSNumber.init(value:))
            entity.birthdayDay = member.birthdayDay.map(NSNumber.init(value:))
            entity.notificationPrefs = member.notificationPrefs
            return MemberDTO(entity)
        }
    }

    public func updatePrefs(memberId: UUID, prefs: NotificationPrefs) async throws -> MemberDTO {
        try await access.write { context in
            let member: Member = try ManagedFetch.require(Member.entityName, id: memberId, in: context)
            member.notificationPrefs = prefs
            return MemberDTO(member)
        }
    }

    public func touchLastSeen(memberId: UUID, at date: Date) async throws {
        try await access.write { context in
            let member: Member = try ManagedFetch.require(Member.entityName, id: memberId, in: context)
            member.lastSeenAt = date
        }
    }

    public func setSharesBusyTimes(memberId: UUID, shares: Bool) async throws -> MemberDTO {
        try await access.write { context in
            let member: Member = try ManagedFetch.require(Member.entityName, id: memberId, in: context)
            member.sharesBusyTimes = shares
            return MemberDTO(member)
        }
    }

    public func markUsVisited(memberId: UUID, at date: Date) async throws -> MemberDTO {
        try await access.write { context in
            let member: Member = try ManagedFetch.require(Member.entityName, id: memberId, in: context)
            member.lastUsVisitAt = date
            return MemberDTO(member)
        }
    }

    public func markRecapSeen(memberId: UUID, at date: Date) async throws -> MemberDTO {
        try await access.write { context in
            let member: Member = try ManagedFetch.require(Member.entityName, id: memberId, in: context)
            member.lastRecapSeenAt = date
            return MemberDTO(member)
        }
    }

    public func delete(id: UUID) async throws {
        try await access.write { context in
            guard let member: Member = try ManagedFetch.first(Member.entityName, id: id, in: context) else { return }
            context.delete(member)
        }
    }
}
