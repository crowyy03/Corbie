import CoreData
import Foundation

public struct CoreDataMemberRepository: MemberRepository {
    private let access: CoreDataAccess

    public init(stack: CoreDataStack) {
        access = CoreDataAccess(stack: stack)
    }

    public func upsertCurrentMember(
        appleUserId: String,
        spaceId: UUID,
        draft: MemberDraft,
        theme: CorbieTheme
    ) async throws -> MemberSaveResult {
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
            if let month = draft.birthdayMonth { member.birthdayMonth = NSNumber(value: month) }
            if let day = draft.birthdayDay { member.birthdayDay = NSNumber(value: day) }
            if member.joinedAt == nil { member.joinedAt = Date() }
            let requested = draft.colorKey ?? member.colorKey
            return try MemberColorAssignment.apply(requested: requested, to: member, theme: theme, in: context)
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
                sort: [NSSortDescriptor(key: "joinedAt", ascending: true), NSSortDescriptor(key: "id", ascending: true)],
                in: context
            )
            return members.map(MemberDTO.init)
        }
    }

    public func partner(of memberId: UUID, spaceId: UUID) async throws -> MemberDTO? {
        try await members(spaceId: spaceId).first { $0.id != memberId }
    }

    public func update(_ edited: MemberDTO, from original: MemberDTO, theme: CorbieTheme) async throws -> MemberSaveResult {
        let changes = try FieldChanges(edited, from: original)
        return try await access.write { context in
            let member: Member = try ManagedFetch.require(Member.entityName, id: edited.id, in: context)
            changes.write(\.displayName) { member.displayName = $0 }
            if changes.changed(\.birthdayMonth) || changes.changed(\.birthdayDay) {
                CoreDataMemberRepository.write(month: edited.birthdayMonth, day: edited.birthdayDay, to: member)
            }
            guard changes.changed(\.colorKey) else { return MemberSaveResult(member: MemberDTO(member)) }
            return try MemberColorAssignment.apply(requested: edited.colorKey, to: member, theme: theme, in: context)
        }
    }

    public func setDisplayName(memberId: UUID, _ name: String?) async throws -> MemberDTO {
        try await access.write { context in
            let member: Member = try ManagedFetch.require(Member.entityName, id: memberId, in: context)
            if member.displayName != name { member.displayName = name }
            return MemberDTO(member)
        }
    }

    public func setColor(memberId: UUID, colorKey: String, theme: CorbieTheme) async throws -> MemberSaveResult {
        try await access.write { context in
            let member: Member = try ManagedFetch.require(Member.entityName, id: memberId, in: context)
            return try MemberColorAssignment.apply(requested: colorKey, to: member, theme: theme, in: context)
        }
    }

    public func setBirthday(memberId: UUID, month: Int?, day: Int?) async throws -> MemberDTO {
        try await access.write { context in
            let member: Member = try ManagedFetch.require(Member.entityName, id: memberId, in: context)
            CoreDataMemberRepository.write(month: month, day: day, to: member)
            return MemberDTO(member)
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

    @discardableResult
    public func removeMembersAndFreeTheirTasks(ids: [UUID], spaceId: UUID) async throws -> Int {
        guard ids.isEmpty == false else { return 0 }
        return try await access.write { context in
            let memberIds = ids.map { $0 as NSUUID }
            let members: [Member] = try ManagedFetch.all(
                Member.entityName,
                predicate: NSPredicate(format: "id IN %@ AND space.id == %@", memberIds, spaceId as NSUUID),
                in: context
            )
            guard members.isEmpty == false else { return 0 }
            let tasks: [TaskItem] = try ManagedFetch.all(
                TaskItem.entityName,
                predicate: NSPredicate(format: "assigneeMemberId IN %@ AND space.id == %@", memberIds, spaceId as NSUUID),
                in: context
            )
            let steps: [PlanStep] = try ManagedFetch.all(
                PlanStep.entityName,
                predicate: NSPredicate(
                    format: "assigneeMemberId IN %@ AND plan.space.id == %@",
                    memberIds,
                    spaceId as NSUUID
                ),
                in: context
            )
            tasks.forEach { $0.assigneeMemberId = nil }
            steps.forEach { $0.assigneeMemberId = nil }
            members.forEach(context.delete)
            return members.count
        }
    }

    private static func write(month: Int?, day: Int?, to member: Member) {
        if member.birthdayMonth?.intValue != month { member.birthdayMonth = month.map(NSNumber.init(value:)) }
        if member.birthdayDay?.intValue != day { member.birthdayDay = day.map(NSNumber.init(value:)) }
    }
}

enum MemberColorAssignment {
    static func apply(
        requested: String?,
        to member: Member,
        theme: CorbieTheme,
        in context: NSManagedObjectContext
    ) throws -> MemberSaveResult {
        guard let requested else { return MemberSaveResult(member: MemberDTO(member)) }
        let wanted = MemberColorSlot.stored(requested)
        guard let taken = try partnerSlot(of: member, in: context) else {
            member.colorKey = wanted.rawValue
            return MemberSaveResult(member: MemberDTO(member))
        }
        guard wanted.conflicts(with: taken, in: theme) else {
            member.colorKey = wanted.rawValue
            return MemberSaveResult(member: MemberDTO(member))
        }
        let free = wanted.nearestFreeSlot(against: taken, in: theme)
        member.colorKey = free.rawValue
        return MemberSaveResult(member: MemberDTO(member), shiftedColorFrom: wanted)
    }

    private static func partnerSlot(of member: Member, in context: NSManagedObjectContext) throws -> MemberColorSlot? {
        guard let spaceId = member.space?.id else { return nil }
        let members: [Member] = try ManagedFetch.all(
            Member.entityName,
            predicate: ManagedFetch.spaceRelation(spaceId),
            sort: [NSSortDescriptor(key: "joinedAt", ascending: true)],
            in: context
        )
        guard let partner = members.first(where: { $0.id != member.id }) else { return nil }
        guard let key = partner.colorKey else { return nil }
        return MemberColorSlot.stored(key)
    }
}
