import CoreData
import Foundation

public struct CoreDataBusyIntervalRepository: BusyIntervalRepository {
    private let access: CoreDataAccess

    public init(stack: CoreDataStack) {
        access = CoreDataAccess(stack: stack)
    }

    public func replace(
        spaceId: UUID,
        memberId: UUID,
        source: BusyIntervalSource,
        intervals: [BusyIntervalDraft],
        at date: Date
    ) async throws -> [BusyIntervalDTO] {
        for interval in intervals where interval.endAt <= interval.startAt {
            throw CorbieError.invalidInput("busy interval ends before it starts")
        }
        return try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: spaceId, in: context)
            let existing: [BusyInterval] = try ManagedFetch.all(
                BusyInterval.entityName,
                predicate: CoreDataBusyIntervalRepository.owned(by: memberId, source: source),
                in: context
            )
            for stale in existing {
                context.delete(stale)
            }
            return intervals.compactMap { draft in
                let interval = BusyInterval(context: context)
                context.assign(interval, toStoreOf: space)
                interval.space = space
                interval.memberId = memberId
                interval.startAt = draft.startAt
                interval.endAt = draft.endAt
                interval.source = source
                interval.updatedAt = date
                return BusyIntervalDTO(interval)
            }
            .sorted { $0.startAt < $1.startAt }
        }
    }

    public func intervals(spaceId: UUID, from: Date, to: Date) async throws -> [BusyIntervalDTO] {
        try await access.read { context in
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                ManagedFetch.spaceRelation(spaceId),
                NSPredicate(format: "endAt > %@", from as NSDate),
                NSPredicate(format: "startAt < %@", to as NSDate)
            ])
            let intervals: [BusyInterval] = try ManagedFetch.all(
                BusyInterval.entityName,
                predicate: predicate,
                sort: [NSSortDescriptor(key: "startAt", ascending: true)],
                in: context
            )
            return intervals.compactMap(BusyIntervalDTO.init)
        }
    }

    public func deleteAll(memberId: UUID, source: BusyIntervalSource) async throws {
        try await access.write { context in
            let intervals: [BusyInterval] = try ManagedFetch.all(
                BusyInterval.entityName,
                predicate: CoreDataBusyIntervalRepository.owned(by: memberId, source: source),
                in: context
            )
            for interval in intervals {
                context.delete(interval)
            }
        }
    }

    public func purge(before date: Date) async throws {
        try await access.write { context in
            let intervals: [BusyInterval] = try ManagedFetch.all(
                BusyInterval.entityName,
                predicate: NSPredicate(format: "endAt < %@", date as NSDate),
                in: context
            )
            for interval in intervals {
                context.delete(interval)
            }
        }
    }

    private static func owned(by memberId: UUID, source: BusyIntervalSource) -> NSPredicate {
        NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "memberId == %@", memberId as NSUUID),
            NSPredicate(format: "sourceRaw == %@", source.rawValue)
        ])
    }
}
