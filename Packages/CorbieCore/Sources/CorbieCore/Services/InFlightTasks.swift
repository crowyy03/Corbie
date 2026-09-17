import Foundation

final class InFlightTasks: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [UUID: Task<Void, Never>] = [:]

    var count: Int {
        lock.withLock { tasks.count }
    }

    func run(_ operation: @escaping @Sendable () async -> Void) {
        let id = UUID()
        lock.withLock {
            tasks[id] = Task { [weak self] in
                await operation()
                self?.finish(id)
            }
        }
    }

    func waitUntilEmpty() async {
        while let pending = lock.withLock({ tasks.values.first }) {
            await pending.value
        }
    }

    private func finish(_ id: UUID) {
        lock.withLock { tasks[id] = nil }
    }
}
