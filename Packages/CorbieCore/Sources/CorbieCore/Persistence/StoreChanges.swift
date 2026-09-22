import CoreData
import Foundation

public struct StoreChange: Sendable, Equatable {
    public enum Origin: Sendable, Equatable {
        case thisProcess
        case elsewhere
    }

    public let origin: Origin
    public let entityNames: Set<String>

    public init(origin: Origin, entityNames: Set<String>) {
        self.origin = origin
        self.entityNames = entityNames
    }

    static func pending(in context: NSManagedObjectContext) -> Set<String> {
        let touched = context.insertedObjects.union(context.updatedObjects).union(context.deletedObjects)
        return Set(touched.compactMap { $0.entity.name })
    }
}

public final class StoreChanges: @unchecked Sendable {
    private let lock = NSLock()
    private var listeners: [UUID: AsyncStream<StoreChange>.Continuation] = [:]

    public init() { }

    public func stream() -> AsyncStream<StoreChange> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<StoreChange>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuation.onTermination = { [weak self] _ in
            self?.removeListener(id)
        }
        lock.withLock { listeners[id] = continuation }
        return stream
    }

    @MainActor
    public func subscribe(_ reload: @escaping @MainActor () async -> Void) -> StoreChangeSubscription {
        let changes = stream()
        return StoreChangeSubscription(
            task: Task { @MainActor in
                for await _ in changes {
                    await reload()
                }
            }
        )
    }

    public func post(_ change: StoreChange) {
        guard change.entityNames.isEmpty == false else { return }
        let current = lock.withLock { Array(listeners.values) }
        for listener in current {
            listener.yield(change)
        }
    }

    var listenerCount: Int {
        lock.withLock { listeners.count }
    }

    private func removeListener(_ id: UUID) {
        lock.withLock { listeners[id] = nil }
    }
}

public final class StoreChangeSubscription: Sendable {
    private let task: Task<Void, Never>

    init(task: Task<Void, Never>) {
        self.task = task
    }

    public func cancel() {
        task.cancel()
    }

    deinit {
        task.cancel()
    }
}
