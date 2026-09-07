import CoreData
import Foundation

public struct CoreDataChoreRepository: ChoreRepository {
    private let access: CoreDataAccess
    private let catalog: ChoreCatalog
    private let locale: Locale

    public init(stack: CoreDataStack, catalog: ChoreCatalog = .bundled, locale: Locale = .current) {
        access = CoreDataAccess(stack: stack)
        self.catalog = catalog
        self.locale = locale
    }

    public func activeSet(spaceId: UUID, viewerMemberId: UUID?) async throws -> ChoreSetDTO? {
        let render = renderer()
        return try await access.read { context in
            let sets: [ChoreSet] = try CoreDataChoreRepository.sets(spaceId: spaceId, in: context)
            guard let active = sets.first(where: { $0.status != .applied }) else { return nil }
            return render(active, viewerMemberId)
        }
    }

    public func set(id: UUID, viewerMemberId: UUID?) async throws -> ChoreSetDTO? {
        let render = renderer()
        return try await access.read { context in
            let set: ChoreSet? = try ManagedFetch.first(ChoreSet.entityName, id: id, in: context)
            return set.map { render($0, viewerMemberId) }
        }
    }

    public func startSet(
        spaceId: UUID,
        catalogIds: [String],
        memberId: UUID?,
        at date: Date
    ) async throws -> ChoreSetDTO {
        let render = renderer()
        let catalog = catalog
        return try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: spaceId, in: context)
            let sets: [ChoreSet] = try CoreDataChoreRepository.sets(spaceId: spaceId, in: context)
            if let unfinished = sets.first(where: { $0.status != .applied }) {
                return render(unfinished, memberId)
            }
            let set = ChoreSet(context: context)
            context.assign(set, toStoreOf: space)
            set.space = space
            set.createdAt = date
            set.status = .building
            let wanted = catalogIds.isEmpty ? catalog.preselectedIds : catalogIds
            for (index, catalogId) in wanted.enumerated() {
                guard let entry = catalog.item(id: catalogId) else { continue }
                let item = ChoreItem(context: context)
                context.assign(item, toStoreOf: set)
                item.choreSet = set
                item.catalogId = entry.id
                item.title = entry.text["en"] ?? entry.id
                item.frequency = entry.frequency
                item.isIncluded = true
                item.addedByMemberId = memberId
                item.sortIndex = Int32(index)
            }
            return render(set, memberId)
        }
    }

    public func addItem(setId: UUID, draft: ChoreItemDraft) async throws -> ChoreSetDTO {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard draft.catalogId != nil || title.isEmpty == false else {
            throw CorbieError.invalidInput("a chore needs a name")
        }
        let render = renderer()
        let catalog = catalog
        return try await access.write { context in
            let set: ChoreSet = try ManagedFetch.require(ChoreSet.entityName, id: setId, in: context)
            try CoreDataChoreRepository.requireEditable(set)
            if let catalogId = draft.catalogId,
               let existing = set.items.first(where: { $0.catalogId == catalogId }) {
                existing.isIncluded = true
                return render(set, draft.addedByMemberId)
            }
            let item = ChoreItem(context: context)
            context.assign(item, toStoreOf: set)
            item.choreSet = set
            item.catalogId = draft.catalogId
            item.title = draft.catalogId.flatMap { catalog.item(id: $0)?.text["en"] } ?? title
            item.frequency = draft.catalogId.flatMap { catalog.item(id: $0)?.frequency } ?? draft.frequency
            item.isIncluded = true
            item.addedByMemberId = draft.addedByMemberId
            item.sortIndex = Int32(set.items.count)
            return render(set, draft.addedByMemberId)
        }
    }

    public func setIncluded(itemId: UUID, isIncluded: Bool) async throws -> ChoreSetDTO {
        let render = renderer()
        return try await access.write { context in
            let item: ChoreItem = try ManagedFetch.require(ChoreItem.entityName, id: itemId, in: context)
            let set = try CoreDataChoreRepository.owner(of: item)
            try CoreDataChoreRepository.requireEditable(set)
            item.isIncluded = isIncluded
            return render(set, nil)
        }
    }

    public func setFrequency(itemId: UUID, frequency: ChoreFrequency) async throws -> ChoreSetDTO {
        let render = renderer()
        return try await access.write { context in
            let item: ChoreItem = try ManagedFetch.require(ChoreItem.entityName, id: itemId, in: context)
            let set = try CoreDataChoreRepository.owner(of: item)
            try CoreDataChoreRepository.requireEditable(set)
            item.frequency = frequency
            return render(set, nil)
        }
    }

    public func removeItem(itemId: UUID) async throws -> ChoreSetDTO {
        let render = renderer()
        return try await access.write { context in
            let item: ChoreItem = try ManagedFetch.require(ChoreItem.entityName, id: itemId, in: context)
            let set = try CoreDataChoreRepository.owner(of: item)
            try CoreDataChoreRepository.requireEditable(set)
            context.delete(item)
            context.processPendingChanges()
            return render(set, nil)
        }
    }

    public func startRating(setId: UUID) async throws -> ChoreSetDTO {
        let render = renderer()
        return try await access.write { context in
            let set: ChoreSet = try ManagedFetch.require(ChoreSet.entityName, id: setId, in: context)
            try CoreDataChoreRepository.requireEditable(set)
            let included = set.items.filter(\.isIncluded).count
            guard included >= ChoreSetDTO.minimumIncludedItems else {
                throw CorbieError.invalidInput("a split needs at least \(ChoreSetDTO.minimumIncludedItems) chores")
            }
            set.status = .rating
            return render(set, nil)
        }
    }

    public func rate(itemId: UUID, memberId: UUID, verdict: ChoreVerdict, at date: Date) async throws -> ChoreSetDTO {
        let render = renderer()
        return try await access.write { context in
            let item: ChoreItem = try ManagedFetch.require(ChoreItem.entityName, id: itemId, in: context)
            let set = try CoreDataChoreRepository.owner(of: item)
            guard set.revealedAt == nil else {
                throw CorbieError.invalidInput("this split is already revealed")
            }
            guard item.isIncluded else {
                throw CorbieError.invalidInput("this chore is not part of the split")
            }
            if set.status == .building {
                set.status = .rating
            }
            let rating = item.ratings.first { $0.memberId == memberId } ?? {
                let fresh = ChoreRating(context: context)
                context.assign(fresh, toStoreOf: item)
                fresh.choreItem = item
                fresh.memberId = memberId
                return fresh
            }()
            rating.verdict = verdict
            rating.createdAt = date
            return render(set, memberId)
        }
    }

    public func undoRating(itemId: UUID, memberId: UUID) async throws -> ChoreSetDTO {
        let render = renderer()
        return try await access.write { context in
            let item: ChoreItem = try ManagedFetch.require(ChoreItem.entityName, id: itemId, in: context)
            let set = try CoreDataChoreRepository.owner(of: item)
            guard set.revealedAt == nil else {
                throw CorbieError.invalidInput("this split is already revealed")
            }
            for rating in item.ratings where rating.memberId == memberId {
                context.delete(rating)
            }
            context.processPendingChanges()
            return render(set, memberId)
        }
    }

    public func reveal(setId: UUID, at date: Date) async throws -> ChoreSetDTO {
        let render = renderer()
        return try await access.write { context in
            let set: ChoreSet = try ManagedFetch.require(ChoreSet.entityName, id: setId, in: context)
            guard let space = set.space else {
                throw CorbieError.notFound("Space for chore set \(setId)")
            }
            let memberIds = space.members.compactMap(\.id).sorted { $0.uuidString < $1.uuidString }
            guard memberIds.count >= 2 else {
                throw CorbieError.invalidInput("a split is revealed once both of you have rated")
            }
            let included = set.items.filter(\.isIncluded)
            guard included.count >= ChoreSetDTO.minimumIncludedItems else {
                throw CorbieError.invalidInput("a split needs at least \(ChoreSetDTO.minimumIncludedItems) chores")
            }
            let memberAId = memberIds[0]
            let memberBId = memberIds[1]
            var candidates: [ChoreSplitCandidate] = []
            for item in included {
                guard let itemId = item.id,
                      let verdictA = item.ratings.first(where: { $0.memberId == memberAId })?.verdict,
                      let verdictB = item.ratings.first(where: { $0.memberId == memberBId })?.verdict else {
                    throw CorbieError.invalidInput("both of you still have chores left to rate")
                }
                candidates.append(
                    ChoreSplitCandidate(
                        id: itemId,
                        loadPerWeek: item.frequency.loadPerWeek,
                        verdictA: verdictA,
                        verdictB: verdictB
                    )
                )
            }
            let outcome = ChoreSplitEngine.split(candidates, memberAId: memberAId, memberBId: memberBId)
            for item in set.items {
                for assignment in item.assignments {
                    context.delete(assignment)
                }
            }
            context.processPendingChanges()
            for item in included {
                guard let itemId = item.id, let decision = outcome.decision(for: itemId) else { continue }
                let assignment = ChoreAssignment(context: context)
                context.assign(assignment, toStoreOf: item)
                assignment.choreItem = item
                assignment.result = decision.result
                assignment.assignedMemberId = decision.assignedMemberId
                assignment.memberAId = memberAId
                assignment.memberBId = memberBId
                assignment.scoreA = Int16(decision.scoreA)
                assignment.scoreB = Int16(decision.scoreB)
                assignment.createdAt = date
            }
            set.revealedAt = date
            set.status = .revealed
            return render(set, nil)
        }
    }

    public func apply(setId: UUID, memberId: UUID?, at date: Date) async throws -> [TaskDTO] {
        let render = titleRenderer()
        return try await access.write { context in
            let set: ChoreSet = try ManagedFetch.require(ChoreSet.entityName, id: setId, in: context)
            guard set.revealedAt != nil else {
                throw CorbieError.invalidInput("a split is added to Tasks once it is revealed")
            }
            guard let space = set.space else {
                throw CorbieError.notFound("Space for chore set \(setId)")
            }
            var leftovers = CoreDataChoreRepository.choreTasks(in: space, context: context)
            var applied: [TaskDTO] = []
            for item in set.items.filter(\.isIncluded).sorted(by: { $0.sortIndex < $1.sortIndex }) {
                guard let itemId = item.id,
                      let assignment = item.assignments.sorted(by: {
                          ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast)
                      }).last else { continue }
                let key = CoreDataChoreRepository.matchKey(of: item)
                let task = leftovers.removeValue(forKey: key) ?? {
                    let fresh = TaskItem(context: context)
                    context.assign(fresh, toStoreOf: space)
                    fresh.space = space
                    fresh.createdByMemberId = memberId
                    fresh.createdAt = date
                    return fresh
                }()
                task.title = render(item)
                task.choreItemId = itemId
                task.recurrence = item.frequency.recurrence
                task.assigneeMemberId = assignment.assignedMemberId
                task.takenAt = assignment.assignedMemberId == nil ? nil : date
                task.rotatesBetweenMembers = assignment.result == .rotate
                task.archivedAt = nil
                applied.append(TaskDTO(task))
            }
            for leftover in leftovers.values {
                leftover.archivedAt = date
            }
            set.appliedAt = date
            set.status = .applied
            return applied
        }
    }

    public func history(spaceId: UUID, viewerMemberId: UUID?) async throws -> [ChoreSetDTO] {
        let render = renderer()
        return try await access.read { context in
            let sets: [ChoreSet] = try CoreDataChoreRepository.sets(spaceId: spaceId, in: context)
            return sets.map { render($0, viewerMemberId) }
        }
    }

    private func titleRenderer() -> @Sendable (ChoreItem) -> String {
        let catalog = catalog
        let locale = locale
        return { item in
            guard let catalogId = item.catalogId, let entry = catalog.item(id: catalogId) else {
                return item.title ?? ""
            }
            return entry.text(for: locale)
        }
    }

    private func renderer() -> @Sendable (ChoreSet, UUID?) -> ChoreSetDTO {
        let title = titleRenderer()
        return { set, viewerMemberId in
            ChoreSetDTO(
                set,
                showsEveryRating: CoreDataChoreRepository.everyoneHasRated(set),
                viewerMemberId: viewerMemberId,
                title: title
            )
        }
    }

    private static func everyoneHasRated(_ set: ChoreSet) -> Bool {
        if set.revealedAt != nil { return true }
        let memberCount = set.space?.members.count ?? 0
        guard memberCount > 0 else { return false }
        let included = set.items.filter(\.isIncluded)
        guard included.isEmpty == false else { return false }
        return included.allSatisfy { Set($0.ratings.compactMap(\.memberId)).count >= memberCount }
    }

    private static func sets(spaceId: UUID, in context: NSManagedObjectContext) throws -> [ChoreSet] {
        try ManagedFetch.all(
            ChoreSet.entityName,
            predicate: ManagedFetch.spaceRelation(spaceId),
            sort: [NSSortDescriptor(key: "createdAt", ascending: false)],
            in: context
        )
    }

    private static func owner(of item: ChoreItem) throws -> ChoreSet {
        guard let set = item.choreSet else {
            throw CorbieError.notFound("ChoreSet for item \(item.id?.uuidString ?? "?")")
        }
        return set
    }

    private static func requireEditable(_ set: ChoreSet) throws {
        guard set.revealedAt == nil else {
            throw CorbieError.invalidInput("this split is already revealed")
        }
    }

    private static func matchKey(of item: ChoreItem) -> String {
        if let catalogId = item.catalogId { return "catalog:" + catalogId }
        return "custom:" + (item.title ?? "").lowercased()
    }

    private static func choreTasks(in space: Space, context: NSManagedObjectContext) -> [String: TaskItem] {
        var keyed: [String: TaskItem] = [:]
        for task in space.tasks where task.choreItemId != nil {
            guard let itemId = task.choreItemId,
                  let item: ChoreItem = try? ManagedFetch.first(ChoreItem.entityName, id: itemId, in: context)
            else { continue }
            keyed[matchKey(of: item)] = task
        }
        return keyed
    }
}
